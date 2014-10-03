`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author:
// Author:
////////////////////////////////////////////////////////////////////////////////
module SURF_command_interface_v3(
		clk_i,
		event_id_i,
		buffer_i,
		start_i,
		busy_o,
		done_o,
		CMD_o,
		CMD_debug_o	
    );
	localparam NCLOCK_BITS = 3;
	parameter NUM_SURFS = 12;
   localparam [7:0] TX_HEADER = 8'hA6;
   
	input clk_i;
	input [31:0] event_id_i;
	input [1:0] buffer_i;
	input start_i;
	output done_o;
	output [NUM_SURFS-1:0] CMD_o;
	output CMD_debug_o;
	output busy_o;

	(* IOB = "TRUE" *)
	(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
	reg [NUM_SURFS-1:0] cmd_reg = {12{1'b1}};
	reg cmd = 1;   

   localparam FSM_BITS = 3;
   localparam [FSM_BITS-1:0] IDLE = 0;
   localparam [FSM_BITS-1:0] HEADER = 1;
   localparam [FSM_BITS-1:0] LAB_ID = 2;
   localparam [FSM_BITS-1:0] EVENT_3 = 3;
   localparam [FSM_BITS-1:0] EVENT_2 = 4;
   localparam [FSM_BITS-1:0] EVENT_1 = 5;
   localparam [FSM_BITS-1:0] EVENT_0 = 6;
   localparam [FSM_BITS-1:0] EVENT_SUM = 7;
   reg [FSM_BITS-1:0] state = IDLE;
   
   reg [7:0] tx_data_in = {8{1'b0}};
   reg [7:0] temp_sum = {8{1'b0}};
   wire [7:0] simple_event_sum = temp_sum + tx_data_in;

   reg start_seen = 0;

   wire buffer_half_full;
   wire serial_out;

   always @(posedge clk_i) begin
      if (start_i) start_seen <= 1;
      else if (state == HEADER) start_seen <= 0;

      if (state == HEADER) tx_data_in <= {{6{1'b0}},buffer_i};
      else if (state == LAB_ID) tx_data_in <= event_id_i[31:24];
      else if (state == EVENT_3) tx_data_in <= event_id_i[23:16];
      else if (state == EVENT_2) tx_data_in <= event_id_i[15:8];
      else if (state == EVENT_1) tx_data_in <= event_id_i[7:0];
      else if (state == EVENT_0) tx_data_in <= simple_event_sum;
      else tx_data_in <= TX_HEADER;
      
      // Call [31:24] = A, [23:16] = B, [15:8] = C, [7:0] = D
      // At EVENT_0, temp_sum = 0, and simple_event_sum = A
      // At EVENT_1, temp_sum = A, simple_event_sum == A + B
      // At EVENT_2, temp_sum = A+B, simple_event_sum = A + B + C
      // At EVENT_3, temp_sum = A+B+C, simple_event_sum = A+B+C+D
      // Then it's caught in tx_data_in and pushed into the FIFO at EVENT_SUM.
      if (state == EVENT_3 || state == EVENT_2 || state == EVENT_1) temp_sum <= simple_event_sum;
      else temp_sum <= {8{1'b0}};
   
      case (state)
         IDLE: if ((start_i || start_seen) && !buffer_half_full) state <= HEADER;
         HEADER: state <= LAB_ID;
         LAB_ID: state <= EVENT_3;
         EVENT_3: state <= EVENT_2;
         EVENT_2: state <= EVENT_1;
         EVENT_1: state <= EVENT_0;
         EVENT_0: state <= EVENT_SUM;
         EVENT_SUM: state <= IDLE;
      endcase
      
      cmd_reg <= {NUM_SURFS{serial_out}};
      cmd <= serial_out;
   end
   
   uart_tx u_transmitter(.data_in(tx_data_in),
                         .write_buffer(state != IDLE),
                         .reset_buffer(1'b0),
                         .buffer_full(),
                         .buffer_half_full(buffer_half_full),
                         .serial_out(serial_out),
                         
                         .clk(clk_i),
                         .en_16_x_baud(1'b1));
   
   assign done_o = (state == EVENT_SUM);
   assign CMD_o = cmd_reg;
   assign CMD_debug_o = cmd;
   assign busy_o = (state != IDLE);
endmodule
