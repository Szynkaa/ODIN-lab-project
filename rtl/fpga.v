
module fpga #(parameter prescale=85_000_000 / (8 * 115_200)) (
    // General
    input  wire clk_100_in,
    input  wire rst,

    // UART
    input  wire rxd,
    output wire txd
);

    wire clk_85;
    wire mmcm_clk_fb;

    // 85MHz from 100MHz
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .DIVCLK_DIVIDE(4),
        .CLKFBOUT_MULT_F(40.375),
        .CLKOUT0_DIVIDE_F(11.875)
    ) MMCME2_BASE_inst (
        .CLKOUT0(clk_85),
        .CLKFBOUT(mmcm_clk_fb),
        .CLKIN1(clk_100_in),
        .PWRDWN(1'b0),
        .RST(rst),
        .CLKFBIN(mmcm_clk_fb)
    );

    fpga_core #(
        .prescale(prescale)
    ) fpga_core_inst (
        // General
        .clk(clk_85),
        .rst(rst),

        // UART
        .rxd(rxd),
        .txd(txd)
    );

endmodule
