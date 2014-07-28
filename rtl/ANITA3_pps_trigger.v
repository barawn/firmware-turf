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
module ANITA3_pps_trigger(
		input clk33_i,
		input pps_i,
		input disable_i,
		input en_i,
		output trig_o
    );

	reg holdoff = 0;
	reg [6:0] holdoff_counter = {7{1'b0}};
	wire [7:0] holdoff_counter_plus_one = holdoff_counter + 1;
	reg [1:0] pps_reg_i = {2{1'b0}};
	reg trigger = 0;
	always @(posedge clk33_i) begin
		pps_reg_i <= {pps_reg_i[0], pps_i};
		trigger <= pps_reg_i[0] && !pps_reg_i[1] && !holdoff && en_i;
		if (holdoff_counter_plus_one[7]) holdoff <= 0;
		else if (trigger && !disable_i) holdoff <= 1;
		if (holdoff) holdoff_counter <= holdoff_counter_plus_one;
	end
	
	assign trig_o = trigger;
endmodule
