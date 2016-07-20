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
      L1B_i,
		mask_i,
		V_pol_phi_o,
      V_pol_phi_sc_o,
		H_pol_phi_o,
      H_pol_phi_sc_o
    );

	parameter NUM_SURFS = 12;
	parameter NUM_TRIG = 4;
	parameter NUM_PHI = 16;
	input clk250_i;
	input clk250b_i;
	input [NUM_SURFS*NUM_TRIG-1:0] L1_i;
   input [NUM_SURFS*NUM_TRIG-1:0] L1B_i;
	input [2*NUM_PHI-1:0] mask_i;
	
   output [NUM_PHI-1:0] V_pol_phi_o;
   output [NUM_PHI-1:0] V_pol_phi_sc_o;
   
	output [NUM_PHI-1:0] H_pol_phi_o;
   output [NUM_PHI-1:0] H_pol_phi_sc_o;
   
	wire [NUM_PHI-1:0] V_pol_phi_in;
   wire [NUM_PHI-1:0] V_pol_phi_sc;
	wire [NUM_PHI-1:0] H_pol_phi_in;
   wire [NUM_PHI-1:0] H_pol_phi_sc;
	
	// Remap to SURFs.
	wire [NUM_TRIG-1:0] SURF_L1[NUM_SURFS-1:0];
   wire [NUM_TRIG-1:0] SURF_L1B[NUM_SURFS-1:0];
	generate
		genvar s;
		for (s=0;s<NUM_SURFS;s=s+1) begin : SL
			assign SURF_L1[s] = L1_i[4*s +: 4];
         assign SURF_L1B[s] = L1B_i[4*s +: 4];
		end
	endgenerate
		      
	wire [NUM_PHI-1:0] V_pol_mask = mask_i[0 +: NUM_PHI];
	wire [NUM_PHI-1:0] H_pol_mask = mask_i[NUM_PHI +: NUM_PHI];
	
	(* IOB = "TRUE" *)
	reg [NUM_PHI-1:0] V_pol_phi_reg = {NUM_PHI{1'b0}};
	(* IOB = "TRUE" *)
	reg [NUM_PHI-1:0] H_pol_phi_reg = {NUM_PHI{1'b0}};

   (* IOB = "TRUE" *)
   reg [NUM_PHI-1:0] V_pol_phi_scal_reg = {NUM_PHI{1'b0}};
   (* IOB = "TRUE" *)
   reg [NUM_PHI-1:0] H_pol_phi_scal_reg = {NUM_PHI{1'b0}};
	
	reg [NUM_PHI-1:0] V_pol_phi_pipe = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_phi_pipe = {NUM_PHI{1'b0}};

   function [4:0] phi_map;
      input integer surf;
      input integer num;
      begin
         surf = surf + 1;         
         // This default will throw an error if you use this function wrong.
         phi_map = 17;
         if (surf == 3) begin
            if (num == 0) phi_map = 1; //1;
            if (num == 1) phi_map = 2; //5;
         end else
         if (surf == 4) begin
            if (num == 0) phi_map = 9; //3;
            if (num == 1) phi_map = 10;//7;
         end else
         if (surf == 5) begin
            if (num == 0) phi_map = 3; //2;
            if (num == 1) phi_map = 4; //6;
         end else
         if (surf == 6) begin
            if (num == 0) phi_map = 11;//4;
            if (num == 1) phi_map = 12;//8;
         end else
         if (surf == 7) begin
            if (num == 0) phi_map = 5; //16;
            if (num == 1) phi_map = 6; //12;
         end else
         if (surf == 8) begin
            if (num == 0) phi_map = 13;//14;
            if (num == 1) phi_map = 14;//10;
         end else 
         if (surf == 9) begin
            if (num == 0) phi_map = 7; //15;
            if (num == 1) phi_map = 8; //11;
         end else
         if (surf == 10) begin
            if (num == 0) phi_map = 15;//13;
            if (num == 1) phi_map = 16;//9;
         end
         phi_map = phi_map - 1;
      end
   endfunction
   
   localparam TRIGGER_SURF_START = 2;
   localparam TRIGGER_SURF_END = 9;

   generate
      genvar i;
		genvar j;
      for (i=TRIGGER_SURF_START;i<=TRIGGER_SURF_END;i=i+1) begin : MAP
         assign V_pol_phi_in[phi_map(i,0)] = SURF_L1[i][0];
         assign V_pol_phi_sc[phi_map(i,0)] = SURF_L1B[i][0];
         assign V_pol_phi_in[phi_map(i,1)] = SURF_L1[i][2];
         assign V_pol_phi_sc[phi_map(i,1)] = SURF_L1B[i][2];
         // These --technically-- do entirely nothing right now.
         assign H_pol_phi_in[phi_map(i,0)] = SURF_L1[i][1];
         assign H_pol_phi_sc[phi_map(i,0)] = SURF_L1B[i][1];
         assign H_pol_phi_in[phi_map(i,1)] = SURF_L1[i][3];
         assign H_pol_phi_sc[phi_map(i,1)] = SURF_L1B[i][3];
      end
		for (j=0;j<NUM_PHI;j=j+1) begin : PHI
			always @(posedge clk250_i) begin : IFF
            V_pol_phi_scal_reg[j] <= ~V_pol_phi_sc[j];
            H_pol_phi_scal_reg[j] <= ~H_pol_phi_sc[j];
            
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
   assign V_pol_phi_sc_o = V_pol_phi_scal_reg;
   
	assign H_pol_phi_o = H_pol_phi_pipe;
	assign H_pol_phi_sc_o = H_pol_phi_scal_reg;
endmodule
