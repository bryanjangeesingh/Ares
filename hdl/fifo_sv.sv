module fifo_sv #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 128,
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
    output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb,

    input wire laser_trigger
);
    
    typedef enum {WAITING=0, FILLING=1, DUMPING=2} fifo_state;
    fifo_state state;
    logic [7:0] adc_counter;
    logic [127:0] holding_buffer;
    logic done_dumping;
    logic [7:0] reading_address;
    logic [2:0] array_index;

    assign s00_axis_tready = 1;
    assign m00_axis_tstrb = 16'hF; 

    always_ff @(posedge s00_axis_aclk) begin
        case (state)
            WAITING: begin
                if (laser_trigger) begin
                    state <= FILLING;
                    adc_counter <= 0;
                end
            end

            FILLING: begin
                adc_counter <= adc_counter + 1;
                if (adc_counter == 127) begin
                    state <= DUMPING;
                end
            end

            DUMPING: begin
                if (done_dumping) begin
                    state <= WAITING;
                end
            end

            default: begin
                state <= WAITING;
            end
        endcase


    end

    always_ff @(posedge m00_axis_aclk) begin
        if (~m00_axis_aresetn) begin
            m00_axis_tvalid <= 0;
            reading_address <= 0;
            array_index <= 0;
            done_dumping <= 0;
        end

        else begin
            if (state == DUMPING) begin
                m00_axis_tvalid <= 1;
                m00_axis_tlast <= 0;
                m00_axis_tdata <= holding_buffer[array_index << 4 + 15: array_index << 4]; // ASSUMES first sample of the 8 in the LSB
                array_index <= array_index + 1;
                if (array_index == 7) begin
                    reading_address <= reading_address + 1;
                end
                // termination logic 
                if (reading_address == 127 && array_index == 7) begin
                    done_dumping <= 1;
                end
            end else begin
                m00_axis_tvalid <= 0;
                reading_address <= 0;
                array_index <= 0;
                if (done_dumping) begin
                    done_dumping <= 0;
                    m00_axis_tlast <= 1;
                end
            end
        end
    end

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(128), // 8 16 bit samples
        .RAM_DEPTH(128)  // 1024 samples in 128 sets of 8
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


