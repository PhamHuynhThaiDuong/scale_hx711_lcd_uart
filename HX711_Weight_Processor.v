module HX711_Weight_Processor #(
    parameter N_SAMPLE = 5,
    parameter SCK_HALF_DIV = 50,
    parameter CALIBRATION_FACTOR = 440
)(
    input  wire i_clk,
    input  wire i_rst_n,
    input  wire i_hx711_dout,
    input  wire i_tare_en,

    output wire o_hx711_sck,
    output wire signed [24:0] o_weight_g,
    output wire o_weight_done,

    //---------------Debug signals-------------
	// HX711 signals
    output reg         hx711_start,
    output wire [23:0] hx711_raw_unit,
    output wire        hx711_done,
    
    output wire [23:0] hx711_raw,
    output wire[23:0] hx711_raw_mean,
    output wire hx711_mean_done,
    
	// Tare / Net / Weight signals
    output wire  signed [23:0] o_tare,
    output wire                o_tare_updated,
    output wire  signed [24:0] o_net,
    output wire                o_net_done
);

	
    	// HX711 signals
    	//reg         hx711_start;
    	//wire [23:0] hx711_raw_unit;
   	//wire        hx711_done;
    	wire        hx711_busy;

    	//wire [23:0] hx711_raw;
     	//wire[23:0] hx711_raw_mean;
	//wire hx711_mean_done;

	// Tare / Net / Weight signals
 /*   	wire               tare_pulse;
	wire  signed [23:0] o_tare;
    	wire                o_tare_updated;
    	wire  signed [24:0] o_net;
    	wire                o_net_done;
    	wire signed [24:0] weight_g;
    	wire               weight_done;
 */             
    
  
 // Trigger one pulse to start hx711 controller
 always@(posedge i_clk or negedge i_rst_n) begin
	if(!i_rst_n) hx711_start <= 1'b0;
	else begin
	    hx711_start <= 1'b0;
	    if(!hx711_busy) hx711_start <= 1'b1;
	end
 end

 
    //-------------------------------------------------------------------------
    // HX711 controller
    //-------------------------------------------------------------------------
	
    hx711_controller #(
        .SCK_HALF_DIV(SCK_HALF_DIV)
    ) u_hx711 (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_start      (hx711_start),
        .i_hx711_dout (i_hx711_dout),
        .o_done       (hx711_done),
        .o_dout       (hx711_raw_unit),
        .o_busy       (hx711_busy),
        .o_hx711_sck  (o_hx711_sck),
        .debug_state  ()
    );

    //-------------------------------------------------------------------------
    // Sample_Mean_Calculate
    //-------------------------------------------------------------------------
    	
    Sample_Mean #(
	.N_SAMPLE(N_SAMPLE)
    )u_sample(
        .i_clk(i_clk), 
        .i_rst_n(i_rst_n),
        .i_dout_sample(hx711_raw_unit),
        .i_dout_valid(hx711_done),
	
        .o_mean(hx711_raw_mean),
        .o_mean_done(hx711_mean_done),
        .debug_state ()
    );
     assign hx711_raw = $signed(hx711_raw_mean);
    
    //-------------------------------------------------------------------------
    // Tare / Net / Weight calculation
    //-------------------------------------------------------------------------
	

    Tare_Weight_Cal #(
	.CALIBRATION_FACTOR(CALIBRATION_FACTOR)
    )u_weight (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .i_raw          (hx711_raw),
        .i_data_valid   (hx711_mean_done),
        .i_tare_en      (i_tare_en),
        
	.o_tare(o_tare),
    	.o_tare_updated(o_tare_updated),
    	.o_net(o_net),
    	.o_net_done(o_net_done),
        .o_weight_g     (o_weight_g),
        .o_weight_done  (o_weight_done)
    );
endmodule
