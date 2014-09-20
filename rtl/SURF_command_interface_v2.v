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
module SURF_command_interface_v2(
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
	reg [NUM_SURFS-1:0] cmd_reg = {12{1'b0}};
	reg cmd = 0;

	// WORLD'S EASIEST COMMAND SENDER
	reg starting = 0;
	reg sending = 0;
	reg [NCLOCK_BITS-1:0]  counter = {NCLOCK_BITS{1'b0}};
	wire [NCLOCK_BITS:0] counter_plus_one = counter + 1;
	reg [35:0] data_shift_reg = {36{1'b0}};
	reg done = 0;
	reg ce = 0;
	always @(posedge clk_i) begin
		cmd <= !data_shift_reg[0] && sending;
		cmd_reg <= {12{cmd}};

		counter <= counter_plus_one;
		ce <= counter_plus_one[NCLOCK_BITS];
		
		if (start_i) starting <= 1;
		else if (ce) starting <= 0;
		
		if (ce) begin
			if (starting) sending <= 1;
			else if (data_shift_reg[35:1] == {35{1'b0}}) sending <= 0;
		end
		
		if (ce && (data_shift_reg[35:1] == {35{1'b0}}) && sending) done <= 1;
		else done <= 0;
		
		
		
		// start_i -> starting = 1
		// @ce + starting=1 -> sending = 1, starting = 0
		// @ce + (data_shift_reg[35:1] == {35{1'b0}}) -> sending = 0
		// done = @ce + (data_shift_reg[35:1] == {35{1'b0}}) && sending
		// cmd is !data_shift_reg[0] && sending
				
		if (ce) begin
			if (starting) data_shift_reg <= {1'b1,~event_id_i,~buffer_i,1'b0};
			else data_shift_reg <= {1'b0,data_shift_reg[35:1]};
		end
	end
	
	assign done_o = done;
	assign CMD_o = cmd_reg;
	assign CMD_debug_o = cmd;
	assign busy_o = sending;
endmodule
