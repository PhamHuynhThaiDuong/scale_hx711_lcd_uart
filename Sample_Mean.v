module Sample_Mean #(
	parameter N_SAMPLE = 5
)(
	input i_clk, i_rst_n,
	input [23:0] i_dout_sample,
	input i_dout_valid,
	
	output reg [23:0] o_mean,
	output reg o_mean_done,
	output reg [63:0] debug_state
);


 localparam IDLE = 2'd0;
 localparam SAMPLE = 2'd1;
 localparam CNT_N = 2'd2;
 localparam GET_MEAN = 2'd3;

 // Internal Register
 reg [23:0] sample_sum;	// Reg store sum N-Sample
 reg [23:0] dout_reg;	// Reg store data raw 24-bit
 reg [3:0] sample_cnt;
 reg dout_latched;

 reg [1:0] state;
 
 always @(*) begin
    case(state)
	IDLE: 	debug_state = "IDLE";
	SAMPLE:	debug_state = "SAMPLE";
	CNT_N: debug_state = "CNT_N";
	GET_MEAN: debug_state = "GET_MEAN";
	default: debug_state = "IDLE";
    endcase
 end 

 always @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin dout_reg <= 24'd0; dout_latched <= 1'b0; end
    else begin
	dout_latched <= 1'b0;
	if (i_dout_valid) begin
	   dout_reg <= i_dout_sample;
	   dout_latched <= 1'b1;
	end
    end
 end
 
 always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
 	state <= IDLE;
	sample_sum <= 24'd0;
	sample_cnt <= 4'd0;
	o_mean <= 24'd0;
	o_mean_done <= 1'b0;
    end
    else begin
	case (state)
	     IDLE: begin
		sample_sum <= 24'd0;
		sample_cnt <= 4'd0;
		o_mean_done <= 1'b0;
		if (i_dout_valid) begin
		    state <= SAMPLE;
		end
	     end
	     SAMPLE: begin
		if (dout_latched) begin
		   sample_sum <= sample_sum + dout_reg;
		   sample_cnt <= sample_cnt + 1'b1;
		   state <= CNT_N;
		end
	     end
	     CNT_N: begin
		if (sample_cnt < N_SAMPLE) begin
		   state <= SAMPLE;
		end
		else begin
		     sample_cnt <= 4'd0;
		     state <= GET_MEAN;
		end
	     end
	     GET_MEAN: begin
		o_mean <= sample_sum / N_SAMPLE;
		o_mean_done <= 1'b1;
		state <= IDLE;
	     end
	     default : state <= IDLE;
	endcase
    end

 end

endmodule
