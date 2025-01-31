`timescale 1ns / 1ps


// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "tbench.sv" - Testbench file
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------

`define CLK_HALF_PERIOD             2
`define pc                          1

`define N 256 
`define M 8

`define PROGRAM_ALL_SYNAPSES      1
`define VERIFY_ALL_SYNAPSES       1
`define PROGRAM_NEURON_MEMORY     1
`define VERIFY_NEURON_MEMORY      1
`define DO_FULL_CHECK             1
`define     DO_OPEN_LOOP          1
`define     DO_CLOSED_LOOP        1
 
`define OPEN_LOOP          1'b1
`define AER_SRC_CTRL_nNEUR 1'b0
`define MAX_NEUR         8'd200
`define UART_BIT_INTERVAL `CLK_HALF_PERIOD*`pc*16



module WholeOdin();

    logic            CLK;
    logic            RST;
    
    logic            UART_config_rdy;
    logic            UART_param_checked;
    logic            SNN_initialized_rdy;
    
    logic            RX, TX;
    logic [  `M-1:0] AEROUT_ADDR;
    
    logic [    31:0] synapse_pattern , syn_data;
    logic [    31:0] neuron_pattern  , neur_data;
    logic [    31:0] shift_amt;
    logic [    15:0] addr_temp;

    logic        [ 6:0] param_leak_str;
    logic signed [11:0] param_thr;
    logic signed [11:0] mem_init;
    
    
    integer target_neurons[15:0];
    integer input_neurons[15:0];
    
    logic [7:0] aer_neur_spk;

    logic signed [11:0] vcore[255:0];
    integer time_window_check;

    integer i,j,k,n;
    integer phase;
            

    /***************************
      INIT 
	***************************/ 
    
    initial begin
        RX = 1'b1;
        TX = 1'b1;
        
        UART_config_rdy = 1'b0;
        UART_param_checked = 1'b0;
        SNN_initialized_rdy = 1'b0;
    end
    

  	/***************************
      CLK
	***************************/ 
	
	initial begin
		CLK = 1'b1; 
		forever begin
			wait_ns(`CLK_HALF_PERIOD);
            CLK = ~CLK; 
	    end
	end 
	
    
    /***************************
      RST
	***************************/
	
	initial begin 
        wait_ns(0.1);
        RST = 1'b0;
        wait_ns(100);
        RST = 1'b1;
        wait_ns(100);
        RST = 1'b0;
        wait_ns(100);
        UART_config_rdy = 1'b1;
        while (~UART_param_checked) wait_ns(1);
		wait_ns(100);
        RST = 1'b1;
        wait_ns(100);
        RST = 1'b0;
        wait_ns(100);
        SNN_initialized_rdy = 1'b1;
	end

    
    /***************************
      STIMULI GENERATION
	***************************/

	initial begin 
        while (~UART_config_rdy)
            wait_ns(1);
        
        /*****************************************************************************************************************************************************************************************************************
                                                                              PROGRAMMING THE CONTROL REGISTERS AND NEURON PARAMETERS THROUGH 8-bit UART
        *****************************************************************************************************************************************************************************************************************/

        uart_send_configuration (.addr(2'd0), .data(1'b1), .odin_rx(RX)); // CFG_GATE_ACTIVITY
        wait_ns(50);
        uart_send_configuration (.addr(2'd1), .data(`OPEN_LOOP), .odin_rx(RX)); // CFG_OPEN_LOOP
        wait_ns(50);
        uart_send_configuration (.addr(2'd2), .data(`AER_SRC_CTRL_nNEUR), .odin_rx(RX)); //CFG_AER_SRC_CTRL_nNEUR
//        spi_send (.addr({1'b0,1'b0,2'b00,16'd3 }), .data(`MAX_NEUR               ), .MISO(MISO), .MOSI(MOSI), .SCK(SCK)); //MAX_NEUR

        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    VERIFY THE NEURON PARAMETERS
        *****************************************************************************************************************************************************************************************************************/        

        $display("----- Starting verification of programmed SNN parameters");

        assert(top.CFG_GATE_ACTIVITY          ==  1'b1                   ) else $fatal(1, "GATE_ACTIVITY parameter not correct.");
        assert(top.CFG_OPEN_LOOP              == `OPEN_LOOP              ) else $fatal(1, "OPEN_LOOP parameter not correct.");
        assert(top.CFG_AER_SRC_CTRL_nNEUR     == `AER_SRC_CTRL_nNEUR     ) else $fatal(1, "AER_SRC_CTRL_nNEUR parameter not correct.");
        assert(top.CFG_MAX_NEUR            == `MAX_NEUR               ) else $fatal(1, "MAX_NEUR parameter not correct.");
        
        $display("----- Ending verification of programmed SNN parameters, no error found!");
        
        UART_param_checked = 1'b1;
        
        while (~SNN_initialized_rdy) wait_ns(1);
        

        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    PROGRAM NEURON MEMORY WITH TEST VALUES
        *****************************************************************************************************************************************************************************************************************/

        if (`PROGRAM_NEURON_MEMORY) begin
            $display("----- Starting programmation of neuron memory in the SNN through UART.");
            uart_send_configuration (.addr(2'd0), .data(1'b1), .odin_rx(RX)); // CFG_GATE_ACTIVITY
            neuron_pattern = {2{8'b01010101,8'b10101010}};
            for (i=0; i<`N; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    neur_data       = neuron_pattern >> (j<<3);
                    addr_temp[15:8] = j;
                    addr_temp[7:0]  = i;    // Each single neuron
                    uart_send_neuron(.byte_addr(addr_temp[9:8]),
                                     .word_addr(addr_temp[7:0]),
                                     .mask(8'h00),
                                     .data(neur_data[7:0]),
                                     .odin_rx(RX)
                                     );
                end
                if(!(i%10))
                    $display("programming neurons... (i=%0d/256)", i);
            end
            $display("----- Ending programmation of neuron memory in the SNN through UART.");
            uart_send_configuration (.addr(2'd0), .data(1'b0), .odin_rx(RX)); // disable CFG_GATE_ACTIVITY
        end else
            $display("----- Skipping programmation of neuron memory in the SNN through UART.");
            
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                        TEST NEURON MEMORY
        *****************************************************************************************************************************************************************************************************************/
        
        if (`VERIFY_NEURON_MEMORY && `PROGRAM_NEURON_MEMORY) begin
            $display("----- Starting verification of neuron memory in the SNN.");
            for (i=0; i<`N; i=i+1) begin
                assert(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[i] == neuron_pattern) else $fatal(1, "Memory of neuron %d not written/read correctly.", i);

                if(!(i%10))
                    $display("verifying neurons... (i=%0d/256)", i);
            end
            $display("----- Ending verification of neuron memory in the SNN, no error found!");
        end else
            $display("----- Skipping verification of neuron memory in the SNN.");
        
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                    PROGRAM SYNAPSE MEMORY WITH TEST VALUES
        *****************************************************************************************************************************************************************************************************************/
        
        if (`PROGRAM_ALL_SYNAPSES) begin
            uart_send_configuration (.addr(2'd0), .data(1'b1), .odin_rx(RX)); // CFG_GATE_ACTIVITY
            synapse_pattern = {4'd15,4'd7,4'd12,4'd13,4'd10,4'd5,4'd1,4'd2};
            $display("----- Starting programmation of all synapses in the SNN through UART.");
            for (i=0; i<8192; i=i+1) begin
                for (j=0; j<4; j=j+1) begin
                    syn_data        = synapse_pattern >> (j<<3);
                    addr_temp[15:13] = j;    // Each single byte in a 32-bit word
                    addr_temp[12:0 ] = i;    // Programmed address by address
                    uart_send_synapse (.byte_addr(addr_temp[14:13]),
                                       .word_addr(addr_temp[12:0]),
                                       .mask(8'h00),
                                       .data(syn_data[7:0]),
                                       .odin_rx(RX)
                                       );
                end
                if(!(i%500))
                    $display("programming synapses... (i=%0d/8192)", i);
            end
            uart_send_configuration (.addr(2'd0), .data(1'b0), .odin_rx(RX)); // disable CFG_GATE_ACTIVITY
            $display("----- Ending programmation of all synapses in the SNN through UART.");
        end else
            $display("----- Skipping programmation of all synapses in the SNN through UART.");
            
        
        /*****************************************************************************************************************************************************************************************************************
                                                                                                        TEST SYNAPSE MEMORY
        *****************************************************************************************************************************************************************************************************************/
        
        if (`VERIFY_ALL_SYNAPSES) begin
            $display("----- Starting verification of all synapses in the SNN.");
            for (i=0; i<8192; i=i+1) begin
                assert(top.tinyODIN_inst.synaptic_core_0.synarray_0.SRAM[i] == synapse_pattern) else $fatal(1, "Memory of synapse %d not written/read correctly.", i);
                
                if(!(i%500))
                    $display("verifying synapses... (i=%0d/8192)", i);
            end
            $display("----- Ending verification of all synapses in the SNN, no error found!");
        end else
            $display("----- Skipping verification of all synapses in the SNN.");
 

        /*****************************************************************************************************************************************************************************************************************
                                                                                                     SYSTEM-LEVEL CHECKING
        *****************************************************************************************************************************************************************************************************************/
           
        if (`DO_FULL_CHECK) begin
            // Initializing all neurons to zero
            $display("----- Disabling neurons 0 to 255.");  
            uart_send_configuration(.addr(2'd0), .data(1'd1), .odin_rx(RX)); // CFG_GATE_ACTIVITY (1) 
            for (i=0; i<`N; i=i+1) begin
                addr_temp[15:8] = 3;   // Programming only last byte for disabling a neuron
                addr_temp[7:0]  = i;   // Doing so for all neurons
                
                uart_send_neuron(.byte_addr(addr_temp[9:8]),
                                 .word_addr(addr_temp[7:0]),
                                 .mask(8'h7F),
                                 .data(8'h80),
                                 .odin_rx(RX)
                                 );
            end
            uart_send_configuration(.addr(2'd0), .data(1'd0), .odin_rx(RX)); // disable CFG_GATE_ACTIVITY (0)
            $display("----- Programming neurons done...");
            
            
            /*****************************************************************************************************************************************************************************************************************
                                                                                                            TEST NEURON MEMORY
            *****************************************************************************************************************************************************************************************************************/
            
            if (`VERIFY_NEURON_MEMORY) begin
                $display("----- Starting verification of neuron memory in the SNN.");
                for (i=0; i<`N; i=i+1) begin
                    assert(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[i][31] == 1'b1) else $fatal(1, "Neuron %d not disabled correctly.", i);
                end
                $display("----- Ending verification of neuron memory in the SNN, no error found!");
            end else
                $display("----- Skipping verification of neuron memory in the SNN.");

            for (phase=0; phase<2; phase=phase+1) begin


	            $display("--- Starting phase %d.", phase);

	            //Disable network operation
	            uart_send_configuration(.addr(2'd0), .data(1'd1), .odin_rx(RX)); // CFG_GATE_ACTIVITY (1)
                uart_send_configuration (.addr(2'd1), .data(1'd1), .odin_rx(RX)); // CFG_OPEN_LOOP (1)

	            $display("----- Starting programming of neurons 0,1,3,13,27,38,53,62,100,119,140,169,194,248,250,255.");
	            
	            target_neurons = '{255,250,248,194,169,140,119,100,62,53,38,27,13,3,1,0};
	            input_neurons  = '{255,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0};
	            
	            // Programming neurons
	            for (i=0; i<16; i=i+1) begin
	                shift_amt      = 32'b0;
	                
	                case (target_neurons[i]) 
	                    0 : begin
	                        param_leak_str  = (!phase) ?           7'd0     :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    1 : begin
	                        param_leak_str  = (!phase) ?           7'd1     :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd3);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    3 : begin
	                        param_leak_str  = (!phase) ?           7'd10    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd10);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    13 : begin
	                        param_leak_str  = (!phase) ?           7'd30    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd100);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    27 : begin
	                        param_leak_str  = (!phase) ?           7'd40    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd200);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    38 : begin
	                        param_leak_str  = (!phase) ?           7'd50    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd300);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    53 : begin
	                        param_leak_str  = (!phase) ?           7'd60    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd400);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    62 : begin
	                        param_leak_str  = (!phase) ?           7'd70    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd500);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    100 : begin
	                        param_leak_str  = (!phase) ?           7'd80    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd600);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    119 : begin
	                        param_leak_str  = (!phase) ?           7'd90    :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd700);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    140 : begin
	                        param_leak_str  = (!phase) ?           7'd100   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd800);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    169 : begin
	                        param_leak_str  = (!phase) ?           7'd110   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd900);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    194 : begin
	                        param_leak_str  = (!phase) ?           7'd127   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd2022);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    248 : begin
	                        param_leak_str  = (!phase) ?           7'd120   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1000);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    250 : begin
	                        param_leak_str  = (!phase) ?           7'd130   :           7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd1500);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    255 : begin
	                        param_leak_str  = (!phase) ?           7'd140  :            7'd10;
	                        param_thr       = (!phase) ? $signed( 12'd2047) : $signed( 12'd2000);
	                        mem_init        = (!phase) ? $signed( 12'd2046) : $signed( 12'd0);
	                    end
	                    default : $fatal("Error in neuron configuration"); 
	                endcase 
	                
	                neuron_pattern = {1'b0, param_leak_str, param_thr, mem_init};
	                                         
	                for (j=0; j<4; j=j+1) begin
	                    neur_data       = neuron_pattern >> shift_amt;
	                    addr_temp[15:8] = j;
	                    addr_temp[7:0]  = target_neurons[i];
	                    
                        uart_send_neuron(.byte_addr(addr_temp[9:8]),
                                         .word_addr(addr_temp[7:0]),
                                         .mask(8'h00),
                                         .data(neur_data[7:0]),
                                         .odin_rx(RX)
                                         );
	                    shift_amt       = shift_amt + 32'd8;
	                end          

			        for (j=0; j<16; j=j+1) begin
			            addr_temp[ 12:5] = input_neurons[j][7:0];
			            addr_temp[  4:0] = target_neurons[i][7:3];
			            addr_temp[14:13] = target_neurons[i][2:1];
			            uart_send_synapse (.byte_addr(addr_temp[14:13]),
                                           .word_addr(addr_temp[12:0]),
                                           .mask(8'h00),
                                           .data({input_neurons[j][3:0],input_neurons[j][3:0]}),
                                           .odin_rx(RX)
                                           ); // Synapse value = pre-synaptic neuron index 4 LSBs
			        end

                end


                if (`DO_OPEN_LOOP) begin
    	            //Re-enable network operation (CFG_OPEN_LOOP stays at 1)
    	            uart_send_configuration(.addr(2'd0), .data(1'b0), .odin_rx(RX)); // CFG_GATE_ACTIVITY (0)
    	            
    	            $display("----- Starting stimulation pattern.");

                    for (n=0; n<256; n++)
                        vcore[n] = $signed(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[n][11:0]);

                    if (!phase) begin

                    	for (j=0; j<2050; j=j+1) begin
                    	    uart_send_aer(.address({1'b0,1'b1,8'hFF}), .odin_rx(RX));
                            wait_ns(2000);

                            for (n=0; n<256; n++)
                                vcore[n] = $signed(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                        end

                    	wait_ns(10000);

                        /*
                         * Here, all neurons but number 0 should be at a membrane potential of 0
                         */
                        for (j=0; j<16; j=j+1)
                            assert ($signed(vcore[target_neurons[j]]) == (((target_neurons[j] > 0) && (target_neurons[j] < `MAX_NEUR)) ? $signed(12'd0) : $signed(12'd2046))) else $fatal(1, "Issue in open-loop experiments: membrane potential of neuron %d not correct after leakage",target_neurons[j]);


                    end else begin

                    	for (j=0; j<16; j=j+1)
    	                	for (k=0; k<10; k=k+1) begin
    	                	    uart_send_aer(.address({1'b0,1'b0,input_neurons[j][7:0]}), .odin_rx(RX));
//    	                		aer_send (.addr_in({1'b0,1'b0,input_neurons[j][7:0]}), .addr_out(AERIN_ADDR), .ack(AERIN_ACK), .req(AERIN_REQ)); //Neuron events
                                wait_ns(2000);
                    
                                for (n=0; n<256; n++)
                                    vcore[n] = $signed(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                            end

                    	wait_ns(10000);

                		/*
                		 * Here, neurons that did not fire (all except 0,1,3,13,27) should be at mem pot -80
                		 */
                        for (j=0; j<16; j=j+1)
                            if ((target_neurons[j] > 27) && (target_neurons[j] < `MAX_NEUR))
                                assert ($signed(vcore[target_neurons[j]]) == $signed(-12'd80)) else $fatal(1, "Issue in open-loop experiments: membrane potential of neuron %d not correct after stimulation",target_neurons[j]);


                        for (j=0; j<100; j=j+1) begin
                            uart_send_aer(.address({1'b0,1'b1,8'hFF}), .odin_rx(RX));
                            wait_ns(2000);

                            for (n=0; n<256; n++)
                                vcore[n] = $signed(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                        end

                        wait_ns(10000);

                        /*
                         * Here, all mem pots should be back to 0
                         */
                        for (j=0; j<16; j=j+1)
                            assert ($signed(vcore[target_neurons[j]]) == $signed(12'd0)) else $fatal(1, "Issue in open-loop experiments: membrane potential of neuron %d not correct after leakage",target_neurons[j]);

                        fork
                            // Thread 1
                        	for (k=0; k<300; k=k+1) begin
                                uart_send_aer(.address({1'b0,1'b0,input_neurons[7][7:0]}), .odin_rx(RX));
                                wait_ns(2000);

                                for (n=0; n<256; n++)
                                    vcore[n] = $signed(top.tinyODIN_inst.neuron_core_0.neurarray_0.SRAM[n][11:0]);
                            end

                            //Thread 2
                             /*
                             * Here, neuron 194 (with the highest membrane potential among enabled neurons) should fire. Neuron 248, 250 or 255 should be disabled.
                             */
                            while (aer_neur_spk != 8'd194) begin
                                assert ((aer_neur_spk != 8'd248) && (aer_neur_spk != 8'd250) && (aer_neur_spk != 8'd255)) else $fatal(1, "Issue in open-loop experiments: neurons 248, 250 or 255 should be disabled.");
                                wait_ns(1);
                            end
                        join

                    	wait_ns(100000);

                    end   

                end 


                if (`DO_CLOSED_LOOP) begin

                    //Re-enable network operation
                    uart_send_configuration (.addr(2'd0), .data(1'b0), .odin_rx(RX)); // CFG_GATE_ACTIVITY (0)
                    uart_send_configuration (.addr(2'd1), .data(1'b0), .odin_rx(RX)); // CFG_OPEN_LOOP (0)
                    
                    $display("----- Starting stimulation pattern.");
                    

                    if (phase) begin

                        //Start monitoring output spikes in the console
                        uart_send_aer(.address({1'b1,1'b0,{4'h5,4'd3}}), .odin_rx(RX)); //Virtual value-5 event to neuron 3
                        uart_send_aer(.address({1'b1,1'b0,{4'h5,4'd3}}), .odin_rx(RX)); //Virtual value-5 event to neuron 3
                        /*
                         * Here, the correct output firing sequence is 3,0,1,0.
                         */
                        uart_get_aer(.data(AEROUT_ADDR), .rx(TX));
                        assert (AEROUT_ADDR == 8'd3) else $fatal(1, "Issue in closed-loop experiments: first spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        uart_get_aer(.data(AEROUT_ADDR), .rx(TX));
                        assert (AEROUT_ADDR == 8'd0) else $fatal(1, "Issue in closed-loop experiments: second spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        uart_get_aer(.data(AEROUT_ADDR), .rx(TX));
                        assert (AEROUT_ADDR == 8'd1) else $fatal(1, "Issue in closed-loop experiments: third spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        uart_get_aer(.data(AEROUT_ADDR), .rx(TX));
                        assert (AEROUT_ADDR == 8'd0) else $fatal(1, "Issue in closed-loop experiments: fourth spike of the output sequence is not correct, received %d", AEROUT_ADDR);
                        time_window_check = 0;
                        while (time_window_check < 10000) begin
                            assert (!top.tinyODIN_inst.AEROUT_REQ) else $fatal(1, "There should not be more than 4 output spikes in the closed-loop experiments, received %d", AEROUT_ADDR);
                            wait_ns(1);
                            time_window_check += 1;
                        end
                    end

                end

            end

            $display("----- No error found -- All tests passed! :-)"); 

        end else
            $display("----- Skipping scheduler checking."); 
 
// ________END_TODO____________

 

        wait_ns(500);
        $finish;
        
    end
    
    
    /***************************
      SNN INSTANTIATION
	***************************/

    fpga_core #(.prescale(`pc), .max_neurons(`MAX_NEUR)) top (.clk(CLK), .rst(RST), .rxd(RX), .txd(TX));
    
    /***********************************************************************
						    TASK IMPLEMENTATIONS
    ************************************************************************/ 

    /***************************
	 SIMPLE TIME-HANDLING TASKS
	***************************/
	
	// These routines are based on a correct definition of the simulation timescale.
	task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask

    
    /***************************
	 AER send event
	***************************/
    
    task automatic aer_send (
        input  logic [`M+1:0] addr_in,
        ref    logic [`M+1:0] addr_out,
        ref    logic          ack,
        ref    logic          req
    );
        while (ack) wait_ns(1);
        addr_out = addr_in;
        wait_ns(5);
        req = 1'b1;
        while (!ack) wait_ns(1);
        wait_ns(5);
        req = 1'b0;
	endtask


    /***************************
	 UART send data
	***************************/
	
	task automatic uart_send_configuration (
	   input logic [1:0]  addr,
	   input logic        data,
	   ref   logic        odin_rx
    );
        reg [7:0] payload = {4'b0001, addr, 1'b0, data};
        send_uart_data(.data(payload), .programmer_tx(odin_rx));
    endtask
    
    task automatic uart_send_neuron (
	   input logic [1:0]  byte_addr,
	   input logic [7:0]  word_addr,
	   input logic [7:0]  mask,
	   input logic [7:0]  data,
	   ref   logic        odin_rx
    );
        reg [7:0] payload = {4'b0100, 2'd0, byte_addr};
        send_uart_data(.data(payload), .programmer_tx(odin_rx));
        send_uart_data(.data(word_addr), .programmer_tx(odin_rx));
        send_uart_data(.data(mask), .programmer_tx(odin_rx));
        send_uart_data(.data(data), .programmer_tx(odin_rx));
    endtask
    
    task automatic uart_send_synapse (
	   input logic [1:0]  byte_addr,
	   input logic [12:0] word_addr,
	   input logic [7:0]  mask,
	   input logic [7:0]  data,
	   ref   logic        odin_rx
    );
        reg [7:0] payload = {1'b1, byte_addr, word_addr[12:8]};
        send_uart_data(.data(payload), .programmer_tx(odin_rx));
        send_uart_data(.data(word_addr[7:0]), .programmer_tx(odin_rx));
        send_uart_data(.data(mask), .programmer_tx(odin_rx));
        send_uart_data(.data(data), .programmer_tx(odin_rx));
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
        
    
    /***************************
	 UART read AER
	***************************/
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
