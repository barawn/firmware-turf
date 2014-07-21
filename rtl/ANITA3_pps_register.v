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
module ANITA3_pps_register(
		input clk250_i,
		input clk33_i,
		input pps_i,
		output pps_o,
		output pps_clk33_o
    );

	reg pps_holdoff_250 = 0;
	reg pps_holdoff_33 = 0;
	reg pps_holdoff_clear = 0;
	reg [15:0] pps_holdoff_counter = {16{1'b0}};
	reg [2:0] pps_reg_250 = {3{1'b0}};
	reg pps_flag_250 = 0;
	reg [2:0] pps_reg_33 = {3{1'b0}};
	reg pps_flag_33 = 0;
	always @(posedge clk250_i) begin
		pps_reg_250 <= {pps_reg_250[1:0],pps_i};
		pps_flag_250 <= pps_reg_250[1] && !pps_reg_250[2] && !pps_holdoff_250;
		if (pps_holdoff_clear) pps_holdoff_250 <= 0;
		else if (pps_flag_250) pps_holdoff_250 <= 1;
	end
	always @(posedge clk33_i) begin
		pps_reg_33 <= {pps_reg_33[1:0],pps_i};
		pps_flag_33 <= pps_reg_33[1] && !pps_reg_33[2] && !pps_holdoff_33;
		if (pps_holdoff_clear) pps_holdoff_33 <= 0;
		else if (pps_flag_33) pps_holdoff_33 <= 1;
		
		if (pps_holdoff_counter[15]) pps_holdoff_counter <= {16{1'b0}};
		else if (pps_holdoff_33) pps_holdoff_counter <= pps_holdoff_counter + 1;
		
		pps_holdoff_clear <= pps_holdoff_counter[15];
	end
	assign pps_o = pps_flag_250;
	assign pps_clk33_o = pps_flag_33;
	
endmodule
