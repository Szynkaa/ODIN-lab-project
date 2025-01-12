`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/06/2025 08:22:19 PM
// Design Name: 
// Module Name: test_configurationWithUART
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_configurationWithUART();

    reg clk;
    reg rst;
    reg stream;
    
    reg [7:0] data = 8'b00010001;
    localparam addr_gate = 2'd0;
    localparam addr_loop = 2'd1;
    localparam addr_aer  = 2'd2;
    
    
    initial begin
        clk = 1'b0;
        rst = 1'b0;
        stream = 1'b1;
        
        #3 rst = 1'b1;
        #3 rst = 1'b0;
        
        
        data[3:2] = addr_gate;
        // transmit
        @(posedge clk) stream = 1'b0; //start
        for(int i=0; i<8; i+=1)
            #16 stream = data[i]; 
        #16 stream = 1'b1; //stop
        
        
        data[3:2] = addr_loop;
        // transmit
        #50 stream = 1'b0; //start
        for(int i=0; i<8; i+=1)
            #16 stream = data[i]; 
        #16 stream = 1'b1; //stop
        
        
        data[3:2] = addr_aer;
        // transmit
        #50 stream = 1'b0; //start
        for(int i=0; i<8; i+=1)
            #16 stream = data[i]; 
        #16 stream = 1'b1; //stop
        
        
        #50 $finish;

    end
    
    initial forever #1 clk = ~clk;
    
    fpga_core #(.prescale(1)) top (.clk(clk), .rst(rst), .rxd(stream));
endmodule
