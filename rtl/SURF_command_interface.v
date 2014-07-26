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
module SURF_command_interface(
		clk_i,
		event_id_i,
		buffer_i,
		start_i,
		busy_o,
		done_o,
		CMD_o,
		CMD_debug_o	
    );

	parameter NUM_SURFS = 12;

	input clk_i;
	input [31:0] event_id_i;
	input [1:0] buffer_i;
	input start_i;
	output done_o;
	output [NUM_SURFS-1:0] CMD_o;
	output CMD_debug_o;
	output busy_o;
	
	(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
	reg [NUM_SURFS-1:0] cmd_reg = {12{1'b0}};
	(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
	(* KEEP = "YES" *)
	reg cmd_debug = 0;
	
	reg [33:0] shift_reg = {34{1'b0}};
	reg [5:0] counter = {6{1'b0}};
	reg sending = 0;
	reg done = 0;
	wire cmd_reg_in = (!sending || done_o) ? start_i : shift_reg[0];
	// We need to send 36 total bits. 
	// Start bit sent at counter == 0.
	// Buffer ID sent at counter == 1, 2.
	// Event ID sent at 3,4,5,6, 7,8,9,10, 11,12,13,14, 15,16,17,18, 19,20,21,22 23,24,25,26 27,28,29,30 31,32,33,34.
	// When Counter == 34, assert done, the stop bit is sent.
	always @(posedge clk_i) begin
		cmd_reg <= {NUM_SURFS{cmd_reg_in}};
		cmd_debug <= cmd_reg_in;

		if (counter == 6'd34) done <= 1;
		else done <= 0;
		
		if (start_i) sending <= 1;
		else if (done) sending <= 0;		
		
		if (!sending) shift_reg <= {event_id_i,buffer_i};
		else shift_reg <= {1'b0,shift_reg[33:1]};

		if (done) counter <= 6'h00;
		else if (sending || start_i) counter <= counter + 1;
	end
	assign done_o = done;
	assign CMD_o = cmd_reg;
	assign CMD_debug_o = cmd_debug;
	assign busy_o = sending;
endmodule
