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
module ANITA3_simple_trigger_map(
		clk250_i,
		clk250b_i,
		L1_i,
		mask_i,
		V_pol_phi_o,
		H_pol_phi_o
    );

	parameter NUM_SURFS = 12;
	parameter NUM_TRIG = 4;
	parameter NUM_PHI = 16;
	input clk250_i;
	input clk250b_i;
	input [NUM_SURFS*NUM_TRIG-1:0] L1_i;
	input [2*NUM_PHI-1:0] mask_i;
	output [NUM_PHI-1:0] V_pol_phi_o;
	output [NUM_PHI-1:0] H_pol_phi_o;
	wire [NUM_PHI-1:0] V_pol_phi_in;
	wire [NUM_PHI-1:0] H_pol_phi_in;
	
	// Remap to SURFs.
	wire [NUM_TRIG-1:0] SURF_L1[NUM_SURFS-1:0];
	generate
		genvar s;
		for (s=0;s<NUM_SURFS;s=s+1) begin : SL
			assign SURF_L1[s] = L1_i[4*s +: 4];
		end
	endgenerate
		
	wire [NUM_PHI-1:0] V_pol_mask = mask_i[0 +: NUM_PHI];
	wire [NUM_PHI-1:0] H_pol_mask = mask_i[NUM_PHI +: NUM_PHI];
	
	(* IOB = "TRUE" *)
	reg [NUM_PHI-1:0] V_pol_phi_reg = {NUM_PHI{1'b0}};
	(* IOB = "TRUE" *)
	reg [NUM_PHI-1:0] H_pol_phi_reg = {NUM_PHI{1'b0}};
	
	reg [NUM_PHI-1:0] V_pol_phi_pipe = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_phi_pipe = {NUM_PHI{1'b0}};

	assign V_pol_phi_in[0] = SURF_L1[2][0];
	assign V_pol_phi_in[4] = SURF_L1[2][1];
	assign H_pol_phi_in[0] = SURF_L1[2][2];
	assign H_pol_phi_in[4] = SURF_L1[2][3];

	// TEMPORARY MOVE!!!!
	// SURF 3 should have phi sectors 2 and 6.
	// SURF 3 should have phi sectors 1 and 5.
	
	// We're temporarily switching phi sectors 2 and 5.
// CORRECT
	assign V_pol_phi_in[2] = SURF_L1[3][0];
	assign V_pol_phi_in[6] = SURF_L1[3][1];
	assign H_pol_phi_in[2] = SURF_L1[3][2];
	assign H_pol_phi_in[6] = SURF_L1[3][3];

	assign V_pol_phi_in[1] = SURF_L1[4][0];
	assign V_pol_phi_in[5] = SURF_L1[4][1];
	assign H_pol_phi_in[1] = SURF_L1[4][2];
	assign H_pol_phi_in[5] = SURF_L1[4][3];

// WRONG
//	assign V_pol_phi_in[5] = SURF_L1[3][0];
//	assign V_pol_phi_in[6] = SURF_L1[3][1];
//	assign H_pol_phi_in[5] = SURF_L1[3][2];
//	assign H_pol_phi_in[6] = SURF_L1[3][3];
//
//	assign V_pol_phi_in[1] = SURF_L1[4][0];
//	assign V_pol_phi_in[2] = SURF_L1[4][1];
//	assign H_pol_phi_in[1] = SURF_L1[4][2];
//	assign H_pol_phi_in[2] = SURF_L1[4][3];

	assign V_pol_phi_in[3] = SURF_L1[5][0];
	assign V_pol_phi_in[7] = SURF_L1[5][1];
	assign H_pol_phi_in[3] = SURF_L1[5][2];
	assign H_pol_phi_in[7] = SURF_L1[5][3];

	assign V_pol_phi_in[15] = SURF_L1[6][0];
	assign V_pol_phi_in[11] = SURF_L1[6][1];
	assign H_pol_phi_in[15] = SURF_L1[6][2];
	assign H_pol_phi_in[11] = SURF_L1[6][3];

	assign V_pol_phi_in[13] = SURF_L1[7][0];
	assign V_pol_phi_in[9] = SURF_L1[7][1];
	assign H_pol_phi_in[13] = SURF_L1[7][2];
	assign H_pol_phi_in[9] = SURF_L1[7][3];

	assign V_pol_phi_in[14] = SURF_L1[8][0];
	assign V_pol_phi_in[10] = SURF_L1[8][1];
	assign H_pol_phi_in[14] = SURF_L1[8][2];
	assign H_pol_phi_in[10] = SURF_L1[8][3];

	assign V_pol_phi_in[12] = SURF_L1[9][0];
	assign V_pol_phi_in[8] = SURF_L1[9][1];
	assign H_pol_phi_in[12] = SURF_L1[9][2];
	assign H_pol_phi_in[8] = SURF_L1[9][3];

	generate
		genvar j;
		for (j=0;j<NUM_PHI;j=j+1) begin : PHI
			always @(posedge clk250_i) begin : IFF
				if (V_pol_mask[j]) V_pol_phi_reg[j] <= 0;
				else V_pol_phi_reg[j] <= V_pol_phi_in[j];
					
				if (H_pol_mask[j]) H_pol_phi_reg[j] <= 0;
				else H_pol_phi_reg[j] <= H_pol_phi_in[j];
				
				V_pol_phi_pipe <= V_pol_phi_reg;
				H_pol_phi_pipe <= H_pol_phi_reg;
			end
		end
	endgenerate

	assign V_pol_phi_o = V_pol_phi_pipe;
	assign H_pol_phi_o = H_pol_phi_pipe;
	
endmodule
