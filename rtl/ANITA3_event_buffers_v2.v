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
module ANITA3_event_buffers_v2(
		input clk33_i,
		input clk250_i,
		input [7:0] event_wr_addr_i,
		input [15:0] event_wr_dat_i,
		input event_wr_i,
		input event_done_i,
		input [5:0] event_rd_addr_i,
		output [31:0] event_rd_dat_o,
		output [1:0] read_buffer_o,
		input clear_evt_i,
		output clear_evt_250_o,
		input rst_i,
		output [31:0] status_o,
		output [15:0] debug_o
    );

   parameter BUF_PER_EVENT = "SINGLE";
   // The top 2 get ignored in the double-buffered case.
   localparam BUF_BITS = 4;
   
	// This version queues the inbound event writes in a FIFO, to make sure that the ordering
	// is strict. Event writes still go into a block RAM, but event_done puts the 2 bit [7:6]
	// write address into a FIFO (which will always be only 0 or 1, mind you, making this the stupidest
	// FIFO ever).
	//
	// Then on the outbound side, the 'event ready' flag is essentially just whether or not the
	// FIFO is empty.

   // This is for the 2-buffers per event version.
	// This is the clear event that gets passed to the dual buffer manager.
	reg clear_dual_event = 0;
	// Acknowledge back from 250 MHz domain.  
	wire dual_event_cleared;
	// This bit indicates that the next clear event will execute the dual buffer clear.
	reg clear_dual_event_pending = 0;


	// These bits indicate which buffers are active. Mostly for bookkeeping.
   reg [BUF_BITS-1:0] buffer_active = {BUF_BITS{1'b0}};
   
	wire [1:0] current_buffer;
	wire 		  buffer_valid;
	wire 		  event_empty;
	assign buffer_valid = !event_empty;
	event_done_fifo u_done_fifo(.clk(clk33_i),
										 .din(event_wr_addr_i[7:6]),.wr_en(event_done_i),
										 .dout(current_buffer),.rd_en(dual_event_cleared),
										 .empty(event_empty),
										 .rst(rst_i));

	// This generates the equivalent of HOLDA, HOLDB, HOLDC, HOLDD.
	// HOLDA is set when buffer0 is active, and then cleared on the first clr_evt.
	//       This means it is 0 IF:
	//          !buffer_active[0] (!A)
	//          (clear_dual_event_pending && !current_read_buffer) (B & !C)
	//       This means it is *1* if !( !A || (B && !C))
	//       DeMorgans says !!A && !(B && !C) == A && !(B && !C)
	//       == A && (!B || !!C) == A && (!B || C)
	//       == (buffer_active[0]) && (!clear_dual_event_pending || current_read_buffer)
	// HOLDB is set when buffer0 is active.
	wire [3:0] legacy_buffer_active;
   wire [1:0] legacy_current_buffer;
   generate
      if (BUF_PER_EVENT == "SINGLE") begin : CUR_ACTIVE
         assign legacy_buffer_active = buffer_active;
         assign legacy_current_buffer = current_buffer;
         /////////////////////////////////////////
         // 		SINGLE BUFFER CLEARING LOGIC  //
         /////////////////////////////////////////

         always @(posedge clk33_i) begin : SINGLE_CLEAR
            clear_dual_event <= clear_evt_i;
         end
      end else begin : LEGACY_ACTIVE
         assign legacy_buffer_active = { buffer_active[1], 
													buffer_active[1] && (!clear_dual_event_pending || !current_buffer[0]),
													buffer_active[0],
													buffer_active[0] && (!clear_dual_event_pending || current_buffer[0]) };
         assign legacy_current_buffer = {current_buffer[0],clear_dual_event_pending};
         /////////////////////////////////////////
         // 		DUAL BUFFER CLEARING LOGIC    //
         /////////////////////////////////////////

         always @(posedge clk33_i) begin : DUAL_CLEAR
            if (rst_i) clear_dual_event_pending <= 0;
            else if (clear_evt_i && clear_dual_event_pending) clear_dual_event_pending <= 0;
            else if (clear_evt_i) clear_dual_event_pending <= 1;
            clear_dual_event <= clear_evt_i && clear_dual_event_pending;
         end            
      end
   endgenerate
   
	
	flag_sync u_sync(.in_clkA(clear_dual_event),.clkA(clk33_i),
						  .out_clkB(clear_evt_250_o),.clkB(clk250_i));
	flag_sync u_syncback(.in_clkA(clear_evt_250_o),.clkA(clk250_i),
								.out_clkB(dual_event_cleared),.clkB(clk33_i));

	/////////////////////////////////////////
	// 		BUFFER ACTIVE LOGIC				//
	/////////////////////////////////////////

	always @(posedge clk33_i) begin
		// Buffer active logic.
		if (rst_i) begin
         buffer_active <= {BUF_BITS{1'b0}};
		end else if (clear_dual_event) begin
			buffer_active[current_buffer] <= 0; //LM need to clear 1 out of 4
		end else if (event_done_i) begin
			buffer_active[event_wr_addr_i[7:6]] <= 1;
		end
	end

	/////////////////////////////////////////
	// 			   EVENT BUFFER RAM    		//
	/////////////////////////////////////////

   // Port A is 16 bits, so it has 10 address bits.
   // There are 4 possible buffers, and 64 spaces to write into. We use the top bits to indicate the buffer,
   // so we insert a gap of 2 bits betweeen [7:6] and [5:0] to get a total of 10 bits (2 + 2 + 6).
   //
   // Port B is 32 bits, so it has 9 address bits.
   // There are again 4 possible buffers, and we can read from 64 addresses (even though only 32 have data).
   // We use the current_buffer to select which buffer we're reading from, and then insert a gap of 1 bit
   // between current_buffer and event_rd_addr_i to get a total of 9 bits (2 + 1 + 6).
	RAMB16_S18_S36 u_event_buffer(.DIPA(2'b00),.DIA(event_wr_dat_i),.ADDRA({event_wr_addr_i[7:6],{2{1'b0}},event_wr_addr_i[5:0]}),.WEA(1'b1),.ENA(event_wr_i),.SSRA(1'b0),.CLKA(clk33_i),
											.DOB(event_rd_dat_o),.ADDRB({current_buffer,1'b0,event_rd_addr_i}),.WEB(1'b0),.ENB(1'b1),.SSRB(1'b0),.CLKB(clk33_i));

	assign read_buffer_o = current_buffer;
	
	assign status_o = {{15{1'b0}},buffer_valid,{10{1'b0}},legacy_buffer_active,legacy_current_buffer};

	assign debug_o[1:0] = legacy_current_buffer;
   assign debug_o[2 +: 4] = legacy_buffer_active;
	assign debug_o[6] = clear_evt_i || rst_i;
	assign debug_o[7] = event_wr_i;
   assign debug_o[8] = event_wr_addr_i[6];
	assign debug_o[9] = event_wr_addr_i[7];
	assign debug_o[10] = buffer_valid;
endmodule
