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
`define NUM_SURFS 12
module TOP_v37(
		// TURFIO interface
		input nCSTURF,
		input TURF_WnR,
		inout [7:0] TURF_DIO,
		// Clocks from TURFIO
		input CLK125_P,
		input CLK125_N,
		input CLK33_P,
		input CLK33_N,
		// PPS from TURFIO (D10/D12)
		input PPS,
		input PPS_BURST,
		// External triggers to/from TURFIO (D14/D13)
		input TRIG_IN,
		output TRIG_OUT,
		// Trigger inputs from SURFs.
		input [`NUM_SURFS*4-1:0] L1_P,
		input [`NUM_SURFS*4-1:0] L1_N,
		// HOLD outputs to SURFs.
		output [`NUM_SURFS*4-1:0] HOLD_P,
		output [`NUM_SURFS*4-1:0] HOLD_N,
		// Command outputs to SURFs ('EVID' in old firmware or TS_S1)
		output [`NUM_SURFS-1:0] CMD_P,
		output [`NUM_SURFS-1:0] CMD_N,
		// Clock outputs to SURFs. (TSTRB in old firmware)
		output [`NUM_SURFS-1:0] SURF_CLK_P,
		output [`NUM_SURFS-1:0] SURF_CLK_N,
		// Reference pulse outputs to SURFs. (TS_S0_P/N in old firmware)
		output [`NUM_SURFS-1:0] SURF_REF_PULSE_P,
		output [`NUM_SURFS-1:0] SURF_REF_PULSE_N
		// Unused returns from SURFs (no diff-ins - BUSY_P/N in old firmware)
		// input [`NUM_SURFS*2-1:0] SURF_IN		
    );

	parameter DEBUG = "YES";
	parameter [3:0] VER_MONTH = 7;
	parameter [7:0] VER_DAY = 22;
	parameter [3:0] VER_MAJOR = 3;
	parameter [3:0] VER_MINOR = 8;
	parameter [3:0] VER_REV = 0;
	parameter [3:0] VER_BOARDREV = 0;
	parameter [31:0] VERSION = {VER_BOARDREV,VER_MONTH,VER_DAY,VER_MAJOR,VER_MINOR,VER_REV};

	// Infrastructure.
	wire [`NUM_SURFS*4-1:0] L1;
	wire [`NUM_SURFS*4-1:0] HOLD;
	wire [`NUM_SURFS-1:0] CMD;
	wire [`NUM_SURFS-1:0] SURF_REF_PULSE;
	wire CLK250;
	wire CLK250B;
	wire CLK125;
	wire CLK33;
	TURF_infrastructure #(.NUM_SURFS(`NUM_SURFS)) u_turf_if(.L1_P(L1_P),.L1_N(L1_N),.L1(L1),
																	.HOLD_P(HOLD_P),.HOLD_N(HOLD_N),.HOLD(HOLD),
																	.CMD_P(CMD_P),.CMD_N(CMD_N),.CMD(CMD),
																	.SURF_CLK_P(SURF_CLK_P),.SURF_CLK_N(SURF_CLK_N),
																	.SURF_REF_PULSE_P(SURF_REF_PULSE_P),.SURF_REF_PULSE_N(SURF_REF_PULSE_N),.SURF_REF_PULSE(SURF_REF_PULSE),
																	.CLK125_P(CLK125_P),.CLK125_N(CLK125_N),.CLK125(CLK125),
																	.CLK250(CLK250),.CLK250B(CLK250B),
																	.CLK33_P(CLK33_P),.CLK33_N(CLK33_N),.CLK33(CLK33));
	wire pps_clk250;
	wire pps_clk33;
	wire pps2_trig;
	ANITA3_pps_register u_pps_reg(.clk250_i(CLK250),
											.clk33_i(CLK33),
											.pps_i(PPS),
											.pps_o(pps_clk250),
											.pps_clk33_o(pps_clk33));
											
	// TURF register interface.
	// Scalar data and address.
	wire [31:0] scal_dat;
	wire [5:0] scal_addr;
	// Event data and address.
	wire [31:0] event_dat;
	wire [5:0] event_addr;
	// Phi masking
	wire [31:0] phi_mask;
	// Event ID epoch and overall reset.
	wire [11:0] epoch;
	wire evid_reset;
	// Master clear.
	wire clr_all;
	// Clear event, master disable.
	wire clr_evt;
	wire disable_evt;
	// Trigger enable/disables.
	wire en_pps1_trig;
	wire en_pps2_trig;
	wire dis_ext_trig;
	wire soft_trig;
	// Next ID.
	wire [31:0] next_id;
	// Buffer status.
	wire [31:0] buf_status;
	wire [34:0] register_debug;
	wire [34:0] trigger_debug;
	wire [31:0] pps_trig_time;
	
	wire soft_or_ext = (TRIG_IN && !dis_ext_trig) || soft_trig;
	
	wire event_ready;
	
	TURF_REGISTER_INTERFACE_v2 #(.VERSION(VERSION)) u_turf_registers(.clk_i(CLK33),
															  .scal_dat_i(scal_dat),
															  .scal_addr_o(scal_addr),
															  .event_dat_i(event_dat),
															  .event_addr_o(event_addr),
															  .phi_mask_o(phi_mask),
															  .epoch_o(epoch),
															  .evid_reset_o(evid_reset),
															  .clr_all_o(clr_all),
															  .clr_evt_o(clr_evt),
															  .disable_o(disable_evt),
															  .en_pps1_trig_o(en_pps1_trig),
															  .en_pps2_trig_o(en_pps2_trig),
															  .dis_ext_trig_o(dis_ext_trig),
															  .soft_trig_o(soft_trig),
															  .next_id_i(next_id),
															  .buf_status_i(buf_status),
															  .pps_time_o(pps_trig_time),
															  .nCSTURF(nCSTURF),
															  .TURF_WnR(TURF_WnR),
															  .TURF_DIO(TURF_DIO),
															  .debug_o(register_debug));

	ANITA3_pps_trigger u_pps_trig(.clk33_i(CLK33),
											.pps_i(PPS_BURST),
											.en_i(en_pps2_trig),
											.trig_o(pps2_trig));

	TRIGGER_INTERFACE u_trigger_interface(.clk33_i(CLK33),
													  .clk125_i(CLK125),
													  .clk250_i(CLK250),
													  .clk250b_i(CLK250B),
													  .L1_i(L1),
													  .HOLD_o(HOLD),
													  .CMD_o(CMD),
													  
													  .scal_addr_i(scal_addr),
													  .scal_dat_o(scal_dat),
													  
													  .event_addr_i(event_addr),
													  .event_dat_o(event_dat),
													  
													  .pps_i(pps_clk250),
													  .pps_clk33_i(pps_clk33),
													  
													  .phi_mask_i(phi_mask),
													  // FIX THIS.
													  // This should be soft OR ext trig.
													  .soft_trig_i(soft_or_ext),
													  // FIX THIS.
													  // This should be registered or something.
													  .pps1_time_i(pps_trig_time),
													  .pps1_en_i(en_pps1_trig),
													  .pps2_trig_i(pps2_trig),
													  .clr_all_i(clr_all),
													  .clr_evt_i(clr_evt),
													  .epoch_i(epoch),
													  .evid_reset_i(evid_reset),
													  .next_id_o(next_id),
													  .trig_out_o(TRIG_OUT),
													  .status_o(buf_status),
													  .debug_o(trigger_debug));
													  
  // Fan out.
  assign SURF_REF_PULSE = {`NUM_SURFS{TRIG_IN}};

  wire [35:0] ila_control;
	generate
		if (DEBUG == "YES") begin : CS_CORES
		  (* box_type = "black_box" *)
		  chipscope_icon u_icon(.CONTROL0(ila_control));
		  (* box_type = "black_box" *)
		  turf_ila u_ila(.CONTROL(ila_control),.CLK(CLK33),.TRIG0({trigger_debug[0],HOLD[3:0],register_debug[13:0]}));
		end
	endgenerate
	
endmodule
