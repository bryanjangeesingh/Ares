module average #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 32,
        parameter integer C_M00_AXIS_TDATA_WIDTH  = 32
    )
    (
    input wire  s00_axis_aclk, s00_axis_aresetn, // ADC axis
    input wire  s00_axis_tlast, s00_axis_tvalid,
    input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
    input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1: 0] s00_axis_tstrb,
    output logic  s00_axis_tready,

    // Ports of Axi Master Bus Interface M00_AXIS
    input wire  m00_axis_aclk, m00_axis_aresetn, // FIR axis
    input wire  m00_axis_tready,
    output logic  m00_axis_tvalid, m00_axis_tlast,
    output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
    output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb);

    logic prev_valid_in;
    logic [15:0] ix;
    logic [15:0] trigger_number;
    always_ff @(posedge s00_axis_aclk) begin

        prev_valid_in <= s00_axis_tvalid;

        if (s00_axis_tvalid && ~(prev_valid_in)) begin

        end

        

    end

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(32), // 8 16 bit samples
        .RAM_DEPTH(1024)  // 1024 samples in 128 sets of 8
    ) fifo_buffer (
        .addra(adc_counter),
        .clka(s00_axis_aclk),
        .wea(state == FILLING),
        .dina(s00_axis_tdata),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(s00_axis_aresetn),
        .douta(),

        .addrb(reading_address),
        .dinb(),
        .clkb(m00_axis_aclk),
        .web(1'b0),
        .enb(1'b1),
        .regceb(1'b1),
        .rstb(m00_axis_aresetn),
        .doutb(holding_buffer)
    );

endmodule
