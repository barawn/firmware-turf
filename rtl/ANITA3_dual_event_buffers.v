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
module ANITA3_dual_event_buffers(
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
		output [31:0] status_o
    );


	reg clear_dual_event = 0;

	reg clear_dual_event_pending = 0;
	reg current_read_buffer = 0;

	
	reg current_read_buffer_hold = 0;
	reg [1:0] next_read_buffer;		
	reg [1:0] buffer_active = {2{1'b0}};
	wire [3:0] legacy_buffer_active = { buffer_active[1], 
													buffer_active[1] && !clear_dual_event_pending && current_read_buffer,
													buffer_active[0],
													buffer_active[0] && !clear_dual_event_pending && !current_read_buffer };

	// This is the dual event buffer version.
	always @(posedge clk33_i) begin
		if (rst_i) clear_dual_event_pending <= 0;
		else if (clear_evt_i && clear_dual_event_pending) clear_dual_event_pending <= 0;
		else if (clear_evt_i) clear_dual_event_pending <= 1;
		
		clear_dual_event <= clear_evt_i && clear_dual_event_pending;
		
		if (rst_i) begin
			buffer_active <= {2{1'b0}};
		end else if (clear_dual_event) begin
			buffer_active[current_read_buffer] <= 0;
		end else if (event_done_i) begin
			buffer_active[event_wr_addr_i[6]] <= 1;
		end
		
		if (rst_i) current_read_buffer <= 0;
		else if (clear_dual_event) begin
			case (current_read_buffer)
				1'b0: current_read_buffer <= 1'b1;
				1'b1: current_read_buffer <= 1'b0;
			endcase
		end
		
		current_read_buffer_hold <= current_read_buffer;
	end
	flag_sync u_sync(.in_clkA(clear_dual_event),.clkA(clk33_i),
						  .out_clkB(clear_evt_250_o),.clkB(clk250_i));
	
	RAMB16_S18_S36 u_event_buffer(.DIPA(2'b00),.DIA(event_wr_dat_i),.ADDRA({1'b0,event_wr_addr_i[6],{2{1'b0}},event_wr_addr_i[5:0]}),.WEA(1'b1),.ENA(event_wr_i),.SSRA(1'b0),.CLKA(clk33_i),
											.DOB(event_rd_dat_o),.ADDRB({1'b0,current_read_buffer,1'b0,event_rd_addr_i}),.WEB(1'b0),.ENB(1'b1),.SSRB(1'b0),.CLKB(clk33_i));

	assign read_buffer_o = {1'b0,current_read_buffer_hold};
	assign status_o = {{15{1'b0}},buffer_active[current_read_buffer],{10{1'b0}},legacy_buffer_active,current_read_buffer,clear_dual_event_pending};
endmodule
