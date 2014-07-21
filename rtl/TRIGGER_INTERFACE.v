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
module TRIGGER_INTERFACE( clk33_i,
			  clk125_i,
			  clk250_i,
			  clk250b_i,
			  L1_i,
			  HOLD_o,
			  CMD_o,

			  scal_addr_i,
			  scal_dat_o,

			  event_addr_i,
			  event_dat_o,

			  pps_i,			  
			  pps_clk33_i,
			  
			  phi_mask_i,
			  
			  soft_trig_i,
			  pps1_en_i,
			  pps1_time_i,
			  pps2_trig_i,

			  clr_all_i,
			  clr_evt_i,

			  epoch_i,
			  evid_reset_i,
			  next_id_o,
			  
			  trig_out_o
			  );
   parameter NUM_TRIG = 4;
   parameter NUM_HOLD = 4;
   parameter NUM_SURFS = 12;
	parameter NUM_PHI = 16;
	
   input clk33_i;
   input clk125_i;
	input clk250_i;
	input clk250b_i;
   input [NUM_SURFS*NUM_TRIG-1:0] L1_i;
   output [NUM_SURFS*NUM_HOLD-1:0] HOLD_o;
   output [NUM_SURFS-1:0] 	   CMD_o;

   input [5:0] 			   scal_addr_i;
   output [31:0] 		   scal_dat_o;

   input [5:0] 			   event_addr_i;
   output [31:0] 		   event_dat_o;
   
   input 			   pps_i;
	input 				pps_clk33_i;

	input [NUM_PHI*2-1:0] phi_mask_i;

   input 			   soft_trig_i;
   input 			   pps1_en_i;
	input [31:0] 		pps1_time_i;
   input 			   pps2_trig_i;
   
   input 			   clr_all_i;
   input 			   clr_evt_i;
   input [11:0] 		   epoch_i;
   input 			   evid_reset_i;
   output [31:0] 		   next_id_o;

   output 			   trig_out_o;

	wire rf_trigger;

	wire digitize;
   wire [1:0] 			   digitize_buffer;
	wire [3:0]				digitize_source;
   wire [1:0] 			   trig_buffer;
   wire [1:0] 			   clear_buffer;
   wire trigger_dead;
	wire [NUM_PHI*2-1:0] phi_pattern;
	wire [2*NUM_PHI-1:0] phi_scaler;	

	wire [3:0] buffer_status;

	wire [15:0] current_pps_time;
	wire [31:0] current_clock_time;

	wire [15:0] event_pps_time;
	wire [31:0] event_clock_time;
	
	wire [3:0] trigger;
	
	wire pps1_trig;

	wire clr_buffer_250;

	assign trigger[0] = rf_trigger;
	assign trigger[1] = pps1_trig;
	assign trigger[2] = pps2_trig_i;
	assign trigger[3] = soft_trig_i;

   ANITA3_simple_trigger u_trigger(.clk33_i(clk33_i),
											  .clk250_i(clk250_i),
											  .clk250b_i(clk250b_i),
											  .phi_mask_i(phi_mask_i),
											  .scal_o(phi_scaler),
											  .L1_i(L1_i),
											  .trig_o(rf_trigger),
											  .phi_o(phi_pattern));
	wire [NUM_HOLD-1:0] global_hold;
   ANITA3_buffer_manager u_buffer_manager(.clk250_i(clk250_i),
														.trig_i(trigger),
														.trig_buffer_o(trig_buffer),
														.clear_i(clr_evt_i),
														.clear_buffer_i(clear_buffer),
														.digitize_o(digitize),
														.digitize_buffer_o(digitize_buffer),
														.digitize_source_o(digitize_source),
														.buffer_status_o(buffer_status),
														.HOLD_o(global_hold),
														.dead_o(trigger_dead));
	assign HOLD_o = {NUM_SURFS{global_hold}};
	ANITA3_timebase u_timebase(.clk250_i(clk250_i),
										.clk33_i(clk33_i),
										.rst_i(clr_all_i),
										.pps_i(pps_i),
										.trig_en_i(pps1_en_i),
										.trig_time_i(pps1_time_i),
										.trig_o(pps1_trig),
										.event_i(digitize),
										.current_pps_o(current_pps_time),
										.current_clock_o(current_clock_time),
										.event_pps_o(event_pps_time),
										.event_clock_o(event_clock_time));

	// The event generator needs:
	// A 'digitize' command
	// Which buffer to digitize
	// Which trigger caused it.
	// Trigger pattern.
	// This is 2 + 4 + 32 = 38 bits.
	// We have something like 16.5 clocks to do it, though.
	// Let's say we have 8 clocks, and 18 bits per.
	// Top bit indicates start of event.
	// Next bit indicates end of event.
	// First 16-bits: Buffer + Trigger + Buffer Status
	// Next 16-bits: V Pattern
	// Next 16-bits: H Pattern
	// Next 16-bits: PPS Time
	// Next 16-bits: Clock count low
	// Next 16-bits: Clock count high
	// This is 6 clocks. Should be plenty.
	wire [7:0] event_write_addr;
	wire [15:0] event_write_dat;
	wire event_write;
	ANITA3_event_generator u_event_generator(.clk33_i(clk33_i),
														  .clk125_i(clk125_i),
														  .rst_i(clr_all_i),
														  // Command to begin event generation, and all details.
														  .digitize_i(digitize),
														  .digitize_buffer_i(digitize_buffer),
														  .digitize_source_i(digitize_source),
														  .buffer_status_i(buffer_status),
														  .pattern_i(phi_pattern),
														  .pps_time_i(event_pps_time),
														  .clock_time_i(event_clock_time),
														  // Event ID control.
														  .epoch_i(epoch_i),
														  .evid_reset_i(evid_reset_i),
														  .next_id_o(next_id_o),
														  // Event data
														  .event_addr_o(event_write_addr),
														  .event_dat_o(event_write_dat),
														  .event_wr_o(event_write),
														  // Error
														  .event_error_o(event_error),
														  .CMD_o(CMD_o));
	ANITA3_event_buffers u_event_buffers(.clk33_i(clk33_i),
													 .clk250_i(clk250_i),
													 .event_wr_addr_i(event_write_addr),
													 .event_wr_dat_i(event_write_dat),
													 .event_wr_i(event_write),
													 .clear_evt_i(clr_evt_i),
													 .clear_evt_250_o(clr_buffer_250),
													 .read_buffer_o(clear_buffer),
													 .rst_i(clr_all_i),
													 .event_rd_addr_i(event_addr_i),
													 .event_rd_dat_o(event_dat_o));
	// add more later
	ANITA3_scalers u_scalers(.clk33_i(clk33_i),
									 .L3_i(phi_scaler),
									 .pps_i(pps_clk33_i),
									 .sec_i(current_pps_time),
									 .c3po_i(current_clock_time),
									 .scal_addr_i(scal_addr_i),
									 .scal_dat_o(scal_dat_o));

	assign trig_out_o = digitize;

endmodule   
   
   