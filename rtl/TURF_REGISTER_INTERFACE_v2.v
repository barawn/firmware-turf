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
module TURF_REGISTER_INTERFACE_v2(input clk_i,
				  // Muxed registers.
				  input [31:0] 	scal_dat_i,
				  output [5:0] 	scal_addr_o,
				  input [31:0] 	event_dat_i,
				  output [5:0] 	event_addr_o,
				  // Dedicated register outputs.
				  output [31:0] ant_mask_o,
				  output [31:0] phi_mask_o,
				  output [11:0] epoch_o,
				  output 	evid_reset_o,
				  output 	clr_all_o,
				  output 	clr_evt_o,
				  output 	dcm_reset_o,
				  output 	disable_o,
				  output 	en_pps1_trig_o,
				  output 	en_pps2_trig_o,
				  output 	dis_ext_trig_o,
				  output 	soft_trig_o,
				  // Dedicated register inputs.
				  // busy_i is the "busy_a" flag from the SURFs. Use for
				  // identification checking.
				  input [11:0]		busy_i,
				  // Next event ID.
				  input [31:0] 	next_id_i,
				  // Event buffer status.
				  input [31:0] 	buf_status_i, 
				  // DCM status.
				  input [2:0] 		dcm_status_i,
				  /// Clock register.
				  output [31:0] pps_time_o,
				  // TURFIO interface
				  input 	nCSTURF,
				  input 	TURF_WnR,
				  inout [7:0] 	TURF_DIO,
				  output [34:0] debug_o);

   parameter [31:0] IDENT = "TURF";
   parameter [31:0] VERSION = {32{1'b0}};
      
   // IOB-pushed registers.
   (* IOB = "TRUE" *)
   reg 						ncsturf_q;
   (* IOB = "TRUE" *)
   reg 						turf_wnr_q;
   (* IOB = "TRUE" *)
   reg [7:0] 					turf_di_q = {8{1'b0}};
//   (* IOB = "TRUE" *)
//   reg [7:0] 					turf_oeb_q = {8{1'b1}};
	wire [7:0] turf_oeb_q;
   (* IOB = "TRUE" *)
   reg [7:0] 					turf_do_q = {8{1'b0}};

   // Write flag.
   reg 						wr_reg = 0;
   // Indicates end of read (end of bus ownership)
   reg 						terminate_read = 0;
   
   wire 					turf_oe;

   // ID register.
   wire [31:0] 					ident_register = IDENT;
   // Version register
   wire [31:0] 					version_register = VERSION;  
   // Holding register for write addresses.
   reg [7:0] 					address_register = {8{1'b0}};
   // Holding register for incoming data.
   reg [31:0] 					data_register_in = {32{1'b0}};   
   
   // Phi mask register.
   wire 					sel_phi_mask_register;   
   reg [31:0] 					phi_mask_register = {32{1'b0}};
   reg [31:0] 					ant_mask_register = {32{1'b0}};
   // Event ID epoch register.
   wire 					sel_epoch_register;   
   reg [11:0] 					epoch_register = {12{1'b0}};
   reg 						evid_reset = 0;   
   // Trigger control register.
   wire 					sel_trigger_register;   
   reg [3:0]			trigger_register = {4{1'b0}};
   // Timed trigger register.
   wire 					sel_clock_register;
   reg [31:0] 					clock_register = {32{1'b0}};   
   // Clear and disable register.
   wire 					sel_clear_register;   
   reg [3:0] 					clear_register = {4{1'b0}};
   
   // Bank 0 = registers
   // Bank 1/2 = Event data.
   // Bank 3 = Scalers.
	wire [31:0] 					turf_registers[15:0];
	// Multiplex registers.
	wire [31:0]						turf_register_mux;
   // This contains the banks.
   wire [31:0] 					turf_data_array[3:0];
	// This multiplexes the banks;
	wire [31:0]						turf_data_mux;
   // This multiplexes the banks.
   wire [7:0] 					turf_do_in;
   // Holding register for outgoing data.
   reg [23:0] 					data_register_out = {24{1'b0}};

   localparam FSM_BITS = 4;
   localparam [FSM_BITS-1:0] IDLE = 0;   // Wait for nCSTURF_Q
   localparam [FSM_BITS-1:0] WR0 = 1;    // Byte0 from TURFIO on bus
   localparam [FSM_BITS-1:0] WR1 = 2;    // Byte1 from TURFIO on bus
   localparam [FSM_BITS-1:0] WR2 = 3;    // Byte2 from TURFIO on bus
   localparam [FSM_BITS-1:0] WR3 = 4;    // Byte3 from TURFIO on bus
   localparam [FSM_BITS-1:0] RD1 = 5;    // Byte1 to TURFIO on bus
   localparam [FSM_BITS-1:0] RD2 = 6;    // Byte2 to TURFIO on bus
   localparam [FSM_BITS-1:0] RD3 = 7;    // Byte3 to TURFIO on bus
	localparam [FSM_BITS-1:0] RD4 = 8; 	  // Complete.
   reg [FSM_BITS-1:0] 				state = IDLE;

   // Logic associated with the state machine.
   // See TURFBUSv2.txt for more details.
   always @(posedge clk_i) begin : FSM_LOGIC
      case (state)
	IDLE: begin
	   if (!ncsturf_q && !turf_wnr_q) state <= RD1;
	   else if (!ncsturf_q) state <= WR0;
	end
	RD1: state <= RD2;
	RD2: state <= RD3;
	RD3: state <= RD4;
	RD4: state <= IDLE;
	WR0: state <= WR1;
	WR1: state <= WR2;
	WR2: state <= WR3;
	WR3: state <= IDLE;
      endcase // case (state)
   end // block: FSM_LOGIC

   // Positive clock edge IOB logic. These are all inputs.
   always @(posedge clk_i) begin : IOB_LOGIC_POSITIVE
      turf_di_q <= TURF_DIO;
      ncsturf_q <= nCSTURF;
      turf_wnr_q <= TURF_WnR;
   end

	generate
		genvar k;
		for (k=0;k<8;k=k+1) begin : STOP_SCREWING_ME
			(* IOB = "TRUE" *)
			FD u_oebfd(.D(turf_oe),.C(~clk_i),.Q(turf_oeb_q[k]));
		end
	endgenerate
   // Negative clock edge IOB logic. These are outputs.
   always @(negedge clk_i) begin : IOB_LOGIC_NEGATIVE
      turf_do_q <= turf_do_in;
//      turf_oeb_q <= {8{!turf_oe}};
   end

   always @(posedge clk_i) begin : REGISTER_LOGIC
      // Capture read data from internal registers.
      if (state == IDLE && !ncsturf_q && !turf_wnr_q)
			data_register_out <= turf_data_mux[31:8];
      else if (state == RD1 || state == RD2) begin
			data_register_out <= {{8{1'b0}},data_register_out[23:8]};
      end

      // Capture inbound address and data.
      if (state == IDLE && !ncsturf_q && turf_wnr_q) address_register <= turf_di_q;
      if (state == WR0) data_register_in[7:0] <= turf_di_q;
      if (state == WR1) data_register_in[15:8] <= turf_di_q;
      if (state == WR2) data_register_in[23:16] <= turf_di_q;
      if (state == WR3) data_register_in[31:24] <= turf_di_q;

      // At posedge of RD3, data is captured, and output enable
      // goes low 1/2 clock afterwards.
      terminate_read <= (state == RD3);
      
      wr_reg <= (state == WR3);
      if (wr_reg && (address_register[3:0] == 4'd4)) ant_mask_register <= data_register_in;
      if (wr_reg && (address_register[3:0] == 4'd6)) phi_mask_register <= data_register_in;
      if (wr_reg && (address_register[3:0] == 4'd7)) begin
	 epoch_register <= data_register_in[11:0];
	 evid_reset <= 1;
      end else begin
	 evid_reset <= 0;
      end
	 
      if (wr_reg && (address_register[3:0] == 4'd8)) begin
			trigger_register[3:1] <= data_register_in[3:1];
		end
		if (wr_reg && (address_register[3:0] == 4'd8)) begin
			trigger_register[0] <= data_register_in[0];
		end else begin
			trigger_register[0] <= 0;
		end
      if (wr_reg && (address_register[3:0] == 4'd12)) clear_register <= data_register_in[3:0];
      else clear_register[1:0] <= {2{1'b0}};

      if (wr_reg && (address_register[3:0] == 4'd9)) clock_register <= data_register_in;
      
   end

   assign turf_registers[0] = ident_register;
   assign turf_registers[1] = version_register;
   assign turf_registers[2] = ident_register;
   assign turf_registers[3] = version_register;
   assign turf_registers[4] = ant_mask_register;
   assign turf_registers[5] = {32{1'b0}};
   assign turf_registers[6] = phi_mask_register;
   assign turf_registers[7] = {{20{1'b0}}, epoch_register};
   assign turf_registers[8] = {{28{1'b0}}, trigger_register};
   assign turf_registers[9] = {{5{1'b0}}, clock_register};
   assign turf_registers[10] = buf_status_i;
   assign turf_registers[11] = next_id_i;
   assign turf_registers[12] = {busy_i,{13{1'b0}},dcm_status_i,clear_register};
   assign turf_registers[13] = turf_registers[5];
   assign turf_registers[14] = turf_registers[6];
	assign turf_registers[15] = turf_registers[7];
	
	assign turf_register_mux = turf_registers[turf_di_q[3:0]];
	assign turf_data_mux = turf_data_array[turf_di_q[7:6]];
	
   assign turf_do_in = (state == IDLE) ? turf_data_mux[7:0] : data_register_out[7:0];   
   assign turf_oe = !(!turf_wnr_q && !terminate_read);
   
   assign turf_data_array[0] = turf_register_mux;
	assign turf_data_array[1] = event_dat_i;
   assign turf_data_array[2] = event_dat_i;
   assign turf_data_array[3] = scal_dat_i;
   
   assign scal_addr_o = turf_di_q[5:0];
   assign event_addr_o = turf_di_q[5:0];
	
   assign ant_mask_o = ant_mask_register;
   assign phi_mask_o = phi_mask_register;
   assign epoch_o = epoch_register;
   assign evid_reset_o = evid_reset;
   assign clr_all_o = clear_register[0];
   assign clr_evt_o = clear_register[1];
   assign disable_o = clear_register[2];
	assign dcm_reset_o = clear_register[3];
	
   assign soft_trig_o = trigger_register[0];   
   assign en_pps1_trig_o = trigger_register[1];
   assign en_pps2_trig_o = trigger_register[2];
   assign dis_ext_trig_o = trigger_register[3];
      
	assign pps_time_o = clock_register;	
	
   generate
      genvar i;
      for (i=0;i<8;i=i+1) begin : LOOP
	 assign TURF_DIO[i] = (turf_oeb_q[i]) ? 1'bZ : turf_do_q[i];
      end
      endgenerate

	// Replicate the bus. Outputs need to be delayed.
	(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
	(* KEEP = "TRUE" *)
	reg [7:0] turf_do_debug = {8{1'b0}};
	reg turf_oe_debug = 1;
	always @(posedge clk_i) begin
		turf_do_debug <= turf_do_in;
		turf_oe_debug <= turf_oe;
	end
	assign debug_o[7:0] = (turf_oe_debug) ? turf_di_q : turf_do_debug;
	assign debug_o[8] = ncsturf_q;
	assign debug_o[9] = turf_wnr_q;
	assign debug_o[10 +: 3] = state;
	assign debug_o[34:13] = {(34-13+1){1'b0}};

endmodule // TURF_REGISTER_INTERFACE_v2

      
   
   
				  
				  
				 
