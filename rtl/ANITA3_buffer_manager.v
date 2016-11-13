module ANITA3_buffer_manager( 
					clk250_i,
					rst_i,
			      trig_i,					
			      trig_buffer_o,
			      clear_i,
			      clear_buffer_i,
			      digitize_o,
					digitize_buffer_o,
					digitize_source_o,
					buffer_status_o,
			      HOLD_o,
			      dead_o
			      );

   parameter NUM_HOLD = 4;
   localparam BUFFER_HELD = 1'b1;
   localparam BUFFER_FREE = 1'b0;
   
   input clk250_i;
	input rst_i;
   input [3:0] trig_i;
   output [1:0] trig_buffer_o;
   input       clear_i;
   input [1:0] clear_buffer_i;
   output digitize_o;
	output [1:0] digitize_buffer_o;
	output [3:0] digitize_source_o;
   output [NUM_HOLD-1:0] HOLD_o;
	output [NUM_HOLD-1:0] buffer_status_o;
	output dead_o;

	reg trig_all = 0;
	reg [3:0] trig_source = {4{1'b0}};
	reg [3:0] trig_store = {4{1'b0}};
	reg digitize_flag = 0;
	reg [1:0] digitize_buffer = {2{1'b0}};
	reg [NUM_HOLD-1:0] held_buffers = {NUM_HOLD{BUFFER_FREE}};
   reg [1:0] current_buffer = {2{1'b0}};
   reg 	     trigger_dead = 0;
	reg [NUM_HOLD-1:0] buffer_status = {NUM_HOLD{BUFFER_FREE}};
	wire trigger_holdoff;

   integer i;
	
   always @(posedge rst_i or posedge clk250_i) begin
		if(rst_i)
			begin
				trig_all<= 0;
				trigger_dead <= 0;
				trig_source<= {4{1'b0}};
				trig_store<= {4{1'b0}};
				held_buffers <= {NUM_HOLD{BUFFER_FREE}};
				current_buffer <= {2{1'b0}};
			end
		else
			begin
				trig_all <= !trig_all && |trig_i && !trigger_dead && !trigger_holdoff;
				trig_store <= trig_i;
				if (trig_all) trig_source <= trig_store;

            for (i=0;i<NUM_HOLD;i=i+1) begin : BUFFER_LOOP
               if (clear_buffer_i == i && clear_i) held_buffers[i] <= BUFFER_FREE;
               else if (current_buffer == i && trig_all) held_buffers[i] <= BUFFER_HELD;
            end
            
//				if (clear_i) held_buffers[clear_buffer_i] <= BUFFER_FREE;
//				else if (trig_all) held_buffers[current_buffer] <= BUFFER_HELD;

            trigger_dead <= (held_buffers == {4{BUFFER_HELD}});
				
				if (trig_all) current_buffer <= current_buffer + 1;

				if (trig_all) digitize_flag <= 1;
				else if (!trigger_holdoff) digitize_flag <= 0;

				if (trig_all) digitize_buffer <= current_buffer;
				if (trig_all) buffer_status <= held_buffers;
			end
	end

   // Cheat and use the trigger holdoff for the case where a clear comes in when we're dead.
   // We need to wait an additional 100 ns before taking data to make sure that the LABs have
   // something.
	ANITA3_trigger_holdoff u_holdoff(.clk250_i(clk250_i),
												.rst_i(rst_i),
												.trig_i(trig_all | (clear_i && trigger_dead)),
												.holdoff_o(trigger_holdoff));												
   assign HOLD_o = held_buffers;
   assign trig_buffer_o = current_buffer;
   assign digitize_o = digitize_flag;
	assign digitize_buffer_o = digitize_buffer;
	assign digitize_source_o = trig_source;
   assign dead_o = trigger_dead;
	assign buffer_status_o = buffer_status;
endmodule
			      
			      
