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
module ANITA3_deadtime_counter_v2(
		input clk250_i,
		input clk33_i,
		input dead_i,
		input pps_i,
		input pps_clk33_i,
		output [15:0] deadtime_o,
		output [21:0] deadtime_full_debug
		
    );

	reg deadtime_flag = 0;
	reg [5:0] deadtime_counter = {6{1'b0}};
	reg [1:0] deadtime_div32_clk33;
	reg [21:0] deadtime_counter_clk33 = {23{1'b0}};
	reg [15:0] deadtime_scaler = {16{1'b0}};
	always @(posedge clk250_i) begin
		if (pps_i) deadtime_counter <= {6{1'b0}};
		else if (dead_i) deadtime_counter <= deadtime_counter + 1; // so this is a counter mod 64 - the MSb will toggle 0-1 exactly once 
																					  // every 64 counts - on the and it will stay on for 32 clock cycles
																					  // minimum = 32*4ns=128 ns -  which is plenty to be latched on the 33MHz domain
	end
	// We're now counting 256 ns increments, so we need 22 bits.
	always @(posedge clk33_i) begin
		deadtime_div32_clk33 <= {deadtime_div32_clk33[0],deadtime_counter[5]};
		deadtime_flag <= deadtime_div32_clk33[0] && !deadtime_div32_clk33[1];
		if (pps_clk33_i) deadtime_counter_clk33 <= {22{1'b0}};
		else if (deadtime_flag) deadtime_counter_clk33 <= deadtime_counter_clk33 + 1;

		// These are now 256ns*2^6=16.384 us increments.
		if (pps_clk33_i) deadtime_scaler <= deadtime_counter_clk33[21:6];
	end
	assign deadtime_o = deadtime_scaler;
	assign deadtime_full_debug = deadtime_counter_clk33;
	
	
endmodule
