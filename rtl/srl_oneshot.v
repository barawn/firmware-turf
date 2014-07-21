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
module srl_oneshot(
		input clk250_i,
		input trig_i,
		output scal_o
    );

	parameter ONESHOT_LENGTH = 16;

	reg flag = 0;
	reg [15:0] delay_line = {16{1'b0}};
	always @(posedge clk250_i) begin
		if (trig_i) flag <= 1;
		else if (delay_line[ONESHOT_LENGTH-1]) flag <= 0;
		
		delay_line <= {delay_line[14:0],trig_i};
	end
	assign scal_o = flag;
endmodule
