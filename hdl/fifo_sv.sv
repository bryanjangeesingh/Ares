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

    fifo_state state_prev;
    fifo_state state_prev_2;

    logic done_dumping_prev;
    logic done_dumping_prev_2;

    assign s00_axis_tready = 1;
    assign m00_axis_tstrb = 16'hF; 

    always_ff @(posedge s00_axis_aclk) begin
        done_dumping_prev <= done_dumping;
        done_dumping_prev_2 <= done_dumping_prev;
        if (~s00_axis_aresetn) begin
            done_dumping_prev <= 0;
            done_dumping_prev_2 <= 0;
            adc_counter <= 0;
            state <= WAITING;
        end
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
                if (done_dumping_prev_2) begin
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
            state_prev <= state;
            state_prev_2 <= state_prev;
            if (state_prev_2 == DUMPING) begin
                m00_axis_tvalid <= 1;
                m00_axis_tlast <= 0;
                
                case (array_index)      // ASSUMES first sample of the 8 in the LSB
                    0: begin 
                        m00_axis_tdata <= holding_buffer[15:0];
                    end 
                    1: begin 
                        m00_axis_tdata <= holding_buffer[31:16];
                    end 
                    2: begin 
                        m00_axis_tdata <= holding_buffer[47:32];
                    end 
                    3: begin 
                        m00_axis_tdata <= holding_buffer[63:48];
                    end 
                    4: begin 
                        m00_axis_tdata <= holding_buffer[79:64];
                    end 
                    5: begin 
                        m00_axis_tdata <= holding_buffer[95:80];
                    end 
                    6: begin 
                        m00_axis_tdata <= holding_buffer[111:96];
                    end 
                    7: begin 
                        m00_axis_tdata <= holding_buffer[127:112];
                    end 
                
                    default: begin
                         m00_axis_tdata <= 0;
                    end 
                endcase

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



