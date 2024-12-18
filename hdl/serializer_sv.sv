module serializer_sv #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 192,
        parameter integer C_M00_AXIS_TDATA_WIDTH  = 16,
        parameter integer PACKET_COUNT = 512
    )
    (                 
    input wire  s00_axis_aclk, s00_axis_aresetn, // ADC axis
    input wire  s00_axis_tlast, s00_axis_tvalid,
    input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
    input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1: 0] s00_axis_tstrb,
    output logic  s00_axis_tready,

    input wire  m00_axis_aclk, m00_axis_aresetn, // FIR axis
    input wire  m00_axis_tready,
    output logic  m00_axis_tvalid, m00_axis_tlast,
    output logic [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
    output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb,
    output logic [3:0] debugger);

    typedef enum logic {WAITING=0, DUMPING=1} fifo_state;
    fifo_state state;
    logic [191:0] holding_buffer;
    logic [9:0] reading_address;
    logic [3:0] array_index;

    logic got_to_dumping;
    logic sent_data;
    logic completed_dumping;

    assign debugger = {1'b1, got_to_dumping, sent_data, completed_dumping};
    assign m00_axis_tstrb = 4'hF;
    assign m00_axis_tlast = (reading_address == (PACKET_COUNT - 1) && array_index == 11);

    always_ff @(posedge s00_axis_aclk) begin
        if (~s00_axis_aresetn) begin
            state <= WAITING;
            got_to_dumping <= 0;
            sent_data <= 0;
            completed_dumping <= 0;
        end

        case (state)
            WAITING: begin
                if (s00_axis_tvalid) begin
                    state <= DUMPING;
                    s00_axis_tready <= 1;
                    array_index <= 0;
                    reading_address <= 0;
                    holding_buffer <= s00_axis_tdata;
                end
            end

            DUMPING: begin
                got_to_dumping <= 1;
                if (s00_axis_tvalid && m00_axis_tready) begin
                    m00_axis_tvalid <= 1;
                    sent_data <= 1;
                    
                    case (array_index)      // ASSUMES first sample of the 8 in the LSB
                        0: m00_axis_tdata <= holding_buffer[15:0];
                        1: m00_axis_tdata <= holding_buffer[31:16];
                        2: m00_axis_tdata <= holding_buffer[47:32];
                        3: m00_axis_tdata <= holding_buffer[63:48];
                        4: m00_axis_tdata <= holding_buffer[79:64];
                        5: m00_axis_tdata <= holding_buffer[95:80];
                        6: m00_axis_tdata <= holding_buffer[111:96];
                        7: m00_axis_tdata <= holding_buffer[127:112];
                        8: m00_axis_tdata <= holding_buffer[143:128];
                        9: m00_axis_tdata <= holding_buffer[159:144];
                        10: m00_axis_tdata <= holding_buffer[175:160];
                        11: m00_axis_tdata <= holding_buffer[191:176];
                        default: m00_axis_tdata <= 0; 
                    endcase

                    array_index <= array_index + 1;
                    if (array_index == 10) begin
                        s00_axis_tready <= 1;
                    end

                    if (array_index == 11) begin
                        reading_address <= reading_address + 1;
                        s00_axis_tready <= 0;
                        array_index <= 0;
                        holding_buffer <= s00_axis_tdata;
                    end

                    if (reading_address == (PACKET_COUNT - 1) && array_index == 11) begin
                        completed_dumping <= 1;
                        state <= WAITING;
                        m00_axis_tvalid <= 0;
                        reading_address <= 0;
                    end 
                end else begin
                    m00_axis_tvalid <= 0;
                end
            end

            default: begin
                state <= WAITING;
            end
        endcase
    end
endmodule
