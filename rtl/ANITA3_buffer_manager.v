module ANITA3_buffer_manager( 
					clk250_i,
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
   
   input clk250_i;
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
	reg [NUM_HOLD-1:0] held_buffers = {NUM_HOLD{1'b1}};
   reg [1:0] current_buffer = {2{1'b0}};
   reg 	     trigger_dead = 0;
	reg [NUM_HOLD-1:0] buffer_status = {NUM_HOLD{1'b0}};
	wire trigger_holdoff;
	
   always @(posedge clk250_i) begin
		trig_all <= |trig_i && !trigger_dead && !trigger_holdoff;
		trig_store <= trig_i;
		if (trig_all) trig_source <= trig_store;
      if (clear_i) held_buffers[clear_buffer_i] <= 1;
      else if (trig_all) held_buffers[current_buffer] <= 0;

      trigger_dead <= (held_buffers == {4{1'b0}});
      
      if (trig_all) current_buffer <= current_buffer + 1;

      if (trig_all) digitize_flag <= 1;
		else if (!trigger_holdoff) digitize_flag <= 0;

		if (trig_all) digitize_buffer <= current_buffer;
		if (trig_all) buffer_status <= held_buffers;
		
	end

	ANITA3_trigger_holdoff u_holdoff(.clk250_i(clk250_i),
												.trig_i(trig_all),
												.holdoff_o(trigger_holdoff));												

   assign HOLD_o = held_buffers;
   assign trig_buffer_o = current_buffer;
   assign digitize_o = digitize_flag;
	assign digitize_buffer_o = digitize_buffer;
	assign digitize_source_o = trig_source;
   assign dead_o = trigger_dead;
	assign buffer_status_o = buffer_status;
endmodule
			      
			      
