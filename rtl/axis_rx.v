
module axis_rx (
    input wire clk,
    input wire rst,

    // AXI Stream input
    input  wire [7:0] s_axis_tdata,
    input  wire       s_axis_tvalid,
    output wire       s_axis_tready,

    // Controler interface
    output reg            CTRL_READBACK_EVENT,
    output reg            CTRL_PROG_EVENT,
    output reg  [2*8-1:0] CTRL_SPI_ADDR,
    output reg  [    1:0] CTRL_OP_CODE,
    output reg  [2*8-1:0] CTRL_PROG_DATA,

    // Configuration registers
    output reg        CFG_GATE_ACTIVITY,
    output reg        CFG_OPEN_LOOP,
    output reg        CFG_AER_SRC_CTRL_nNEUR,
    output reg  [7:0] CFG_MAX_NEUR,

    // input AER
    output reg  [9:0] AERIN_ADDR,
	output reg        AERIN_REQ,
	input  wire       AERIN_ACK
);

    /*
    neuron write
    byte 3                  | byte 2         | byte 1    | byte 0
    01 ----, byte_addr<1:0> | word_addr<7:0> | mask<7:0> | date<7:0>

    synapse write
    byte 3                              | byte 2         | byte 1    | byte 0
    10, byte_addr<1:0>, word_addr<11:8> | word_addr<7:0> | mask<7:0> | date<7:0>

    AER in
    byte 1            | byte 0
    11 ----, AER<9:8> | AER<7:0>
    */

    assign CTRL_READBACK_EVENT = 0;

    // TODO state machine to handle above operations and replace SPI_slave module

endmodule
