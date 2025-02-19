
module axis_rx (
    input wire clk,
    input wire rst,

    // AXI Stream input
    input  wire [7:0] s_axis_tdata,
    input  wire       s_axis_tvalid,
    output reg        s_axis_tready,

    // Controler interface
    output reg            CTRL_PROG_EVENT,
    output reg  [2*8-1:0] CTRL_SPI_ADDR,
    output reg  [    1:0] CTRL_OP_CODE,
    output reg  [2*8-1:0] CTRL_PROG_DATA,

    // Configuration registers
    output reg        CFG_GATE_ACTIVITY,
    output reg        CFG_OPEN_LOOP,
    output reg        CFG_AER_SRC_CTRL_nNEUR,

    // AERIN output
    output reg  [9:0] AERIN_ADDR,
    output reg        AERIN_REQ,
    input  wire       AERIN_ACK
);

    /*
    synapse write
    byte 3                             | byte 2         | byte 1    | byte 0
    1, byte_addr<1:0>, word_addr<12:8> | word_addr<7:0> | mask<7:0> | date<7:0>

    neuron write
    byte 3                   | byte 2         | byte 1    | byte 0
    0100, --, byte_addr<1:0> | word_addr<7:0> | mask<7:0> | date<7:0>

    AER in
    byte 1             | byte 0
    0010, --, AER<9:8> | AER<7:0>

    configuration write
    byte 0
    0001, cfg_addr<1:0>, -, cfg_data<0>
    */

    typedef enum {
        IDLE,
        CFG_W,
        NEURON_W,
        SYNAPSE_W,
        WRITE_WAIT,
        AERIN_W,
        AERIN_WAIT
    } states;

    states state, next_state, prev_state;

    reg [2:0] byte_cnt;
    reg [31:0] bytes;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            prev_state <= IDLE;
        end
        else begin
            state <= next_state;
            prev_state <= state;
        end
    end

    always @* begin
        case (state)
            IDLE        :   if      (s_axis_tvalid)
                                if      (s_axis_tdata[7:4] == 4'b0001)  next_state = CFG_W;
                                else if (s_axis_tdata[7:4] == 4'b0100)  next_state = NEURON_W;
                                else if (s_axis_tdata[7:7] == 1'b1)     next_state = SYNAPSE_W;
                                else if (s_axis_tdata[7:4] == 4'b0010)  next_state = AERIN_W;
                                else                                    next_state = IDLE;
                            else                                        next_state = IDLE;

            CFG_W       :                                               next_state = IDLE;

            NEURON_W    :   if   (byte_cnt == 3'd4)                     next_state = WRITE_WAIT;
                            else                                        next_state = NEURON_W;

            SYNAPSE_W   :   if   (byte_cnt == 3'd4)                     next_state = WRITE_WAIT;
                            else                                        next_state = SYNAPSE_W;

            WRITE_WAIT  :                                               next_state = IDLE;

            AERIN_W     :   if   (byte_cnt == 3'd2)                     next_state = AERIN_WAIT;
                            else                                        next_state = AERIN_W;

            AERIN_WAIT  :   if   (AERIN_ACK)                            next_state = IDLE;
                            else                                        next_state = AERIN_WAIT;

            default     :                                               next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            byte_cnt <= 3'b0;
            bytes <= 32'b0;
            s_axis_tready <= 1'b0;
        end
        else if (state == CFG_W || state == NEURON_W || state == SYNAPSE_W || state == AERIN_W) begin
            if (s_axis_tvalid & ~s_axis_tready) begin
                byte_cnt <= byte_cnt + 1;
                bytes <= {bytes[23:0], s_axis_tdata};
                s_axis_tready <= 1'b1;
            end else begin
                byte_cnt <= byte_cnt;
                bytes <= bytes;
                s_axis_tready <= 1'b0;
            end
        end
        else begin
            byte_cnt <= 3'b0;
            bytes <= bytes;
            s_axis_tready <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            CTRL_PROG_EVENT <= 1'b0;
            CTRL_SPI_ADDR <= 16'b0;
            CTRL_OP_CODE <= 2'b00;
            CTRL_PROG_DATA <= 16'b0;
        end
        else if (state == WRITE_WAIT) begin
            if      (prev_state == NEURON_W) begin
                CTRL_PROG_EVENT <= 1'b1;
                CTRL_SPI_ADDR <= {6'b0, bytes[25:16]};
                CTRL_OP_CODE <= 2'b01;
                CTRL_PROG_DATA <= bytes[15:0];
            end
            else if (prev_state == SYNAPSE_W) begin
                CTRL_PROG_EVENT <= 1'b1;
                CTRL_SPI_ADDR <= {2'b0, bytes[30:16]};
                CTRL_OP_CODE <= 2'b10;
                CTRL_PROG_DATA <= bytes[15:0];
            end
            else begin
                CTRL_PROG_EVENT <= 1'b0;
                CTRL_SPI_ADDR <= CTRL_SPI_ADDR;
                CTRL_OP_CODE <= CTRL_OP_CODE;
                CTRL_PROG_DATA <= CTRL_PROG_DATA;
            end
        end
        else begin
            CTRL_PROG_EVENT <= 1'b0;
            CTRL_SPI_ADDR <= CTRL_SPI_ADDR;
            CTRL_OP_CODE <= CTRL_OP_CODE;
            CTRL_PROG_DATA <= CTRL_PROG_DATA;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            AERIN_ADDR <= 10'b0;
            AERIN_REQ <= 1'b0;
        end
        else if (state == AERIN_WAIT) begin
            if (AERIN_ACK)
                AERIN_REQ <= 1'b0;
            else begin
                AERIN_ADDR <= bytes[9:0];
                AERIN_REQ <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            CFG_GATE_ACTIVITY <= 1'b0;
            CFG_OPEN_LOOP <= 1'b0;
            CFG_AER_SRC_CTRL_nNEUR <= 1'b0;
        end
        else if (state == IDLE && prev_state == CFG_W) begin
            if      (bytes[3:2] == 2'd0) CFG_GATE_ACTIVITY <= bytes[0];
            else if (bytes[3:2] == 2'd1) CFG_OPEN_LOOP <= bytes[0];
            else if (bytes[3:2] == 2'd2) CFG_AER_SRC_CTRL_nNEUR <= bytes[0];
        end
    end

endmodule
