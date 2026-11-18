module uart_tx_byte #(
	parameter CYCLE_PER_BIT = 434   // CLK / baudrate 
)(
	input i_clk, 
	input i_rst_n,
	input i_tx_en,
	input [7:0] i_data,
	output reg o_tx_data,
	output wire o_busy,
	output reg o_done,
	output reg [71:0] debug_state
);
	localparam START_BIT = 1'b0;
	localparam STOP_BIT = 1'b1;

	localparam CYCLE_PER_BIT_SIZE = $clog2(CYCLE_PER_BIT);

	localparam [1:0]IDLE 		= 2'd0, 
			START 		= 2'd1,
			SEND_DATA 	= 2'd2,
			STOP 		= 2'd3;

	reg [1:0] currState, nextState;
	reg [CYCLE_PER_BIT_SIZE-1:0] baud_cnt; // Count Time per bit
	reg [2:0] bit_cnt; // count bit transmitted of 1 byte data
	reg [7:0] data_reg;


	assign o_busy = (currState != IDLE);

	always @ (posedge i_clk or negedge i_rst_n) begin
		if (!i_rst_n) begin currState <= IDLE; end
		else currState <= nextState;
	end

	always @ (*) begin
		case (currState)
			IDLE: 		nextState = (i_tx_en) ? START : IDLE;
			START: 		nextState = (baud_cnt == CYCLE_PER_BIT-1) ? SEND_DATA : START;
			SEND_DATA: 	nextState =((baud_cnt == CYCLE_PER_BIT-1) && (bit_cnt == 3'd7)) ? STOP : SEND_DATA;
			STOP: 		nextState = (baud_cnt == CYCLE_PER_BIT-1) ? IDLE : STOP;
			default: nextState = IDLE;
		endcase
	end

	always @ (*) begin
		case(currState)
			IDLE:	debug_state = "IDLE";
			START: 	debug_state = "START";
			SEND_DATA: debug_state = "SEND_DATA";
			STOP: 	debug_state = "STOP";
			default: debug_state = "IDLE";
		endcase
	end


	always @ (posedge i_clk or negedge i_rst_n) begin
		if (!i_rst_n) begin 
			baud_cnt <= 0;
			bit_cnt <= 3'd0;
			o_tx_data <= 1'b1;
			o_done <= 1'b0;
		end
		else case (currState) 
			IDLE: begin
				o_tx_data <= 1'b1; // bit Idle = 1
				baud_cnt <= 0;
				bit_cnt <= 3'd0;
				o_done <= 1'b0;
				if (i_tx_en) data_reg <= i_data;
			end
			START: begin
				o_tx_data <= START_BIT; // bit Start = 0
				if (baud_cnt == CYCLE_PER_BIT-1) baud_cnt <= 0;
				else baud_cnt <= baud_cnt + 1'b1;
			end
			SEND_DATA: begin
				o_tx_data <= data_reg[bit_cnt];
				if (baud_cnt == CYCLE_PER_BIT-1) begin 
					baud_cnt <= 0;
					if (bit_cnt == 3'd7) bit_cnt <= 3'd0;
					else bit_cnt <= bit_cnt + 1'b1;
				end
				else baud_cnt <= baud_cnt + 1'b1;
			end
			STOP: begin
				o_tx_data <= STOP_BIT; 
				if (baud_cnt == CYCLE_PER_BIT-1) begin
					baud_cnt <= 0;
					o_done <= 1'b1;
				end
				else baud_cnt <= baud_cnt + 1'b1;
			end
		endcase
	end

endmodule