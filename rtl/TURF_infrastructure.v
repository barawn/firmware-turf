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
module TURF_infrastructure(
		L1_P, L1_N, L1,
		HOLD_P, HOLD_N, HOLD,
		CMD_P, CMD_N, CMD,
		SURF_CLK_P, SURF_CLK_N,
		SURF_REF_PULSE_P, SURF_REF_PULSE_N, SURF_REF_PULSE,
		CLK125_P, CLK125_N, CLK125, CLK250, CLK250B,
		CLK33_P, CLK33_N, CLK33,
		dcm_reset_i,
		dcm_status_o
    );

	parameter NUM_SURFS = 12;
	parameter NUM_TRIG = 4;
	parameter NUM_HOLD = 4;
	input [NUM_TRIG*NUM_SURFS-1:0] L1_P;
	input [NUM_TRIG*NUM_SURFS-1:0] L1_N;
	output [NUM_TRIG*NUM_SURFS-1:0] L1;
	output [NUM_HOLD*NUM_SURFS-1:0] HOLD_P;
	output [NUM_HOLD*NUM_SURFS-1:0] HOLD_N;
	input [NUM_HOLD*NUM_SURFS-1:0] HOLD;
	output [NUM_SURFS-1:0] CMD_P;
	output [NUM_SURFS-1:0] CMD_N;
	input [NUM_SURFS-1:0] CMD;
	output [NUM_SURFS-1:0] SURF_CLK_P;
	output [NUM_SURFS-1:0] SURF_CLK_N;
	output [NUM_SURFS-1:0] SURF_REF_PULSE_P;
	output [NUM_SURFS-1:0] SURF_REF_PULSE_N;
	input [NUM_SURFS-1:0] SURF_REF_PULSE;
	input CLK125_P;
	input CLK125_N;
	output CLK125;
	input CLK33_P;
	input CLK33_N;
	output CLK33;
	output CLK250;
	output CLK250B;
	input dcm_reset_i;
	output [2:0] dcm_status_o;
	
	wire [NUM_SURFS-1:0] SURF_CLK_to_OBUFDS;
	wire CLK125_to_BUFG;
	wire CLK125B_to_BUFG;
	wire CLK250_to_BUFG;
	wire CLK250B_to_BUFG;

	wire CLK125B;
	wire CLK33_to_BUFG;	
	wire CLK33_to_DCM;
	IBUFGDS_DIFF_OUT u_ibufg_clk125(.I(CLK125_P),.IB(CLK125_N),.O(CLK125_to_BUFG),.OB(CLK125B_to_BUFG));
	(* LOC = "BUFGMUX2P" *)
	BUFG u_bufg_clk125(.I(CLK125_to_BUFG),.O(CLK125));
	(* LOC = "BUFGMUX3S" *)
	BUFG u_bufg_clk125b(.I(CLK125B_to_BUFG),.O(CLK125B));
	
	BUFG u_bufg_clk250(.I(CLK250_to_BUFG),.O(CLK250));
	(* KEEP = "YES" *)
	BUFG u_bufg_clk250b(.I(CLK250B_to_BUFG),.O(CLK250B));
	
	IBUFGDS u_ibufg_clk33(.I(CLK33_P),.IB(CLK33_N),.O(CLK33_to_DCM));
	BUFG u_bufg_clk33(.I(CLK33_to_BUFG),.O(CLK33));
	
	wire [7:0] dcm_status;
	wire dcm_locked;
	assign dcm_status_o[1:0] = dcm_status[1:0];
	assign dcm_status_o[2] = dcm_locked;

	DCM #(.CLK_FEEDBACK("1X"),.CLKOUT_PHASE_SHIFT("NONE"),.DESKEW_ADJUST("SOURCE_SYNCHRONOUS"),
			.DLL_FREQUENCY_MODE("LOW"),.STARTUP_WAIT("TRUE")) u_deskew(.CLKIN(CLK33_to_DCM),
															 .CLKFB(CLK33),
															 .CLK0(CLK33_to_BUFG),
															 .RST(1'b0));															 
	DCM #(.CLK_FEEDBACK("2X"),.CLKOUT_PHASE_SHIFT("NONE"),
			.DLL_FREQUENCY_MODE("LOW"),.STARTUP_WAIT("TRUE")) u_multip(.CLKIN(CLK125),
															 .CLKFB(CLK250),
															 .RST(dcm_reset),
															 .LOCKED(dcm_locked),
															 .STATUS(dcm_status),
															 .CLK2X(CLK250_to_BUFG),
															 .CLK2X180(CLK250B_to_BUFG));															 

	generate
		genvar i,j,k;
		for (i=0;i<NUM_SURFS;i=i+1) begin : SURF
			for (j=0;j<NUM_TRIG;j=j+1) begin : TRIG
				IBUFDS u_trig(.I(L1_P[NUM_TRIG*i+j]),.IB(L1_N[NUM_TRIG*i+j]),.O(L1[4*i+j]));
			end
			for (k=0;k<NUM_HOLD;k=k+1) begin : HOLD_1
				OBUFDS u_hold(.I(HOLD[NUM_HOLD*i+k]),.O(HOLD_P[NUM_HOLD*i+k]),.OB(HOLD_N[4*i+k]));
			end
			assign CMD_P[i] = CMD[i];
			assign CMD_N[i] = ~CMD[i];
//			OBUFDS u_cmd(.I(CMD[i]),.O(CMD_P[i]),.OB(CMD_N[i]));
			OBUFDS u_ref_pulse(.I(SURF_REF_PULSE[i]),.O(SURF_REF_PULSE_P[i]),.OB(SURF_REF_PULSE_N[i]));
			FDDRRSE u_refclk_ddr(.C0(CLK125),.C1(CLK125B),.D0(1'b1),.D1(1'b0),.R(1'b0),.S(1'b0),.Q(SURF_CLK_to_OBUFDS[i]));
			OBUFDS u_refclk_obufds(.I(SURF_CLK_to_OBUFDS[i]),.O(SURF_CLK_P[i]),.OB(SURF_CLK_N[i]));
		end
	endgenerate
	
endmodule
