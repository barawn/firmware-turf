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
module ANITA3_event_buffers(
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

	reg clear_dual_event_pending = 0;

	reg clear_dual_event = 0;

	reg [1:0] current_read_buffer = {2{1'b0}};
	reg [1:0] current_read_buffer_hold = {2{1'b0}};
	reg [1:0] next_read_buffer;		
	reg [3:0] buffer_active = {4{1'b0}};
	always @(current_read_buffer) begin
		//next_read_buffer <= current_read_buffer + 1;
		// 2 buffers.
		next_read_buffer <= {1'b0,~current_read_buffer[0]};
	end

	always @(posedge clk33_i) begin
		if (rst_i) clear_dual_event_pending <= 0;
		else if (clear_evt_i && clear_dual_event_pending) clear_dual_event_pending <= 0;
		else if (clear_evt_i) clear_dual_event_pending <= 1;

		clear_dual_event <= clear_evt_i && clear_dual_event_pending;

		if (rst_i) begin
			buffer_active <= {4{1'b0}};
		end else if (clear_dual_event) begin
			buffer_active[current_read_buffer] <= 0;
		end else if (event_done_i) begin
			buffer_active[event_wr_addr_i[7:6]] <= 1;
		end
		
		if (rst_i) current_read_buffer <= {2{1'b0}};
		else if (clear_dual_event) current_read_buffer <= next_read_buffer;
		current_read_buffer_hold <= current_read_buffer;

	end
	flag_sync u_sync(.in_clkA(clear_evt_i),.clkA(clk33_i),
						  .out_clkB(clear_evt_250_o),.clkB(clk250_i));
	
	RAMB16_S18_S36 u_event_buffer(.DIPA(2'b00),.DIA(event_wr_dat_i),.ADDRA({event_wr_addr_i[7:6],{2{1'b0}},event_wr_addr_i[5:0]}),.WEA(1'b1),.ENA(event_wr_i),.SSRA(1'b0),.CLKA(clk33_i),
											.DOB(event_rd_dat_o),.ADDRB({current_read_buffer[1:0],1'b0,event_rd_addr_i}),.WEB(1'b0),.ENB(1'b1),.SSRB(1'b0),.CLKB(clk33_i));

	assign read_buffer_o = current_read_buffer_hold;
	assign status_o = {{15{1'b0}},buffer_active[current_read_buffer],{10{1'b0}},buffer_active,current_read_buffer};
endmodule
