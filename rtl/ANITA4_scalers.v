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
module ANITA4_scalers(
		clk33_i,
      RF_i,
      gated_RF_i,
		L3_i,
		L3_mon_i,
		L2_i,
		refpulse_i,
		pps_i,
		sec_i,
		c3po_i,
		scal_addr_i,
		scal_dat_o,
		deadtime_i
    );

	parameter NUM_PHI = 16;

	input clk33_i;
   input RF_i;
   input gated_RF_i;
	input [2*NUM_PHI-1:0] L3_i;
	input [2*NUM_PHI-1:0] L3_mon_i;
	
	input [2*NUM_PHI-1:0] L2_i;
	
	input refpulse_i;
	input pps_i;
	input [15:0] sec_i;
	input [31:0] c3po_i;
	input [15:0] deadtime_i;
	
	input [5:0] scal_addr_i;
	output [31:0] scal_dat_o;
	
	// Scaler map is just straight to the L2s.
	// Address 0x10 - 0x17.
	// Then C3PO 250 MHz at 0x27.
	// Then PPS counter at 0x29 bits 31:16.	
	
	reg [2*NUM_PHI-1:0] l3_reg = {2*NUM_PHI{1'b0}};
	reg [2*NUM_PHI-1:0] l3_reg2 = {2*NUM_PHI{1'b0}};
	reg [2*NUM_PHI-1:0] l3_mon_reg = {2*NUM_PHI{1'b0}};
	reg [2*NUM_PHI-1:0] l3_mon_reg2 = {2*NUM_PHI{1'b0}};

	reg [2*NUM_PHI-1:0] l2_reg = {2*NUM_PHI{1'b0}};
	reg [2*NUM_PHI-1:0] l2_reg2 = {2*NUM_PHI{1'b0}};
	
	wire [2*NUM_PHI-1:0] l3_count_flag = l3_reg & ~l3_reg2;
	wire [2*NUM_PHI-1:0] l3_mon_flag = l3_mon_reg & ~l3_mon_reg2;

	wire [2*NUM_PHI-1:0] l2_count_flag = l2_reg & ~l2_reg2;

	
	reg [31:0] output_data;
	wire [7:0] refpulse_count;
	reg [1:0] refpulse_reg = {2{1'b0}};
	wire [7:0] refpulse_scaler;
	ANITA3_scaler u_scaler_refpulse(.clk_i(clk33_i),
											  .pps_i(pps_i),
											  .count_i(refpulse_reg[0] && !refpulse_reg[1]),
											  .scaler_o(refpulse_scaler));
   wire [15:0] rf_scaler;
   ANITA3_scaler #(.WIDTH(16),.PRESCALE(0)) u_scaler_rf(.clk_i(clk33_i),
                             .pps_i(pps_i),
                             .count_i(RF_i),
                             .scaler_o(rf_scaler));
   wire [15:0] gated_rf_scaler;
   ANITA3_scaler #(.WIDTH(16),.PRESCALE(0)) u_scaler_gated_rf(.clk_i(clk33_i),
                             .pps_i(pps_i),
                             .count_i(gated_RF_i),
                             .scaler_o(gated_rf_scaler));
	// 64 overall scalers, but they map to 16 total addresses.
	wire [7:0] l3_scalers_hold[4*NUM_PHI-1:0];	
	// 32 L2 scalers, mapping to 16 addresses
	wire [15:0] l2_scalers_hold[2*NUM_PHI-1:0];

//	wire [31:0] l3_scalers_unmuxed[15:0];
	// 32 + 64  L2 and L3 scalers,  the first mapping to 16 addresses, the next 64 mapping to the next 16 addresses	
	wire [31:0] l2_l3_scalers_unmuxed[31:0];
	
	
	
//	wire [31:0] l3_scalers_mux = l3_scalers_unmuxed[scal_addr_i[3:0]];
	wire [31:0] l2_l3_scalers_mux = l2_l3_scalers_unmuxed[scal_addr_i[4:0]];
	
	generate
		genvar i;
		// This goes from 0-31.
		for (i=0;i<2*NUM_PHI;i=i+1) begin : L3
			ANITA3_scaler u_scaler_l3(.clk_i(clk33_i),
											  .pps_i(pps_i),
											  .count_i(l3_count_flag[i]),
											  .scaler_o(l3_scalers_hold[i]));
			ANITA3_scaler u_scaler_l3_mon(.clk_i(clk33_i),
											  .pps_i(pps_i),
											  .count_i(l3_mon_flag[i]),
											  .scaler_o(l3_scalers_hold[2*NUM_PHI+i]));									  										
			// This now goes from 16-23.
			// Sequentially this goes
			// 0 = [16][0 +: 8]
			// 1 = [16][8 +: 8]
			// 2 = [16][16 +: 8]
			// 3 = [16][24 +: 8]
			// 4 = [17][0 +: 8]
			// etc.
			assign l2_l3_scalers_unmuxed[i/4 + 16][8*(i%4) +: 8] = l3_scalers_hold[i];
			// This now goes from 24-31.
			// Sequentially this goes
			// 0 = [24][0 +: 8]
			// 1 = [24][8 +: 8]
			// 2 = [24][16 +: 8]
			// 3 = [24][24 +: 8]
			assign l2_l3_scalers_unmuxed[i/4 + (2*NUM_PHI/4) + 16][8*(i%4) +: 8] = l3_scalers_hold[2*NUM_PHI+i];
		end
	endgenerate



	generate
		genvar j;
		// This goes from 0-31.
		for (j=0;j<2*NUM_PHI;j=j+1) begin : L2
			ANITA3_scaler #(.WIDTH(16), .PRESCALE(0)) u_scaler_l2(.clk_i(clk33_i), //16 bits 
											  .pps_i(pps_i),
											  .count_i(l2_count_flag[j]),
											  .scaler_o(l2_scalers_hold[j]));							  										
			// Sequentially this goes
			// 0 = [0][0 +: 16]
			// 1 = [0][16 +: 16]
			// 2 = [1][0 +: 16]
			// 3 = [1][16 +: 16]
			// 4 = [2][0 +: 16]
			// etc.
			assign l2_l3_scalers_unmuxed[j/2][16*(j%2) +: 16] = l2_scalers_hold[j]; // starting from 0 to 31
		end
	endgenerate

   wire [1:0] aux_scaler_switch = {scal_addr_i[2],scal_addr_i[0]};
	
	always @(posedge clk33_i) begin
		refpulse_reg <= {refpulse_reg[0],refpulse_i};
		l3_mon_reg <= L3_mon_i;
		l3_mon_reg2 <= l3_mon_reg;
		l3_reg <= L3_i;
		l3_reg2 <= l3_reg;
		l2_reg <= L2_i;
		l2_reg2 <= l2_reg;		
		
	end
	// Scalers map to 0x10-0x1F.	
	// 100000 = 0x20
	// 101001 = 0x29 = PPS
	// 100111 = 0x27 = C3P0 250
	
//	always @(scal_addr_i or l3_scalers_mux or c3po_i) begin
	always @(scal_addr_i or l2_l3_scalers_mux or c3po_i) begin
//		if (!scal_addr_i[5]) output_data <= l3_scalers_mux;
		if (!scal_addr_i[5]) output_data <= l2_l3_scalers_mux;
		else begin
         if (aux_scaler_switch == 2'b00) output_data <= refpulse_scaler;
         else if (aux_scaler_switch == 2'b01) output_data <= {sec_i, deadtime_i};
         else if (aux_scaler_switch == 2'b10) output_data <= {gated_rf_scaler, rf_scaler};
         else output_data <= c3po_i;
		end
	end
	
	assign scal_dat_o = output_data;
		
endmodule
