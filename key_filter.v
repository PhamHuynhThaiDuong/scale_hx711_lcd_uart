module key_filter (
    input  wire i_clk,
    input  wire i_rst_n,
    input  wire i_key,
    output wire o_key
);

    parameter STABLE_CNT = 1_000_000;   // ~20 ms @ 50 MHz
    localparam integer COUNT_WIDTH = 20;

    reg [1:0] key_reg;
    wire      key_sync;

    // ??ng b?
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            key_reg <= 2'b11;
        else begin
            key_reg[0] <= i_key;
            key_reg[1] <= key_reg[0];
        end
    end

    assign key_sync = key_reg[1];

    // Debounce
    reg key_state;
    reg [COUNT_WIDTH-1:0] count;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            count     <= 0;
            key_state <= 1'b1;
        end else if (key_sync == key_state) begin
            count <= 0;
        end else begin
            if (count == STABLE_CNT-1) begin
                key_state <= key_sync;
                count     <= 0;
            end else
                count <= count + 1;
        end
    end

    // Edge detect (nh?n = 1?0)
    reg key_prev;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            key_prev <= 1'b1;
        else
            key_prev <= key_state;
    end

    assign o_key = key_prev & (~key_state);   // xung 1 cycle khi nh?n

endmodule
