
module fpga #(parameter prescale=50_000_000 / (8 * 115_200)) (
    // General
    input  wire clk_100_in,
    input  wire rst,

    // UART
    input  wire rxd,
    output wire txd,

    // GPIO
    output wire [7:0] leds
);

    wire clk_50;
    wire mmcm_clk_fb;

    // 50MHz from 100MHz
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(10.000),
        .CLKOUT0_DIVIDE_F(20.000)
    ) MMCME2_BASE_inst (
        .CLKOUT0(clk_50),
        .CLKFBOUT(mmcm_clk_fb),
        .CLKIN1(clk_100_in),
        .PWRDWN(1'b0),
        .RST(rst),
        .CLKFBIN(mmcm_clk_fb)
    );

    fpga_core #(
        .prescale(prescale),
        .max_neurons(137)
    ) fpga_core_inst (
        // General
        .clk(clk_50),
        .rst(rst),

        // UART
        .rxd(rxd),
        .txd(txd),

        // GPIO
        .leds(leds)
    );

endmodule
