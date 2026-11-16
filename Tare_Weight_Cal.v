module Tare_Weight_Cal #(
	parameter CALIBRATION_FACTOR = 440
)(
    input  wire               i_clk,
    input  wire               i_rst_n,

    input  wire signed [23:0] i_raw,
    input  wire               i_data_valid,
    input  wire               i_tare_en,
    //input wire 		      i_net_en,

    output reg  signed [23:0] o_tare,
    output reg                o_tare_updated,
    output wire  signed [24:0] o_net,
    output reg                o_net_done,
   
    output reg  signed [24:0] o_weight_g,
    output reg 		      o_weight_done
);
/*
  reg  signed [23:0] o_tare;
  reg                o_tare_updated;
  wire  signed [24:0] o_net;
  reg                o_net_done;
*/

    reg signed [23:0] r_raw;
    reg raw_updated;
    reg net_en;
    always @(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) begin r_raw <= 24'sd0; raw_updated <= 1'b0; net_en <= 1'b0; end
	else begin
	     if(i_data_valid) begin
		r_raw <= i_raw;
	 	raw_updated <= 1'b1;
	     end
	     else if(raw_updated) begin
		raw_updated <= 1'b0;
		net_en <= 1'b1;
	     end
	     else net_en <= 1'b0;
	end
    end

 //------------------------------------------------------------------
 // TARE CONTROLLER
 //------------------------------------------------------------------
    reg tare_latched_1;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_tare         <= 24'sd0;
            o_tare_updated <= 1'b0;
            tare_latched_1 <= 1'b0;
        end else begin
            o_tare_updated <= 1'b0;
            if (i_tare_en || (raw_updated && !tare_latched_1) ) begin
                o_tare         <= r_raw;
                o_tare_updated <= 1'b1;
                tare_latched_1 <= 1'b1;
            end
        end
    end

    
 //------------------------------------------------------------------
 // Get delta between no load and have load
 //------------------------------------------------------------------
    reg signed [24:0] net_reg;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            net_reg      <= 25'sd0;
            o_net_done    <= 1'b0;
        end else begin
            o_net_done    <= 1'b0;
            if (net_en) begin
                net_reg <= {r_raw[23], r_raw} - {o_tare[23], o_tare};
                o_net_done <= 1'b1;
            end
        end
    end

 //------------------------------------------------------------------
 // Get positive delta value
 //------------------------------------------------------------------
   assign o_net = (net_reg < 25'sd0) ? 25'sd0 : net_reg;

 //------------------------------------------------------------------
  // Weight Calculator
 //------------------------------------------------------------------
    always @ (posedge i_clk or negedge i_rst_n) begin
        if(!i_rst_n) begin o_weight_g <= 25'sd0; o_weight_done <= 1'b0; end
        else begin
            o_weight_done <= 1'b0;
            if(o_net_done) begin
            o_weight_g <= o_net / CALIBRATION_FACTOR;
            o_weight_done <= 1'b1;
            end
        end
    end
	
endmodule