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
module srl_oneshot_with_ref(
		input clk250_i,
		input pulse_i,
		input trig_i,
		output mon_scal_o,
		output scal_o
    );

	parameter ONESHOT_LENGTH = 16;

	reg [1:0] mon_flag_reg = 0;
	reg mon_flag = 0;
	reg flag = 0;
	reg [15:0] delay_line = {16{1'b0}};
	reg [15:0] mon_delay_line = {16{1'b0}};
	
	always @(posedge clk250_i) begin
		mon_flag_reg <= {mon_flag_reg[0],flag & pulse_i};
		if (mon_flag_reg[0] && !mon_flag_reg[1]) mon_flag <= 1;
		else if (mon_delay_line[ONESHOT_LENGTH-1]) mon_flag <= 0;
		
		mon_delay_line <= {mon_delay_line[14:0],mon_flag_reg[0] && !mon_flag_reg[1]};
		
		if (trig_i) flag <= 1;
		else if (delay_line[ONESHOT_LENGTH-1]) flag <= 0;
		
		delay_line <= {delay_line[14:0],trig_i};
	end
	assign scal_o = flag;
	assign mon_scal_o = mon_flag;
endmodule
