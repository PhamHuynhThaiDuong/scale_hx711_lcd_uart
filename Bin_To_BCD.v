module Bin_To_BCD #(
	parameter SIZE_INPUT = 8,
	parameter SIZE_OUTPUT = 12
)(
	input i_clk, 
	input i_rst_n, 
	input i_start,
	input [SIZE_INPUT-1:0] i_bin,
	/*
	output reg [SIZE_INPUT-1:0] r_bin,
 	output reg [SIZE_INPUT-1:0] r_shifted_bit,
 	output reg [SIZE_OUTPUT-1:0] r_bcd,
	*/
	output reg [SIZE_OUTPUT-1:0] o_bcd,
	output reg o_bcd_done,
	output reg o_busy,
	output reg [63:0] debug_state
);

 reg [2:0] r_state;

 reg [SIZE_INPUT-1:0] r_bin;
 reg [SIZE_INPUT-1:0] r_shifted_bit;
 reg [SIZE_OUTPUT-1:0] r_bcd;
 
 //-----------------------------------------------------
 // Initial States FSM
 //-----------------------------------------------------
 localparam IDLE 	= 3'd0;
 localparam ADD3 	= 3'd1;
 localparam SHIFT_L 	= 3'd2;
 localparam CNT_BIT 	= 3'd3;
 localparam BCD_DONE 	= 3'd4;

 localparam BCD_DIGITS = SIZE_OUTPUT / 4;
 always @(*) begin
 	case(r_state)
	    IDLE: debug_state = "IDLE";
	    ADD3: debug_state = "ADD3";
	    SHIFT_L: debug_state = "SHIFT_L";
	    CNT_BIT: debug_state = "CNT_BIT";
	    BCD_DONE: debug_state = "BCD_DONE";
	    default: debug_state = "IDLE";
	endcase
 end

 integer i;
 always @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
	    r_state <= IDLE;
	    r_bin <= 0;
	    r_shifted_bit <= 0;
	    r_bcd <= 0;
	    o_bcd <= 0;
	    o_bcd_done <= 1'b0;
	    o_busy <= 1'b0;
	end
	else begin
	    case(r_state)
		IDLE: begin
		    r_bin <= 0;
		    r_shifted_bit <= 0;
	    	    r_bcd <= 0;
	    	    o_bcd_done <= 1'b0;
		    o_busy <= 1'b0;
		    if (i_start) begin
			r_state <= ADD3;
			r_bin <= i_bin;
			o_busy <= 1'b1;
		    end
		end
		ADD3: begin
		   for(i = 0; i < BCD_DIGITS; i = i + 1) begin
	    		if( r_bcd[i*4 +:4] >= 4'd5 )
				r_bcd[i*4 +:4] <= r_bcd[i*4 +:4] + 4'd3;
		   end
		   r_state <= SHIFT_L;
		end
		SHIFT_L: begin
		    r_bcd <= { r_bcd[SIZE_OUTPUT-2:0], r_bin[SIZE_INPUT-1] }; 
		    r_bin <= r_bin << 1;
		    r_shifted_bit <= r_shifted_bit + 1;
		    r_state <= CNT_BIT;
		end
		CNT_BIT: begin
		    if(r_shifted_bit < SIZE_INPUT) 
			r_state <= ADD3;
		    else 
			r_state <= BCD_DONE;
		end
		BCD_DONE: begin
		    o_bcd <= r_bcd;
		    o_bcd_done <= 1'b1;
		    r_state <= IDLE;
		end
	    	default: r_state <= IDLE;
	    endcase
	end

 end


endmodule
