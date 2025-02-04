`timescale 1ns / 1ps

`define CLK_HALF_PERIOD     2
`define prescale            30

`define MAX_NEUR            8'd138
`define SPIKES_COUNT        1484

`define UART_BIT_INTERVAL   `CLK_HALF_PERIOD*`prescale*16

module test_inference ();

    logic clk;
    logic rst;
    logic rx, tx;

    initial begin
        clk = 1'b0;
        forever #`CLK_HALF_PERIOD clk = ~clk;
    end

    fpga_core #(
        .prescale(`prescale),
        .max_neurons(`MAX_NEUR)
    ) top (
        .clk(clk),
        .rst(rst),
        .rxd(rx),
        .txd(tx)
    );

    logic [7:0] aers [`SPIKES_COUNT-1:0];

    initial begin
        $readmemh("synapse.mem", top.tinyODIN_inst.synaptic_core_0.synarray_0.SRAM);
        $readmemh("neuron.mem", top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM);
        $readmemh("spikes.mem", aers);
    end

    /**
    ***** sim *****
    */

    integer k;

    initial begin
        rst = 1'b1;
        wait_ns(20);
        rst = 1'b0;
        wait_ns(10);

        for (k = 0; k < `SPIKES_COUNT; k=k+1) begin
            if (aers[k] == 'hFF)
                uart_send_aer(.address({1'b0, 1'b1, 8'hFF}), .odin_rx(rx));
            else
                uart_send_aer(.address({1'b0, 1'b0, aers[k]}), .odin_rx(rx));
        end

        wait_ns(500);
        $finish;
    end

    /**
    ***** tasks *****
    */
    task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask

    task automatic uart_send_aer (
        input logic [9:0] address,
        ref   logic       odin_rx
    );
        reg [7:0] payload = {4'b0010, 2'd0, address[9:8]};
        send_uart_data(.data(payload), .programmer_tx(odin_rx));
        send_uart_data(.data(address[7:0]), .programmer_tx(odin_rx));
    endtask

    task automatic send_uart_data (
        input logic    [7:0] data,
        ref   logic programmer_tx
    );
        programmer_tx = 1'b0; //start

        for(integer i=0; i<8; i+=1) begin
            wait_ns(`UART_BIT_INTERVAL);
            programmer_tx = data[i];
        end

        wait_ns(`UART_BIT_INTERVAL);
        programmer_tx = 1'b1; //stop
        wait_ns(`UART_BIT_INTERVAL);
    endtask

    task automatic uart_get_aer (
        ref   logic    [7:0] data,
        ref   logic            rx
    );
        while (rx) wait_ns(1);

        for(integer i=0; i<8; i+=1) begin
            wait_ns(`UART_BIT_INTERVAL);
            data[i] = rx;
        end

        while (~rx) wait_ns(1);
    endtask

endmodule
