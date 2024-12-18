module averager_sv #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 24,
        parameter integer C_M00_AXIS_TDATA_WIDTH  = 32,
        parameter integer SAMPLES_PER_TRIGGER = 6144,
        parameter integer LIVE_AVERAGES = 64,
        parameter integer LONG_AVERAGES = 8192
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

    input wire btn,
    output logic [3:0] debugger);

    typedef enum {IDLE=0, COLLECTING=1, AVERAGING=2} state_t;

    state_t state;

    logic [15:0] sample_counter;  
    logic [15:0] trigger_counter; 
    logic [15:0] output_counter;  
    logic prev_valid_in;
    logic long_averaging;

    logic got_to_collection;
    logic got_to_averaging;
    logic sending_data;         
    
    // Memory for accumulation
    logic [39:0] accumulator [SAMPLES_PER_TRIGGER-1:0];  // each individual sample is 48 bits

    assign s00_axis_tready = 1;
    assign m00_axis_tstrb = 4'b1111;
    assign debugger = {btn, sending_data, got_to_averaging, got_to_collection};
    assign m00_axis_tlast = (output_counter == SAMPLES_PER_TRIGGER - 1);

    always_ff @(posedge s00_axis_aclk) begin
        if (state==AVERAGING) begin
            got_to_averaging <= 1;
        end

        if (state==COLLECTING) begin
            got_to_collection <= 1;
        end

        if (~s00_axis_aresetn) begin
            state <= IDLE;
            prev_valid_in <= 0;
            trigger_counter <= 0;
            got_to_averaging <= 0;
            got_to_collection <= 0;
            sending_data <= 0;
            long_averaging <= 0;

        end else begin
            prev_valid_in <= s00_axis_tvalid;
            case (state)
                IDLE: begin
                    if (btn) begin
                        long_averaging <= 1;
                    end 
                    if (s00_axis_tvalid && ~prev_valid_in) begin
                        state <= COLLECTING;
                        sample_counter <= 0;
                    end else begin
                        m00_axis_tvalid <= 0;
                        // m00_axis_tlast <= 0;
                    end
                end
                
                COLLECTING: begin
                    if (s00_axis_tvalid) begin
                        accumulator[sample_counter] <= $signed(accumulator[sample_counter]) + $signed(s00_axis_tdata[22:7]);
                        sample_counter <= sample_counter + 1;
                        
                        if (sample_counter == SAMPLES_PER_TRIGGER-1) begin
                            trigger_counter <= trigger_counter + 1;

                            if (trigger_counter == (long_averaging ? (LONG_AVERAGES - 1) : (LIVE_AVERAGES-1))) begin
                                state <= AVERAGING;
                                output_counter <= 0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                        // end
                    end
                end
                
                AVERAGING: begin
                    // Perform averaging and output for all samples
                    if (m00_axis_tready) begin
                        sending_data <= 1;
                        m00_axis_tvalid <= 1;
                        m00_axis_tdata <= $signed(accumulator[output_counter]) >>> (long_averaging ? 13 : 6);
                        accumulator[output_counter] <= 0;
                        output_counter <= output_counter + 1;
                        if (output_counter == (SAMPLES_PER_TRIGGER-1)) begin
                            if (long_averaging) begin
                                long_averaging <= 0;
                            end
                            state <= IDLE;
                            trigger_counter <= 0;
                            m00_axis_tvalid <= 0;
                            output_counter <= 0;
                        end
                    end else begin
                        m00_axis_tvalid <= 0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule





