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
module ANITA3_scaler(
		clk_i,
		pps_i,
		count_i,
		scaler_o
    );

	parameter WIDTH = 8;
	parameter PRESCALE = 0;
	input clk_i;
	input pps_i;
	input count_i;
	output [WIDTH-1:0] scaler_o;
	
	reg [WIDTH+PRESCALE-1:0] counter = {WIDTH+PRESCALE{1'b0}};
	wire [WIDTH+PRESCALE:0] counter_plus_one = counter + 1;

	reg [WIDTH-1:0] scaler = {WIDTH{1'b0}};
	always @(posedge clk_i) begin
		if (pps_i) counter <= {WIDTH+PRESCALE{1'b0}};
		else if (count_i && !counter_plus_one[WIDTH+PRESCALE]) counter <= counter_plus_one;
	
		if (pps_i) scaler <= counter[PRESCALE +: WIDTH];
	end

	assign scaler_o = scaler;

endmodule
