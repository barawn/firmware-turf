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
module soft_or_ext_pipe(input soft_i,
							input ext_i,
							input disable_ext_i,
							input clk250_i,
							input clk33_i,
							output trig_o);
	
	reg soft_or_ext_clk33 = 0;

	(* SHREG_EXTRACT = "NO" *)
	reg [2:0] soft_or_ext_clk250 = 0;
	
	reg trig = 0;
	
	always @(posedge clk33_i) begin
		soft_or_ext_clk33 <= soft_i || (ext_i && !disable_ext_i);
	end
	always @(posedge clk250_i) begin
		soft_or_ext_clk250 <= {soft_or_ext_clk250[1:0],soft_or_ext_clk33};
		trig <= soft_or_ext_clk250[2] && !soft_or_ext_clk250[1];
	end

	assign trig_o = trig;
endmodule
	
							