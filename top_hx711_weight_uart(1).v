/*------------------------------------------------------------------------------
 Module      : top_hx711_weight_uart
 Description : Tang Nano 9K load-cell system
               27 MHz onboard clock -> PLL -> 50 MHz system clock
               HX711 + Tare + Net + Weight + UART debug
 UART        : 115200 baud
------------------------------------------------------------------------------*/

module top_hx711_weight_uart #(
    parameter SYS_FREQ_HZ = 50_000_000,
    parameter SCK_FREQ_HZ = 500_000,
    parameter BAUD_RATE   = 115200,
    parameter DELAY_MS    = 50
)(
    // Onboard 27 MHz clock and external reset
    input  wire i_clk,
    input  wire i_rst_n,

    // HX711
    
    input  wire i_hx711_dout,
    output wire o_hx711_sck,

    // Buttons (active-low, according to the existing key_filter interface)
    input  wire i_tare_btn_n,

    // UART TX
     output wire o_uart_tx
/*
    //---------------Debug signals-------------
	// HX711 signals
    output reg         hx711_start,
    output wire [23:0] hx711_raw_unit,
    output wire        hx711_done,
    
    output wire [23:0] hx711_raw,
    output wire[23:0] hx711_raw_mean,
    output wire hx711_mean_done,
    output reg [3:0] hx711_sample_cnt,
	// Tare / Net / Weight signals
    output wire  signed [23:0] o_tare,
    output wire                o_tare_updated,
    output wire  signed [24:0] o_net,
    output wire                o_net_done,
    output wire signed [24:0] weight_g,
    output wire weight_done,
    	// Bin To BCD signals
    output reg bcd_start,
    output reg signed [24:0] bin_raw,
    output wire [31:0] weight_bcd,
    output wire bcd_done,
    output wire bcd_busy,
   
	// UART signals
    output wire       uart_busy,
    output wire       uart_byte_done,
    output reg        uart_tx_en,
    output reg [7:0]  uart_tx_byte,
    output reg fsm_done,
    output reg [79:0] debug_state
*/
);
	//-------------------------------------------------------------------------
    // PLL: onboard 27 MHz -> system 50 MHz
    //-------------------------------------------------------------------------
    wire i_clk_50m;
    wire pll_lock;
    //wire rst_async_n;
    //wire rst_sys_n;
    //reg  [1:0] reset_sync;

    PLL50M u_pll (
        .clkin  (i_clk),
        .clkout (i_clk_50m),
        .lock   (pll_lock)
    );
    //-------------------------------------------------------------------------
    // Clock-derived parameters (all system logic uses 50 MHz)
    //-------------------------------------------------------------------------
    localparam integer SCK_HALF_DIV  = SYS_FREQ_HZ / (2 * SCK_FREQ_HZ);
    localparam integer CYCLE_PER_BIT = SYS_FREQ_HZ / BAUD_RATE;
    localparam integer DELAY_CYCLES  = (SYS_FREQ_HZ / 1000) * DELAY_MS;

    localparam N_SAMPLE = 5;

    	reg [3:0] r_state;
    	// HX711 signals
    	reg         hx711_start;
    	wire [23:0] hx711_raw_unit;
        wire        hx711_done;
    	wire        hx711_busy;
        reg [3:0]   hx711_sample_cnt;

    	wire [23:0] hx711_raw;
     	wire[23:0] hx711_raw_mean;
        wire hx711_mean_done;

	// Tare / Net / Weight signals
    	wire               tare_pulse;
        wire  signed [23:0] o_tare;
    	wire                o_tare_updated;
    	wire  signed [24:0] o_net;
    	wire                o_net_done;
    	wire signed [24:0] weight_g;
    	wire               weight_done;
 

	// Bin To BCD signals
	reg bcd_start;
	reg signed [24:0] bin_raw;
	wire [31:0] weight_bcd;
	wire bcd_done;
	wire bcd_busy;


	// UART signals
        wire       uart_busy;
    	wire       uart_byte_done;
    	reg        uart_tx_en;
    	reg [7:0]  uart_tx_byte;

    reg fsm_done;

    //-------------------------------------------------------------------------
    // Top-level FSM and message buffer
    // Message format -> W: dddddddd\r\n
    // WEIGHT is sign + 8 decimal digits.
    // Total length = 13 characters.
    //-------------------------------------------------------------------------
    localparam [3:0] IDLE       = 4'd0,
		     SAMPLE	= 4'd1,
                     WEIGHT_CAL = 4'd2,
                     START_BCD  = 4'd3,
                     WAIT_BCD   = 4'd4,
                     BUILD_MSG  = 4'd5,
                     SEND_CHAR  = 4'd6,
                     WAIT_CHAR  = 4'd7,
                     FSM_DONE   = 4'd8;

     localparam integer MSG_LEN = 13;

     reg [3:0] char_idx;
     reg [7:0] msg_buffer [0:MSG_LEN-1];
/* // Block debug states FSM
 always @(*) begin
	case(r_state) 
		IDLE: 		debug_state <= "IDLE";
		SAMPLE: 	debug_state <= "SAMPLE";
		WEIGHT_CAL: 	debug_state <= "WEIGHT_CAL";
		START_BCD: 	debug_state <= "START_BCD";
		WAIT_BCD: 	debug_state <= "WAIT_BCD";
		BUILD_MSG: 	debug_state <= "BUILD_MSG";
		SEND_CHAR: 	debug_state <= "SEND_CHAR";
		WAIT_CHAR: 	debug_state <= "WAIT_CHAR";
		FSM_DONE:	debug_state <= "FSM_DONE";
		default: 	debug_state <= "IDLE";
	endcase
 end
*/
 // Trigger one pulse to start hx711 controller
 always@(posedge i_clk_50m or negedge i_rst_n) begin
	if(!i_rst_n) hx711_start <= 1'b0;
	else begin
	    hx711_start <= 1'b0;
	    if( (r_state == IDLE)&&(!uart_busy) ) hx711_start <= 1'b1;
	end
 end

 always@(posedge i_clk_50m or negedge i_rst_n) begin
	if(!i_rst_n) begin
	    r_state <= IDLE;
	    hx711_sample_cnt <= 4'd0;
	    bin_raw <= 24'sd0;
	    bcd_start <= 1'b0;
	    uart_tx_en 	<= 1'b0;
	    fsm_done <= 1'b0;
	    uart_tx_byte <= 8'd0;
	end
	else begin
	    bcd_start <= 1'b0;
	    uart_tx_en 	<= 1'b0;
	    fsm_done <= 1'b0;
	    case(r_state)
		IDLE: begin
		    if(!uart_busy) r_state <= SAMPLE;
		end
		SAMPLE: begin
		    if( hx711_done) begin
			if(hx711_sample_cnt < N_SAMPLE-1) begin
			    r_state <= IDLE;
			    hx711_sample_cnt <= hx711_sample_cnt + 4'd1;
			end
			else begin
			    hx711_sample_cnt <= 4'd0;
			    r_state <= WEIGHT_CAL;
			end
		    end
		end
		WEIGHT_CAL: begin
		    if(weight_done) begin
			bin_raw <= weight_g;
			r_state <= START_BCD;
		    end
		end
		START_BCD:begin
		    bcd_start <= 1'b1;
		    r_state <= WAIT_BCD;
		end
		WAIT_BCD: begin
		    if(bcd_done) r_state <= BUILD_MSG;
		end
		BUILD_MSG: begin
		    // WEIGHT: W: + space + 8 decimal digits (BCD -> ASCII)
                    msg_buffer[0] <= "W";
                    msg_buffer[1] <= ":";
                    msg_buffer[2] <= " ";
                    msg_buffer[3] <= "0" + {4'd0, weight_bcd[31:28]};
                    msg_buffer[4] <= "0" + {4'd0, weight_bcd[27:24]};
                    msg_buffer[5] <= "0" + {4'd0, weight_bcd[23:20]};
                    msg_buffer[6] <= "0" + {4'd0, weight_bcd[19:16]};
                    msg_buffer[7] <= "0" + {4'd0, weight_bcd[15:12]};
                    msg_buffer[8] <= "0" + {4'd0, weight_bcd[11:8]};
                    msg_buffer[9] <= "0" + {4'd0, weight_bcd[7:4]};
                    msg_buffer[10] <= "0" + {4'd0, weight_bcd[3:0]};
                    // Carriage return + line feed
                    msg_buffer[MSG_LEN-2] <= 8'h0D;
                    msg_buffer[MSG_LEN-1] <= 8'h0A;

                    char_idx  <= 4'd0;
                    r_state <= SEND_CHAR;
		end		
		SEND_CHAR: begin 
		    uart_tx_byte <= msg_buffer[char_idx];
		    uart_tx_en 	<= 1'b1;
		    r_state <= WAIT_CHAR;
		end
		WAIT_CHAR: begin 
		    if(uart_byte_done) begin
			if(char_idx < MSG_LEN-1) begin
			    char_idx <= char_idx + 4'd1;
			    r_state <= SEND_CHAR;
			end
		 	else begin
			    char_idx <= 4'd0;
			    r_state <= FSM_DONE;
			end
		    end
		end
		FSM_DONE: begin
		    fsm_done <= 1'b1;
		    r_state <= IDLE;
		end
		default: r_state <= IDLE;
	    endcase
	end
 end


   //-------------------------------------------------------------------------
   // Debounce button
   //-------------------------------------------------------------------------
    key_filter k1(
    	.i_clk(i_clk_50m),
    	.i_rst_n(i_rst_n),
    	.i_key(i_tare_btn_n),
    	.o_key(tare_pulse)
    );

    //-------------------------------------------------------------------------
    // HX711 controller
    //-------------------------------------------------------------------------
	
    hx711_controller #(
        .SCK_HALF_DIV(SCK_HALF_DIV)
    ) u_hx711 (
        .i_clk        (i_clk_50m),
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
        .i_clk(i_clk_50m), 
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
	

    Tare_Weight_Cal u_weight (
        .i_clk          (i_clk_50m),
        .i_rst_n        (i_rst_n),
        .i_raw          (hx711_raw),
        .i_data_valid   (hx711_mean_done),
        .i_tare_en      (tare_pulse),
        
	.o_tare(o_tare),
    	.o_tare_updated(o_tare_updated),
    	.o_net(o_net),
    	.o_net_done(o_net_done),
        .o_weight_g     (weight_g),
        .o_weight_done  (weight_done)
    );
 
    //-------------------------------------------------------------------------
    // Bin_To_BCD   
    //-------------------------------------------------------------------------
    Bin_To_BCD #(
	.SIZE_INPUT(25),
	.SIZE_OUTPUT(32)
    ) u_bcd(
	.i_clk(i_clk_50m), 
	.i_rst_n(i_rst_n), 
	.i_start(bcd_start),
	.i_bin(bin_raw),
	.o_bcd(weight_bcd),
	.o_bcd_done(bcd_done),
	.o_busy(bcd_busy),
	.debug_state()
    );

    //-------------------------------------------------------------------------
    // UART transmitter
    //-------------------------------------------------------------------------
    uart_tx_byte #(
        .CYCLE_PER_BIT(CYCLE_PER_BIT)
    ) u_uart (
        .i_clk      (i_clk_50m),
        .i_rst_n    (i_rst_n),
        .i_tx_en    (uart_tx_en),
        .i_data     (uart_tx_byte),
        .o_tx_data  (o_uart_tx),
        .o_busy     (uart_busy),
        .o_done     (uart_byte_done),
        .debug_state()
    );


endmodule