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
module ANITA3_buffer_manager_tb;

	// Inputs
	reg clk250_i;
	reg [3:0] trig_i;
	reg clear_i;
	reg [1:0] clear_buffer_i;

	// Outputs
	wire [1:0] trig_buffer_o;
	wire digitize_o;
	wire [3:0] HOLD_o;
	wire dead_o;

	// Instantiate the Unit Under Test (UUT)
	ANITA3_buffer_manager uut (
		.clk250_i(clk250_i), 
		.trig_i(trig_i), 
		.trig_buffer_o(trig_buffer_o), 
		.clear_i(clear_i), 
		.clear_buffer_i(clear_buffer_i), 
		.digitize_o(digitize_o), 
		.HOLD_o(HOLD_o), 
		.dead_o(dead_o)
	);

	always #2 clk250_i = ~clk250_i;
	
	initial begin
		// Initialize Inputs
		clk250_i = 0;
		trig_i = 0;
		clear_i = 0;
		clear_buffer_i = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		@(posedge clk250_i);
		trig_i <= 1;
		@(posedge clk250_i);
		trig_i <= 0;
		#150;
		@(posedge clk250_i);
		trig_i <= 1;
		@(posedge clk250_i);
		trig_i <= 0;
		#500;
		@(posedge clk250_i);
		trig_i <= 1;
		@(posedge clk250_i);
		trig_i <= 0;		
	end
      
endmodule

