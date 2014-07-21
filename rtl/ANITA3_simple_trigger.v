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

// The 'simple' trigger just looks for triggers in adjacent phi sectors.
// It has an internal holdoff of 128 ns between issued triggers.
module ANITA3_simple_trigger( clk250_i,
										clk250b_i,
										clk33_i,
										L1_i,
										trig_o,
										scal_o,
										phi_mask_i,
										phi_o
										);
   parameter NUM_SURFS = 12;
   parameter NUM_TRIG = 4;
   parameter NUM_HOLD = 4;   
	parameter NUM_PHI = 16;

   input clk250_i;
	input clk250b_i;
	input clk33_i;
   input [NUM_SURFS*NUM_TRIG-1:0] L1_i;
	input [2*NUM_PHI-1:0] phi_mask_i;
   output 			  trig_o;
	output [2*NUM_PHI-1:0] phi_o;
	output [2*NUM_PHI-1:0] scal_o;
	
	wire [NUM_PHI-1:0] V_pol_phi;
	wire [NUM_PHI-1:0] H_pol_phi;

	ANITA3_simple_trigger_map u_map(.clk250_i(clk250_i),
											  .clk250b_i(clk250b_i),
											  .mask_i(phi_mask_i),
											  .L1_i(L1_i),
											  .V_pol_phi_o(V_pol_phi),
											  .H_pol_phi_o(H_pol_phi));
	reg [NUM_PHI-1:0] V_pol_trig = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_trig = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] V_pol_hold = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_hold = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] V_pol_pat = {NUM_PHI{1'b0}};
	reg [NUM_PHI-1:0] H_pol_pat = {NUM_PHI{1'b0}};	

	reg H_rf_trigger = 0;
	reg V_rf_trigger = 0;
	reg rf_trigger = 0;
	wire trigger_holdoff;
	
	generate
		genvar i;
		for (i=0;i<NUM_PHI;i=i+1) begin : RF_TRIG
			srl_oneshot v_scaler(.clk250_i(clk250_i),.trig_i(V_pol_trig[i]),.scal_o(scal_o[i]));
			srl_oneshot h_scaler(.clk250_i(clk250_i),.trig_i(H_pol_trig[i]),.scal_o(scal_o[NUM_PHI+i]));
			always @(posedge clk250_i) begin
				// The i+NUM_PHI-1 makes sure that we're always taking the modulus of a positive number.
				// It works out to (i-1), wrapping around from 0-15.
				V_pol_trig[i] <= (V_pol_phi[i]) && (V_pol_phi[(i+NUM_PHI-1)%NUM_PHI] || V_pol_phi[(i+1)%NUM_PHI]);
				H_pol_trig[i] <= (H_pol_phi[i]) && (H_pol_phi[(i+NUM_PHI-1)%NUM_PHI] || H_pol_phi[(i+1)%NUM_PHI]);
			end
		end
	endgenerate
	
	always @(posedge clk250_i) begin
		H_pol_hold <= H_pol_trig;
		V_pol_hold <= V_pol_trig;
		if (!H_rf_trigger && !trigger_holdoff) H_pol_pat <= H_pol_hold;
		if (!V_rf_trigger && !trigger_holdoff) V_pol_pat <= V_pol_hold;		
		H_rf_trigger <= |H_pol_trig;
		V_rf_trigger <= |V_pol_trig;
		rf_trigger <= (H_rf_trigger | V_rf_trigger) && !trigger_holdoff;
	end
	
	ANITA3_trigger_holdoff u_rf_holdoff(.clk250_i(clk250_i),
													.trig_i(V_rf_trigger | H_rf_trigger),
													.holdoff_o(trigger_holdoff));
	
	assign trig_o = rf_trigger;
	assign phi_o = {H_pol_pat,V_pol_pat};
endmodule
   
   