
`timescale 1 ns / 1 ps

	module TLAST_maker #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S01_AXIS
		parameter integer C_S01_AXIS_TDATA_WIDTH	= 16,

		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 16,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_START_COUNT	= 32
	)
	(
		// Users to add ports here
		input wire [3:0] control,
		output wire [3:0] probe,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S01_AXIS
		input wire  s01_axis_aclk,
		input wire  s01_axis_aresetn,
		output wire  s01_axis_tready,
		input wire [C_S01_AXIS_TDATA_WIDTH-1 : 0] s01_axis_tdata,
		input wire [(C_S01_AXIS_TDATA_WIDTH/8)-1 : 0] s01_axis_tstrb,
		input wire  s01_axis_tlast,
		input wire  s01_axis_tvalid,

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready
	);
	
	assign m00_axis_tvalid = (s01_axis_tvalid && s00_axis_tvalid);
	assign m00_axis_tdata = {s01_axis_tdata[15:0], s00_axis_tdata[15:0]};
	assign m00_axis_tstrb = s00_axis_tstrb;
	assign s01_axis_tready = m00_axis_tready;
	assign s00_axis_tready = m00_axis_tready;
	assign m00_axis_tlast = control[0] ? (counter_16 == 65535) : (counter_18 == 262143);
	
	reg [15:0] counter_16;
	reg [17:0] counter_18;
	
	assign probe = control;
	
	always @(posedge s00_axis_aclk) begin
	   if (~s00_axis_aresetn) begin
	       counter_16 <= 0;
	       counter_18 <= 0;   
	   end else begin
	       counter_16 <= counter_16 + 1;
	       counter_18 <= counter_18 + 1;
	   end
	
	end

	// Add user logic here

	// User logic ends

	endmodule
