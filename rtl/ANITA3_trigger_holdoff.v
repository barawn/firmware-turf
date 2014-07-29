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
module ANITA3_trigger_holdoff(
		input clk250_i,
		input trig_i,
		output holdoff_o
    );

	reg holdoff_div_2 = 0;
	reg [3:0] holdoff_counter = {4{1'b0}};
	wire [4:0] holdoff_counter_plus_one = holdoff_counter + 1;
	reg trigger_holdoff = 0;
	reg clear_holdoff = 0;
	always @(posedge clk250_i) begin
		if (clear_holdoff) trigger_holdoff <= 0;
		else if (trig_i) trigger_holdoff <= 1;
		
		if (!trigger_holdoff) holdoff_div_2 <= 0;
		else holdoff_div_2 <= ~holdoff_div_2;
		
		if (!trigger_holdoff) holdoff_counter <= {4{1'b0}};
		else if (holdoff_div_2) holdoff_counter <= holdoff_counter_plus_one;
		
		clear_holdoff <= holdoff_counter_plus_one[4];
	end
	
	assign holdoff_o = trigger_holdoff;

endmodule
