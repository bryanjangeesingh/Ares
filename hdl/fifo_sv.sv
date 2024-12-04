module fifo_sv #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 192,
        parameter integer C_M00_AXIS_TDATA_WIDTH  = 32
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
    output logic [(C_M00_AXIS_TDATA_WIDTH/8)-1: 0] m00_axis_tstrb

);
    typedef enum logic {WAITING=0, DUMPING=1} fifo_state;
    fifo_state state;
    logic [191:0] holding_buffer;
    logic [7:0] reading_address;
    logic [3:0] array_index;
    assign m00_axis_tstrb = 4'hF;
    assign m00_axis_tlast = (reading_address == 63 && array_index == 11);

    always_ff @(posedge s00_axis_aclk) begin
        if (~s00_axis_aresetn) begin
            state <= WAITING;
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
                if (s00_axis_tvalid && m00_axis_tready) begin
                    m00_axis_tvalid <= 1;
                    
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

                    if (reading_address == 63 && array_index == 11) begin
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

//     // typedef enum logic [1:0] {WAITING=0, FILLING=1, DUMPING=2} fifo_state;
//     logic [1:0] state;


//     logic [5:0] adc_counter;
//     logic [191:0] holding_buffer;
//     logic [7:0] reading_address;
//     logic [3:0] array_index;
    

//     assign s00_axis_tready = 1;
//     assign m00_axis_tstrb = 32'hFFFF; 
//     assign m00_axis_tlast = (reading_address == 63 && array_index == 11);


//     always_ff @(posedge s00_axis_aclk) begin
//         if (~s00_axis_aresetn) begin
//             state <= WAITING;
//         end
//         case (state)
//             WAITING: begin
//                 if (s00_axis_tvalid) begin
//                     state <= FILLING;
//                     adc_counter <= 0;
//                 end
//             end

//             FILLING: begin
//                 adc_counter <= adc_counter + 1;
//                 if (adc_counter == 63) begin
//                     state <= DUMPING;
//                     array_index <= 0;
//                     reading_address <= 0;
//                 end
//             end

//             DUMPING: begin
//                 m00_axis_tvalid <= 1;
                
//                 case (array_index)      // ASSUMES first sample of the 8 in the LSB
//                     0: begin 
//                         m00_axis_tdata <= holding_buffer[15:0];
//                     end 
//                     1: begin 
//                         m00_axis_tdata <= holding_buffer[31:16];
//                     end 
//                     2: begin 
//                         m00_axis_tdata <= holding_buffer[47:32];
//                     end 
//                     3: begin 
//                         m00_axis_tdata <= holding_buffer[63:48];
//                     end 
//                     4: begin 
//                         m00_axis_tdata <= holding_buffer[79:64];
//                     end 
//                     5: begin 
//                         m00_axis_tdata <= holding_buffer[95:80];
//                     end 
//                     6: begin 
//                         m00_axis_tdata <= holding_buffer[111:96];
//                     end 
//                     7: begin 
//                         m00_axis_tdata <= holding_buffer[127:112];
//                     end 
//                     8: begin 
//                         m00_axis_tdata <= holding_buffer[143:128];
//                     end 
//                     9: begin 
//                         m00_axis_tdata <= holding_buffer[159:144];
//                     end 
//                     10: begin 
//                         m00_axis_tdata <= holding_buffer[175:160];
//                     end 
//                     11: begin 
//                         m00_axis_tdata <= holding_buffer[191:176];
//                     end 
//                     default: begin
//                          m00_axis_tdata <= 0;
//                     end 
//                 endcase
//                 array_index <= array_index + 1;
//                 if (array_index == 11) begin
//                     reading_address <= reading_address + 1;
//                 end
//                 // termination logic 
//                 if (reading_address == 63 && array_index == 11) begin
//                     state <= WAITING;
//                     m00_axis_tvalid <= 0;
//                     reading_address <= 0;
//                     array_index <= 0;
//                 end
//             end
//         endcase
//     end
// endmodule



