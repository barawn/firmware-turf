`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author: Luca Macchiarulo, University of Hawaii (lucam@hawaii.edu)
// Author:
////////////////////////////////////////////////////////////////////////////////

// The 'simple' trigger just looks for triggers in adjacent phi sectors.
// It has an internal holdoff of 128 ns between issued triggers.
module ANITA4_simple_trigger( clk250_i,
										clk250b_i,
										clk33_i,
										L2_i,
                              L2B_i,
										trig_o,
                              rf_scal_o,
                              gated_rf_scal_o,
										scal_o,
										scal_L2_o,
										disable_i,
										refpulse_i,
										mon_scal_o,
										ant_mask_i,
										phi_mask_i,
										phi_o,
										count_o
										);
   parameter NUM_SURFS = 12;
   parameter NUM_TRIG = 4;
   parameter NUM_HOLD = 4;   
	parameter NUM_PHI = 16;

   input clk250_i;
	input clk250b_i;
	input clk33_i;
   input [NUM_SURFS*NUM_TRIG-1:0] L2_i;
   input [NUM_SURFS*NUM_TRIG-1:0] L2B_i;
	input [2*NUM_PHI-1:0] ant_mask_i;
	input [2*NUM_PHI-1:0] phi_mask_i;
   output 			  trig_o;
	output [2*NUM_PHI-1:0] phi_o;
	output [2*NUM_PHI-1:0] scal_o;
	output [2*NUM_PHI-1:0] scal_L2_o;
   output rf_scal_o;
   output gated_rf_scal_o;
	
	
	
	input refpulse_i;
	output [2*NUM_PHI-1:0] mon_scal_o;
	output [7:0] count_o;
	input disable_i;
	
	wire [NUM_PHI-1:0] V_pol_phi;
	wire [NUM_PHI-1:0] H_pol_phi;
   wire [NUM_PHI-1:0] V_pol_phi_scal;
   wire [NUM_PHI-1:0] H_pol_phi_scal;
	ANITA4_simple_trigger_map u_map(.clk250_i(clk250_i),
											  .clk250b_i(clk250b_i),
											  .mask_i(ant_mask_i),
											  .L2_i(L2_i),
                                   .L2B_i(L2B_i),
											  .V_pol_phi_o(V_pol_phi),
											  .H_pol_phi_o(H_pol_phi),
                                   .V_pol_phi_sc_o(V_pol_phi_scal),
                                   .H_pol_phi_sc_o(H_pol_phi_scal));
	reg [NUM_PHI-1:0] V_pol_trig = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_trig = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] V_pol_scal_trig = {NUM_PHI{1'b0}};
   reg [NUM_PHI-1:0] H_pol_scal_trig = {NUM_PHI{1'b0}};
   
	reg [NUM_PHI-1:0] V_pol_phi_del = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_phi_del = {NUM_PHI{1'b0}};

	
	reg [NUM_PHI-1:0] V_pol_hold = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_hold = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] V_pol_pat = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_pat = {NUM_PHI{1'b0}};	

	reg H_rf_trigger = 0;
	reg V_rf_trigger = 0;
	reg rf_trigger = 0;
	reg [1:0] raw_rf_trigger = {2{1'b0}};
	wire trigger_holdoff;

	reg [7:0] raw_rf_count = {8{1'b0}};
	
	reg rf_count_flag = 0;
	
	reg [7:0] rf_count = {8{1'b0}};	
	reg trig_disable = 0;
	
   reg trigger_flagged = 0;
   wire trigger_flagged_clk33;
   wire trigger_acked;
   
   reg gated_flagged = 0;
   wire gated_acked;
   
	generate
		genvar i;
		for (i=0;i<NUM_PHI;i=i+1) begin : RF_TRIG
			srl_oneshot l2v_scaler(.clk250_i(clk250_i),.trig_i(V_pol_phi_scal[i]), 
													.scal_o(scal_L2_o[i]));
			srl_oneshot l2h_scaler(.clk250_i(clk250_i),.trig_i(H_pol_phi_scal[i]), 
													.scal_o(scal_L2_o[NUM_PHI+i]));

			srl_oneshot_with_ref v_scaler(.clk250_i(clk250_i),.trig_i(V_pol_scal_trig[i]),.pulse_i(refpulse_i), 
													.scal_o(scal_o[i]), .mon_scal_o(mon_scal_o[i]));
			srl_oneshot_with_ref h_scaler(.clk250_i(clk250_i),.trig_i(H_pol_scal_trig[i]),.pulse_i(refpulse_i), 
													.scal_o(scal_o[NUM_PHI+i]), .mon_scal_o(mon_scal_o[NUM_PHI+i]));


			always @(posedge clk250_i) begin
				// The i+NUM_PHI-1 makes sure that we're always taking the modulus of a positive number.
				// It works out to (i-1), wrapping around from 0-15.
//				V_pol_trig[i] <= ((V_pol_phi[i]) && (V_pol_phi[(i+NUM_PHI-1)%NUM_PHI] || V_pol_phi[(i+1)%NUM_PHI])) && !phi_mask_i[i];
//				H_pol_trig[i] <= ((H_pol_phi[i]) && (H_pol_phi[(i+NUM_PHI-1)%NUM_PHI] || H_pol_phi[(i+1)%NUM_PHI])) && !phi_mask_i[NUM_PHI+i];
				V_pol_trig[i] <= ((V_pol_phi[i]) && (V_pol_phi[(i+1)%NUM_PHI])) && !phi_mask_i[i]; //LM: only a phi sector anded with its adjacent
				H_pol_trig[i] <= ((H_pol_phi[i]) && (H_pol_phi[(i+1)%NUM_PHI])) && !phi_mask_i[NUM_PHI+i];	

            V_pol_scal_trig[i] <= ((V_pol_phi_scal[i]) && (V_pol_phi_scal[(i+1)%NUM_PHI]));
            H_pol_scal_trig[i] <= ((H_pol_phi_scal[i]) && (H_pol_phi_scal[(i+1)%NUM_PHI]));
				end
		end
	endgenerate
	
	always @(posedge clk250_i) begin
		trig_disable <= disable_i;
		
		V_pol_phi_del <= V_pol_phi;
		H_pol_phi_del <= H_pol_phi;
		H_pol_hold <= H_pol_phi_del;
		V_pol_hold <= V_pol_phi_del;
		if ((H_rf_trigger || V_rf_trigger) && !trigger_holdoff) H_pol_pat <= H_pol_hold;
		if ((H_rf_trigger || V_rf_trigger) && !trigger_holdoff) V_pol_pat <= V_pol_hold;		
		H_rf_trigger <= |H_pol_trig;
		V_rf_trigger <= |V_pol_trig;
		rf_trigger <= (H_rf_trigger | V_rf_trigger) && !trigger_holdoff && !trig_disable;
//		rf_trigger <= ((|H_pol_trig) | (|V_rf_trigger)) && !trigger_holdoff && !trig_disable; //LM see if it still respects timing - saves 1 cycle
		raw_rf_trigger <= {raw_rf_trigger[0],(H_rf_trigger | V_rf_trigger)};
	
		rf_count_flag <= (raw_rf_trigger[0] && !raw_rf_trigger[1]);
		
		if (rf_count_flag) raw_rf_count <= raw_rf_count + 1;
		if (rf_count_flag && trigger_holdoff) rf_count <= raw_rf_count;
      
      if (trigger_acked) trigger_flagged <= 0;
      else if (rf_count_flag) trigger_flagged <= 1;
      
      if (gated_acked) gated_flagged <= 0;
      else if (rf_count_flag && refpulse_i) gated_flagged <= 1;
	end
	flag_sync u_gated_scaler(.in_clkA(rf_count_flag && refpulse_i && !gated_flagged),.clkA(clk250_i),
                            .out_clkB(gated_rf_scal_o),.clkB(clk33_i));
   flag_sync u_gated_scaler_ack(.in_clkA(gated_rf_scal_o),.clkA(clk33_i),
                                .out_clkB(gated_acked),.clkB(clk250_i));
   flag_sync u_trigger_scaler(.in_clkA(rf_count_flag && !trigger_flagged),.clkA(clk250_i),
                              .out_clkB(rf_scal_o),.clkB(clk33_i));
   flag_sync u_trigger_scaler_ack(.in_clkA(rf_scal_o),.clkA(clk33_i),
                                  .out_clkB(trigger_acked),.clkB(clk250_i));
                                  
	ANITA3_trigger_holdoff u_rf_holdoff(.clk250_i(clk250_i),
													.trig_i(V_rf_trigger | H_rf_trigger),
													.holdoff_o(trigger_holdoff));
	
	assign trig_o = rf_trigger;
	assign phi_o = {H_pol_pat,V_pol_pat};
	assign count_o = rf_count;
endmodule
   
   
