module fir_15 #
  (
    parameter integer C_S00_AXIS_TDATA_WIDTH  = 32,
    parameter integer C_M00_AXIS_TDATA_WIDTH  = 32
  )
  (
  // Ports of Axi Slave Bus Interface S00_AXIS
  input wire  s00_axis_aclk, s00_axis_aresetn,
  input wire  s00_axis_tlast, s00_axis_tvalid,
  input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
  input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1: 0] s00_axis_tstrb,
  output logic  s00_axis_tready,
 
  // Ports of Axi Master Bus Interface M00_AXIS
  input wire  m00_axis_aclk, m00_axis_aresetn,
  input wire  m00_axis_tready,
  output logic  m00_axis_tvalid, m00_axis_tlast,
  output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
  output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb
  );
 
  localparam NUM_COEFFS = 15;
  logic signed [7:0] coeffs [NUM_COEFFS-1 : 0];
  logic signed [C_S00_AXIS_TDATA_WIDTH -1 : 0] intmdt_term [NUM_COEFFS-1 : 0];
  logic [NUM_COEFFS - 1:0] tlast_reg;
  logic [NUM_COEFFS - 1:0] tvalid_reg;
  //initializing values
  initial begin //updated you coefficients
    coeffs[0] = -2;
    coeffs[1] = -3;
    coeffs[2] = -4;
    coeffs[3] = 0;
    coeffs[4] = 9;
    coeffs[5] = 21;
    coeffs[6] = 32;
    coeffs[7] = 36;
    coeffs[8] = 32;
    coeffs[9] = 21;
    coeffs[10] = 9;
    coeffs[11] = 0;
    coeffs[12] = -4;
    coeffs[13] = -3;
    coeffs[14] = -2;
    for(int i=0; i<NUM_COEFFS; i++)begin
      intmdt_term[i] = 0;
    end
    $display("DONE!");
  end

  // if valid is high then write the data 
  assign m00_axis_tdata = intmdt_term[0];
  assign s00_axis_tready = m00_axis_tready;
  assign m00_axis_tlast = tlast_reg[NUM_COEFFS-1];
  assign m00_axis_tvalid = tvalid_reg[NUM_COEFFS-1];
  assign m00_axis_tstrb = 4'b1111;


  always_ff @(posedge s00_axis_aclk) begin 
     if (~m00_axis_aresetn || ~s00_axis_aresetn) begin
        tlast_reg <= 0;
        tvalid_reg <= 0;

    end 
    else begin 
    
    // if the sender is outputting valid data and we are ready to accept data 
    if ((m00_axis_tready)) begin 
      for (int i = 0; i < NUM_COEFFS - 1; i = i+1) begin
        intmdt_term[i] <= $signed(coeffs[i]) * (~s00_axis_tvalid? 0 : $signed(s00_axis_tdata)) + $signed(intmdt_term[i+1]);
      end 
      // handle the i+1th term
      intmdt_term[NUM_COEFFS-1] <= $signed(coeffs[NUM_COEFFS-1]) * $signed(s00_axis_tdata);

      tlast_reg <= {tlast_reg[NUM_COEFFS-2:0], s00_axis_tlast};
      tvalid_reg <= {tvalid_reg[NUM_COEFFS-2:0], s00_axis_tvalid};
    end 
    end  
  end 
   
endmodule
