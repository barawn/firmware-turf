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
module ANITA3_timebase(
		input clk250_i,
		input clk33_i,
		input rst_i,
		input pps_i,
		input [31:0] trig_time_i,
		input trig_en_i,
		input disable_i,
		output trig_o,
		
		input event_i,
		output [15:0] current_pps_o,
		output [31:0] current_clock_o,
		output [15:0] event_pps_o,
		output [31:0] event_clock_o
    );

	// The clock time setting here is sleazed, heavily.
	// The units are 4 ns intervals. This is 28 bits.
	// The top 24 bits you set are really the top 24
	// bits of the time that you want *minus 1*, or in
	// other words you set the time you want, minus 16
	// clocks.
	//
	// Bit 31 is special: this gets set if you want
	// 0 for the top 24 bits (e.g. between 0-15 clocks).
	//
	// So to set 10,005 clocks after PPS (40,020 ns),
	// you would set 0x2705 (=9989).
	//
	// Of course note that all clocks near the PPS are
	// uncertain and may not ever occur.

	// Add this to UCF:
	// TIMESPEC "TS_COUNTER_PATH" = FROM FFS("this_module/counter_2*") TO FFS("this_module/counter_2*") TS_CLK*16;
	// TIMESPEC "TS_PPS_PATH" = FROM FFS("this_module/pps_count*") TO FFS("this_module/pps_count*") TIG;
	reg [15:0] pps_count = {16{1'b0}};
	
   reg [3:0]                             counter_1 = {4{1'b0}};
   wire [4:0]                            counter_1_plus_one = counter_1 + 1;
   reg [3:0]                             counter_1_store = {4{1'b0}};
   reg                                   counter_1_flag = 0;
   reg [27:0]                            counter_2 = {28{1'b0}};
   reg                                   pps_store = 0;
	reg 											  pps_stretch = 0;
	reg digitize_flag = 0;
	reg [1:0] digitize_reg = {2{1'b0}};
	reg [1:0] pps_sync = {2{1'b0}};
	reg pps_flag = 0;

	reg [15:0] event_pps = {16{1'b0}};
	reg [31:0] event_clock = {32{1'b0}};
	reg [31:0] current_clock = {32{1'b0}};
	reg [31:0] current_clock_CLK33 = {32{1'b0}};
	reg [15:0] current_pps_CLK33 = {16{1'b0}};

	wire trig_match_counter_2 = (counter_2 == trig_time_i[31:4]);
	reg trig_match_1 = 0;
	reg trig_match_2 = 0;
	reg trig_match_3 = 0;
	reg [3:0] trig_counter_1 = 0;
	reg trig = 0;
   reg trig_en = 0;
	
	always @(posedge clk33_i) begin
		pps_sync <= {pps_sync[0],pps_stretch};
		pps_flag <= (pps_sync[0] && !pps_sync[1]);	
		if (rst_i) 	current_pps_CLK33 <= {16{1'b0}};
		else if (pps_flag) current_pps_CLK33 <= pps_count;
		
		if (pps_flag) current_clock_CLK33 <= current_clock;
	end
	
   always @(posedge clk250_i) begin
		trig_en <= trig_en_i && !disable_i;
		
		if (counter_1_flag) trig_match_1 <= trig_match_counter_2 && !trig_time_i[31];
		if (pps_i) trig_match_2 <= trig_time_i[31];
		trig_counter_1 <= trig_time_i[3:0];

		trig_match_3 <= (trig_counter_1 == counter_1);
		
		trig <= (trig_match_1 || trig_match_2) && trig_match_3 && trig_en;

		digitize_reg <= {digitize_reg[0],event_i};
		digitize_flag <= (digitize_reg[0] && !digitize_reg[1]);
	
		if (digitize_flag) event_clock <= {counter_2, counter_1_store};
		if (digitize_flag) event_pps <= pps_count;
	
		if (pps_i) pps_stretch <= 1;
		else if (counter_1_flag) pps_stretch <= 0;

		if (pps_i) current_clock <= {counter_2, counter_1_store};

		if (rst_i) pps_count <= {16{1'b0}};
		else if (pps_i) pps_count <= pps_count + 1;
		
      pps_store <= pps_i;

      if (pps_i) counter_1 <= {4{1'b0}};
      else counter_1 <= counter_1_plus_one;

      counter_1_store <= counter_1;
      counter_1_flag <= counter_1_plus_one[4];

      if (pps_store) counter_2 <= {28{1'b0}};
      else if (counter_1_flag) counter_2 <= counter_2 + 1;
   end
	
	assign current_pps_o = current_pps_CLK33;
	assign current_clock_o = current_clock_CLK33;
	assign event_pps_o = event_pps;
	assign event_clock_o = event_clock;
	assign trig_o = trig;
endmodule
