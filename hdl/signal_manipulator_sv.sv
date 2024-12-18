module signal_manipulator_sv #
	(
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 192,
		parameter integer C_M00_AXIS_START_COUNT	= 32,
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 192,
		parameter integer PACKET_COUNT = 512
	)
	(
		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready,
		input wire trigger,

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,
		output wire [3:0] debugger
	);

	logic [9:0] data_counter;

	// Add user logic here
	assign m00_axis_tlast = (data_counter == PACKET_COUNT);
	assign m00_axis_tvalid = (data_counter != 0);
	assign m00_axis_tdata = s00_axis_tdata;
	assign m00_axis_tstrb = s00_axis_tstrb;
	assign s00_axis_tready = m00_axis_tready;
	
	logic trigger_fired;
	logic reset_counter;
	logic incr;
	
	assign debugger = trigger_fired;
	
	always_ff @(posedge s00_axis_aclk) begin
	   if (~s00_axis_aresetn) begin
	       data_counter <= 0;
	       trigger_fired <= 0;
	       reset_counter <= 0;
	       incr <= 0;
	   end else begin	       
		   if (data_counter == PACKET_COUNT) begin
              reset_counter <= 1;
              data_counter <= 0;
		   end else if (data_counter != 0) begin
              incr <= 1;
              data_counter <= data_counter + 1;     
	       end else if (trigger) begin
	          trigger_fired <= 1;
	          data_counter <= 1;
	       end
	   end
	end
endmodule