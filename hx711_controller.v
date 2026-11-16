/*------------------------------------------------------------------------------------------------------------------------------
	Module: 	HX711 Controller
	Create Date: 	20/09/2026
	Author: 	Pham Huynh Thai Duong
 SYS_FRE  = 50 MHz - FPGA Clocks
 SCK_FRE = 500 KHz - HX711 Clocks
--> SCK_DIV = SYS_FRE / SCK_FRE = 100 cycles
-------------------------------------------------------------------------------------------------------------------------------*/

module hx711_controller #(
	parameter SCK_HALF_DIV= 50 // SCK_DIV * 0.5 = 50
)(
	input i_clk, i_rst_n,
	input i_start,
	input i_hx711_dout,

	output reg o_done,
	output reg [23:0] o_dout,
	output wire o_busy,
	output wire o_hx711_sck,
	output reg [79:0] debug_state
);
 reg [2:0] state;
 reg [5:0] clk_div_cnt; 
 reg [4:0] bit_cnt;
 reg [23:0] shift_reg;

 localparam IDLE = 3'd0; 	// State wait start signal 
 localparam WAIT_HX711 = 3'd1;
 localparam T1_DELAY = 3'd2;	// State delay timing from DOUT of HX711 to frist rising edge of SCK
 localparam GEN_PH = 3'd3;	// State generate the high pulse of SCK 
 localparam GEN_PL = 3'd4;	// State generate the low pulse of SCK
 localparam GAIN_PH = 3'd5;	// State generate the high pulse of gain select
 localparam GAIN_PL = 3'd6;	// State generate the low pulse of gain select
 localparam DONE = 3'd7;	// State know HX711_data done. 

 always @ (*) begin
	case(state)
		IDLE: 		debug_state = "IDLE";
		WAIT_HX711: 	debug_state = "WAIT_HX711";
		T1_DELAY: 	debug_state = "T1_DELAY";
		GEN_PH: 	debug_state = "GEN_PH";
		GEN_PL: 	debug_state = "GEN_PL";
		GAIN_PH: 	debug_state = "GAIN_PH"; 
		GAIN_PL: 	debug_state = "GAIN_PL";
		DONE: 		debug_state = "DONE";
		default: 	debug_state = "IDLE";
	endcase
 end

 reg sync_r0, sync_r1;
 always @ (posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin 
		sync_r0 <= 1'b1;  
		sync_r1 <= 1'b1;
	end
	else begin
		sync_r0 <= i_hx711_dout;
		sync_r1 <= sync_r0;
	end
 end
 //assign f_edge_dout = !sync_r0 && sync_r1;

 always @ (posedge i_clk or negedge i_rst_n) begin
 	if (!i_rst_n) begin
		state <= IDLE;
		clk_div_cnt <= 6'd0;
		bit_cnt <= 5'd0;
		shift_reg <= 24'd0;
		o_dout <= 24'd0;
		o_done <= 1'b0;
	end
	else begin
	    o_done <= 1'b0;
	    case(state)
		IDLE: begin
			shift_reg <= 24'd0;
			if (i_start) begin
				state <= WAIT_HX711;
			end
		end
		WAIT_HX711: begin
			if (!sync_r1) begin
				state <= T1_DELAY; 
			end
		end
		T1_DELAY: begin
			if (clk_div_cnt == SCK_HALF_DIV - 1) begin
				clk_div_cnt <= 6'd0;
				state <= GEN_PH;
			end
			else clk_div_cnt <= clk_div_cnt + 1'b1;
		end
		GEN_PH: begin
			if (clk_div_cnt == SCK_HALF_DIV - 1) begin
				clk_div_cnt <= 6'd0;
				state <= GEN_PL;
				shift_reg <= {shift_reg[22:0], sync_r1};
			end
			else clk_div_cnt <= clk_div_cnt + 1'b1;
		end
		GEN_PL: begin
			if (clk_div_cnt == SCK_HALF_DIV - 1) begin
				clk_div_cnt <= 6'd0;
				if (bit_cnt < 5'd23) begin
					bit_cnt <= bit_cnt + 5'b1;
					state <= GEN_PH;
				end
				else begin
					bit_cnt <= 5'd0;
					state <= GAIN_PH;
				end
			end
			else clk_div_cnt <= clk_div_cnt + 1'b1;
		end
		GAIN_PH: begin
			if (clk_div_cnt == SCK_HALF_DIV - 1) begin
				clk_div_cnt <= 6'd0;
				state <= GAIN_PL;
			end
			else clk_div_cnt <= clk_div_cnt + 1'b1;
		end
		GAIN_PL: begin
			if (clk_div_cnt == SCK_HALF_DIV - 1) begin
				clk_div_cnt <= 6'd0;
				state <= DONE;
			end
			else clk_div_cnt <= clk_div_cnt + 1'b1;
		end
		DONE: begin
			o_dout <= shift_reg;
			o_done <= 1'b1;
			state <= IDLE;
		end
		default: 	state <= IDLE;
	    endcase
	end
 end

 assign o_busy = (state != IDLE);
 assign o_hx711_sck = ( (state  == GEN_PH) || (state  == GAIN_PH) );

endmodule