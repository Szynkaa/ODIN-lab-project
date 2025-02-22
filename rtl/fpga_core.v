
module fpga_core #(parameter prescale=1,
                   parameter max_neurons = 255) (
    // General
    input  wire clk,
    input  wire rst,

    // UART
    input  wire rxd,
    output wire txd,

    // GPIO
    output wire [7:0] leds
);

    wire [7:0] rx_axis_tdata;
    wire       rx_axis_tvalid;
    wire       rx_axis_tready;

    wire [7:0] tx_axis_tdata;
    wire       tx_axis_tvalid;
    wire       tx_axis_tready;

    wire tx_busy;
    wire rx_busy;
    wire rx_overrun_error;

    reg  rx_overrun_error_hold;
    always @(posedge clk) begin
        if (rst)
            rx_overrun_error_hold <= 0;
        else if (rx_overrun_error)
            rx_overrun_error_hold <= 1'b1;
        else
            rx_overrun_error_hold <= rx_overrun_error_hold;
    end

    uart uart_inst (
        .clk(clk),
        .rst(rst),

        // AXI input
        .s_axis_tdata(tx_axis_tdata),
        .s_axis_tvalid(tx_axis_tvalid),
        .s_axis_tready(tx_axis_tready),

        // AXI output
        .m_axis_tdata(rx_axis_tdata),
        .m_axis_tvalid(rx_axis_tvalid),
        .m_axis_tready(rx_axis_tready),

        // UART interface
        .rxd(rxd),
        .txd(txd),


        // Status
        .tx_busy(tx_busy),
        .rx_busy(rx_busy),
        .rx_overrun_error(rx_overrun_error),
        .rx_frame_error(),

        // Configuration
        .prescale(prescale)
    );

    wire           CTRL_READBACK_EVENT = 0;
    wire           CTRL_PROG_EVENT;
    wire [2*8-1:0] CTRL_SPI_ADDR;
    wire [    1:0] CTRL_OP_CODE;
    wire [2*8-1:0] CTRL_PROG_DATA;

    wire       CFG_GATE_ACTIVITY;
    wire       CFG_OPEN_LOOP;
    wire       CFG_AER_SRC_CTRL_nNEUR;
    wire [7:0] CFG_MAX_NEUR = max_neurons;

    wire [9:0] AERIN_ADDR;
    wire       AERIN_REQ;
    wire       AERIN_ACK;

    assign leds[0] = CFG_GATE_ACTIVITY;
    assign leds[1] = rx_busy;
    assign leds[2] = rx_overrun_error_hold;
    assign leds[7:3] = tx_axis_tdata[4:0];

    axis_rx rx_handler (
        .clk(clk),
        .rst(rst),

        // AXI Stream input
        .s_axis_tdata(rx_axis_tdata),
        .s_axis_tvalid(rx_axis_tvalid),
        .s_axis_tready(rx_axis_tready),

        // Controler interface
        .CTRL_PROG_EVENT(CTRL_PROG_EVENT),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        .CTRL_OP_CODE(CTRL_OP_CODE),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),

        // Configuration registers
        .CFG_GATE_ACTIVITY(CFG_GATE_ACTIVITY),
        .CFG_OPEN_LOOP(CFG_OPEN_LOOP),
        .CFG_AER_SRC_CTRL_nNEUR(CFG_AER_SRC_CTRL_nNEUR),

        // AERIN output
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK)
    );

    tinyODIN tinyODIN_inst (
        // Global input     -------------------------------
        .CLK(clk),
        .RST(rst),

        // Controller write iface -------------------------
        .CTRL_READBACK_EVENT(CTRL_READBACK_EVENT),
        .CTRL_PROG_EVENT(CTRL_PROG_EVENT),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        .CTRL_OP_CODE(CTRL_OP_CODE),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),

        // Configuration    -------------------------------
        .CFG_GATE_ACTIVITY(CFG_GATE_ACTIVITY),
        .CFG_OPEN_LOOP(CFG_OPEN_LOOP),
        .CFG_AER_SRC_CTRL_nNEUR(CFG_AER_SRC_CTRL_nNEUR),
        .CFG_MAX_NEUR(CFG_MAX_NEUR),

        // Input 10-bit AER -------------------------------
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),

        // Output 8-bit AER -------------------------------
        .AEROUT_ADDR(tx_axis_tdata),
        .AEROUT_REQ(tx_axis_tvalid),
        .AEROUT_ACK(tx_busy),

        // Debug ------------------------------------------
        .SCHED_FULL()
    );

endmodule
