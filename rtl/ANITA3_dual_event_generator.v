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
module ANITA3_dual_event_generator(
		input clk33_i,
		input clk125_i,
		input rst_i,
		input digitize_i,
		input [1:0] digitize_buffer_i,
		input [3:0] digitize_source_i,
		input [3:0] buffer_status_i,
		input [31:0] pattern_i,
		input [15:0] pps_time_i,
		input [31:0] clock_time_i,
		input [11:0] epoch_i,
		input [7:0] rf_count_i,
		input evid_reset_i,
		output [31:0] next_id_o,
		output event_error_o,
		
		output [7:0] event_addr_o,
		output [15:0] event_dat_o,
		output event_wr_o,
		output event_done_o,
		
		output [11:0] CMD_o,
		output [34:0] debug_o
    );

	// Use an 18-bit block RAM.
	wire [17:0] block_ram_mux;
	wire [17:0] block_ram_in[7:0];
		
	reg [1:0] digitize_reg = {2{1'b0}};
	reg start_flag = 0;
	reg [2:0] write_counter = {3{1'b0}};

	// Read domain.
	wire [17:0] event_data_out;
	reg event_read_enable;
	wire event_read_valid;
	
	reg [1:0] buffer_pointer = {2{1'b0}};
	reg [5:0] event_addr_pointer;
	reg [15:0] event_data;
	reg [15:0] event_count = {16{1'b0}};
	reg [31:0] next_event_id = {32{1'b0}};
	wire [19:0] next_event_id_without_epoch = next_event_id[19:0] + 1;
	reg event_wr = 0;

	reg [1:0] buffer_decoder;

	wire [1:0] buffer_out = event_data_out[1:0];
	wire [3:0] buffer_status_out = event_data_out[9:6];

	wire surf_command_done;
	wire surf_command_busy;
	
	localparam FSM_BITS = 5;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] START_EVENT = 1;
	localparam [FSM_BITS-1:0] ISSUE_ID_AND_DIGITIZE_0 = 2;
	localparam [FSM_BITS-1:0] STORE_ID_HIGH = 3;
	localparam [FSM_BITS-1:0] STORE_STATUS = 4;
	localparam [FSM_BITS-1:0] STORE_COUNT = 5;
	localparam [FSM_BITS-1:0] STORE_LOW_PATTERN = 6;
	localparam [FSM_BITS-1:0] STORE_HIGH_PATTERN = 7;
	localparam [FSM_BITS-1:0] STORE_TIME = 8;
	localparam [FSM_BITS-1:0] STORE_CLOCK_LOW = 9;
	localparam [FSM_BITS-1:0] STORE_CLOCK_HIGH = 10;
	localparam [FSM_BITS-1:0] STORE_RF_COUNT = 16;
	localparam [FSM_BITS-1:0] ISSUE_EVENT_READY = 11;
	localparam [FSM_BITS-1:0] ERROR = 12;
	localparam [FSM_BITS-1:0] WAIT_1 = 13;
	localparam [FSM_BITS-1:0] WAIT_2 = 14;
	localparam [FSM_BITS-1:0] ISSUE_ID_AND_DIGITIZE_1 = 15;
	reg [FSM_BITS-1:0] state = IDLE;

	always @(posedge clk125_i) begin
		if (rst_i) digitize_reg <= {2{1'b0}};
		else digitize_reg <= {digitize_reg[0],digitize_i};
	
		if (rst_i) start_flag <= 0;
		else if (digitize_reg[0] && !digitize_reg[1]) start_flag <= 1;
		else if (write_counter[2] && write_counter[1]) start_flag <= 0;

		if (rst_i) write_counter <= {3{1'b0}};
		else if (start_flag) write_counter <= write_counter + 1;
		else write_counter <= {3{1'b0}};
	end
	// 2 bits for digitize buffer
	// 4 bits for source
	// 4 bits for status
	// 6 bits unused
	// 2 bits stop/start.
	assign block_ram_in[0] = {2'b10,{6{1'b0}},buffer_status_i,digitize_source_i,digitize_buffer_i};
	assign block_ram_in[1] = {2'b00,pattern_i[15:0]};
	assign block_ram_in[2] = {2'b00,pattern_i[31:16]};
	assign block_ram_in[3] = {2'b00,pps_time_i};
	assign block_ram_in[4] = {2'b00,clock_time_i[15:0]};
	assign block_ram_in[5] = {2'b00,clock_time_i[31:16]};
	assign block_ram_in[6] = {2'b00,rf_count_i,digitize_source_i,digitize_buffer_i};
	assign block_ram_in[7] = block_ram_in[3];
	assign block_ram_mux = block_ram_in[write_counter];

	digitize_fifo u_fifo(.din(block_ram_mux),.wr_en(start_flag),.wr_clk(clk125_i),.full(),
								.dout(event_data_out),.rd_en(event_read_enable),.rd_clk(clk33_i),.valid(event_read_valid),
								.rst(rst_i));
	
	always @(posedge clk33_i) begin : READ_FSM
		if (rst_i) state <= IDLE;
		else begin
			case (state)
				IDLE: if (event_read_valid) begin
						if (!event_data_out[17]) state <= ERROR;
						else state <= START_EVENT;
				end
				// The check here should never happen EXCEPT if a clr_all comes in,
				// resets us, and a new event comes in while the old one was still being
				// commanded out. This covers that case, and ensures that the SURFs
				// *always* see a full command.
				START_EVENT: if (!surf_command_busy) state <= ISSUE_ID_AND_DIGITIZE_0;
				ISSUE_ID_AND_DIGITIZE_0: if (surf_command_done) state <= WAIT_1;
				WAIT_1: state <= WAIT_2;
				WAIT_2: state <= ISSUE_ID_AND_DIGITIZE_1;
				ISSUE_ID_AND_DIGITIZE_1: if (surf_command_done) state <= STORE_ID_HIGH;
				STORE_ID_HIGH: state <= STORE_STATUS;
				STORE_STATUS: state <= STORE_COUNT;
				STORE_COUNT: state <= STORE_LOW_PATTERN;
				STORE_LOW_PATTERN: state <= STORE_HIGH_PATTERN;
				STORE_HIGH_PATTERN: state <= STORE_TIME;
				STORE_TIME: state <= STORE_CLOCK_LOW;
				STORE_CLOCK_LOW: state <= STORE_CLOCK_HIGH;
				STORE_CLOCK_HIGH: state <= STORE_RF_COUNT;
				STORE_RF_COUNT: state <= ISSUE_EVENT_READY;
				ISSUE_EVENT_READY: state <= IDLE;
				ERROR: state <= ERROR;
			endcase
		end
	end

	always @(buffer_out or buffer_status_out) begin
		case (buffer_out[0])
			1'b0: begin
				// A and B
				if (((state == START_EVENT) || (state == ISSUE_ID_AND_DIGITIZE_0))) begin
					if (buffer_status_out[0]) buffer_decoder <= 2'b01;
					else buffer_decoder <= 2'b00;
				end else begin
					if (buffer_status_out[0]) buffer_decoder <= 2'b00;
					else buffer_decoder <= 2'b01;
				end
			end
			1'b1: begin
				// C and D
				if (((state == START_EVENT) || (state == ISSUE_ID_AND_DIGITIZE_0))) begin
					if (buffer_status_out[0]) buffer_decoder <= 2'b11;
					else buffer_decoder <= 2'b10;
				end else begin
					if (buffer_status_out[0]) buffer_decoder <= 2'b10;
					else buffer_decoder <= 2'b11;
				end
			end
		endcase
	end

	wire cmd_debug;

	SURF_command_interface u_command(.clk_i(clk33_i),
												.start_i((state == START_EVENT) || (state == WAIT_2)),
												.event_id_i(next_event_id),
												.buffer_i(buffer_decoder),
												.busy_o(surf_command_busy),
												.done_o(surf_command_done),
												.CMD_o(CMD_o),
												.CMD_debug_o(cmd_debug));
	
	always @(posedge clk33_i) begin 
		if (rst_i) event_wr <= 0;
		else if (state == IDLE && event_read_valid && event_data_out[17]) event_wr <= 1;
		else if (state == ISSUE_EVENT_READY) event_wr <= 0;
	
		if (state == IDLE && event_read_valid) buffer_pointer <= event_data_out[1:0];
		
		// Start with event ID 1 to Make Ryan Happy.
		if (rst_i) event_count <= 16'h0001;
		else if (state == ISSUE_EVENT_READY) event_count <= event_count + 2;
		
		if (evid_reset_i) next_event_id <= {epoch_i,{20{1'b0}}};
		else if (state == STORE_LOW_PATTERN) next_event_id <= {epoch_i, next_event_id_without_epoch};
	end

	// The event data structure is:
	// 0x00: low 8 bits: trigger source (3 bits, expanded to 4 hilariously), plus encoding of buffer
	//       high 8 bits: L3 count (all 0s for now!)
	// 0x01: event count
	// 0x02: clock time low
	// 0x03: clock time high
	// 0x04: pps count
	// 0x05: deadtime count (zero for now, read out in housekeeping)
	// 0x06: V pol phi
	// 0x07: H pol phi
	// 0x08: unused (old L2 top)
	// 0x09: unused (old L2 bottom)
	// 0x0A: unused (old L3)
	// 0x0B: unused (old L3)
	// 0x0C: unused (always unused)
	// 0x0D: unused (always unused)
	// 0x0E: unused (old L1 nadir)
	// 0x0F: unused (old L2 nadir)
	// 0x10: event id low
	// 0x11: event id high
	// 0x12: unused (old clock 250 time low)
	// 0x13: unused (old clock 250 time high)
	// 0x14: event lab ID
	// 0x15: current held buffers
	
	// This is legacy, which is why this looks hilariously awful.
	reg [1:0] buffer_sum;
	wire [1:0] this_buffer = event_data_out[1:0];
	wire [3:0] active_holds = event_data_out[6 +: 4];
	always @(this_buffer or active_holds) begin
		case (this_buffer)
			2'b00: buffer_sum <= active_holds[1] + active_holds[2] + active_holds[3];
			2'b01: buffer_sum <= active_holds[0] + active_holds[2] + active_holds[3];
			2'b10: buffer_sum <= active_holds[0] + active_holds[1] + active_holds[3];
			2'b11: buffer_sum <= active_holds[0] + active_holds[1] + active_holds[2];
		endcase
	end
	
	always @(state or next_event_id or event_data_out or event_count or buffer_pointer or buffer_sum) begin
		case (state)
			ISSUE_ID_AND_DIGITIZE_0,WAIT_1,WAIT_2,ISSUE_ID_AND_DIGITIZE_1: begin 
				event_addr_pointer <= 6'h10;
				event_data <= next_event_id[15:0];
				event_read_enable <= 0;
			end
			STORE_ID_HIGH: begin
				event_addr_pointer <= 6'h11;
				event_data <= next_event_id[31:16];
				event_read_enable <= 0;
			end			
			STORE_STATUS: begin
				event_addr_pointer <= 6'h15;
				event_data <= event_data_out[6 +: 4];
				event_read_enable <= 0;
			end
			STORE_COUNT: begin
				event_addr_pointer <= 6'h01;
				event_data <= event_count;
				event_read_enable <= 1;
			end
			STORE_LOW_PATTERN: begin
				event_addr_pointer <= 6'h06;
				event_data <= event_data_out;
				event_read_enable <= 1;
			end
			STORE_HIGH_PATTERN: begin
				event_addr_pointer <= 6'h07;
				event_data <= event_data_out;
				event_read_enable <= 1;
			end
			STORE_TIME: begin
				event_addr_pointer <= 6'h04;
				event_data <= event_data_out;
				event_read_enable <= 1;
			end
			// Store at the 250 MHz position.
			// The 133 MHz position is left open.
			STORE_CLOCK_LOW: begin
				event_addr_pointer <= 6'h12;
				event_data <= event_data_out;
				event_read_enable <= 1;
			end
			STORE_CLOCK_HIGH: begin
				event_addr_pointer <= 6'h13;
				event_data <= event_data_out;
				event_read_enable <= 1;
			end
			STORE_RF_COUNT: begin
				event_addr_pointer <= 6'h14;
				event_data <= buffer_pointer;
				event_read_enable <= 1;
			end
			ISSUE_EVENT_READY: begin
				event_addr_pointer <= 6'h00;
				event_data <= {event_data_out[15:8],1'b0,buffer_sum,event_data_out[2],event_data_out[5:2]};
				event_read_enable <= 0;
			end
			default: begin
				event_addr_pointer <= {6{1'b0}};
				event_data <= {{8{1'b0}},1'b0,buffer_sum,event_data_out[2],event_data_out[5:2]};
				event_read_enable <= 0;
			end
		endcase
	end
	assign event_addr_o[7:6] = buffer_pointer;
	assign event_addr_o[5:0] = event_addr_pointer;
	assign event_dat_o = event_data;
	assign event_wr_o = event_wr;
	assign next_id_o = next_event_id;
	assign event_error_o = (state == ERROR);
	assign event_done_o = (state == ISSUE_EVENT_READY);
	assign debug_o[0] = event_done_o;
	assign debug_o[1 +: 4] = state;
	assign debug_o[5] = surf_command_busy;
	assign debug_o[6] = surf_command_done;
	assign debug_o[7 +: 16] = event_data;
	assign debug_o[34:23] = {34-23+1{1'b0}};
endmodule
