`timescale 1ns/1ps
`define CLK_PERIOD 20

module tb_top_hx711_weight_processor;
	reg i_clk;
    	reg i_rst_n;

    	reg i_hx711_dout;
	reg i_tare_en;

    	wire o_hx711_sck;
	wire signed [24:0] o_weight_g;
     	wire o_weight_done;	

	// Signal Debug
	wire hx711_start;
	wire [23:0] hx711_raw_unit;
	wire        hx711_done;

	wire [23:0] hx711_raw;
    	wire[23:0] hx711_raw_mean;
    	wire hx711_mean_done;
	wire  signed [23:0] o_tare;
    	wire                o_tare_updated;
    	wire  signed [24:0] o_net;
    	wire                o_net_done;
   	
HX711_Weight_Processor dut(
	.i_clk 		(i_clk),
	.i_rst_n 	(i_rst_n),
	
	.i_hx711_dout 	(i_hx711_dout),
	.i_tare_en 	(i_tare_en),
	.o_hx711_sck 	(o_hx711_sck),
	.o_weight_g	(o_weight_g),
	.o_weight_done	(o_weight_done),

	.hx711_start	(hx711_start),
	.hx711_raw_unit	(hx711_raw_unit),
	.hx711_done	(hx711_done),

	.hx711_raw	(hx711_raw),
    	.hx711_raw_mean (hx711_raw_mean),
   	.hx711_mean_done(hx711_mean_done),
	
	.o_tare		(o_tare),
    	.o_tare_updated	(o_tare_updated),
    	.o_net		(o_net),
    	.o_net_done	(o_net_done)
	
);

 initial begin
	i_clk = 1'b0;
	forever #(`CLK_PERIOD/2) i_clk = ~i_clk;
 end

 task send_hx711_data;
	input [23:0] data;
	integer i;
	begin
		$display("Start send hx711_data: %h", data);
		// 1. Chua co dout
		i_hx711_dout = 1'b1;

		// 2. Yêu c?u controller b?t ??u ??c
        	

		// 3. Dout co data
		@(negedge i_clk) i_hx711_dout = 1'b0;

		// 4. Cho SCK len muc cao roi gui bit MSB frist
		@(posedge o_hx711_sck) i_hx711_dout = data[23];
		// 5. Moi falling edge SCK, chuan bi bit next
		for(i=22; i>=0; i= i-1) begin
		    @(negedge o_hx711_sck) i_hx711_dout = data[i];
		end
		
		@(posedge hx711_done);
		$display("Time: %0t | Send hx711 data done: %h",$time, hx711_raw_unit);
	end
 endtask

task press_btn;
	input i_key;
	begin
	    $display(">>> Bat dau nhan nut");
    		i_key = 0; #200;  
    		i_key = 1; #100;  
    		i_key = 0; #150;  
    		i_key = 1; #100;  
    		i_key = 0; #100;  
    		i_key = 1; #100;
		i_key = 0;     

    		// Press button over  debounce time (20 ms)
    		#(20_000_000); // 20 ms = 20,000,000 ns

    		// button is realeased
    		$display(">>> Tha nut nhan");
		i_key = 0; #100;
    		i_key = 1; #200;  
    		i_key = 0; #100;  
    		i_key = 1; #150;  
    		i_key = 0; #100;  
    		i_key = 1;     
	end
endtask

 initial begin
	i_rst_n = 0; i_hx711_dout = 1'b1; i_tare_en = 1'b0;
	#(`CLK_PERIOD*5) i_rst_n = 1;
    // HX711 start sample
	// raw bin when no load
	#(`CLK_PERIOD) send_hx711_data(24'h07f19b);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h07f14e);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h07f15c);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h07ef01);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h07ef0c);
	@(posedge o_weight_done) 
	$display("-->TARE: = %d", o_tare);
	$display("-->NET: = %d", o_net);
        $display("-->WEIGHT: = %d", o_weight_g);
	#(`CLK_PERIOD*10);

	// raw bin when have load
	#(`CLK_PERIOD) send_hx711_data(24'h093800);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h093810);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h0937FF);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h09381B);
	@(negedge hx711_start)
	#(`CLK_PERIOD) send_hx711_data(24'h093850);
	
	@(negedge o_weight_done)
	$display("-->TARE: = %d", o_tare);
	$display("-->NET: = %d", o_net);
        $display("-->WEIGHT: = %d", o_weight_g);
	#(`CLK_PERIOD*10);
	$stop;
 end

endmodule
