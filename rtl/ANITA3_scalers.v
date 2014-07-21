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
module ANITA3_scalers(
		clk33_i,
		L3_i,
		pps_i,
		sec_i,
		c3po_i,
		scal_addr_i,
		scal_dat_o
    );

	parameter NUM_PHI = 16;

	input clk33_i;
	input [2*NUM_PHI-1:0] L3_i;
	input pps_i;
	input [15:0] sec_i;
	input [31:0] c3po_i;
	
	input [5:0] scal_addr_i;
	output [31:0] scal_dat_o;
	
	// Scaler map is just straight to the L2s.
	// Address 0x10 - 0x17.
	// Then C3PO 250 MHz at 0x27.
	// Then PPS counter at 0x29 bits 31:16.	
	
	reg [2*NUM_PHI-1:0] l3_reg = {2*NUM_PHI{1'b0}};
	reg [2*NUM_PHI-1:0] l3_reg2 = {2*NUM_PHI{1'b0}};

	reg [31:0] output_data;
	
	reg [7:0] l3_scalers[2*NUM_PHI-1:0];
	reg [7:0] l3_scalers_hold[2*NUM_PHI-1:0];
	wire [7:0] l3_scalers_mux = l3_scalers_hold[scal_addr_i[4:0]];
	integer i,j;
	initial begin
		for (i=0;i<2*NUM_PHI;i=i+1) begin
			l3_scalers[i] <= {8{1'b0}};
		end
	end
	always @(posedge clk33_i) begin
		l3_reg <= L3_i;
		l3_reg2 <= l3_reg;
		for (j=0;j<2*NUM_PHI;j=j+1) begin
			if (pps_i) l3_scalers[j] <= {8{1'b0}};
			else if (l3_reg[j] && !l3_reg2[j]) l3_scalers[j] <= l3_scalers[j] + 1;

			if (pps_i) l3_scalers_hold[j] <= l3_scalers[j];
		end
	end
	// 101001
	// 100111
	
	always @(scal_addr_i or l3_scalers_mux or c3po_i) begin
		if (scal_addr_i[5]) output_data <= l3_scalers_mux;
		else begin
			if (scal_addr_i[2]) output_data <= {sec_i,16'h00};
			else output_data <= c3po_i;
		end
	end
	
	assign scal_dat_o = output_data;
		
endmodule
