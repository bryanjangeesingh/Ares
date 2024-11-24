module average #(
        parameter integer C_S00_AXIS_TDATA_WIDTH  = 32,
        parameter integer C_M00_AXIS_TDATA_WIDTH  = 32,
        parameter integer SAMPLES_PER_TRIGGER = 1000,
        parameter integer AVERAGES = 100
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

    typedef enum {IDLE=0, COLLECTING=1, AVERAGING=2, OUTPUTTING=3} state_t;

    state_t state;

    logic [15:0] sample_counter;  
    logic [15:0] trigger_counter; 
    logic [15:0] output_counter;  
    logic prev_valid_in;         
    
    // Memory for accumulation
    logic [47:0] accumulator [SAMPLES_PER_TRIGGER-1:0];  // each individual sample is 48 bits
    logic [31:0] averaged_data [SAMPLES_PER_TRIGGER-1:0]; 
    
    logic [9:0] write_addr, read_addr;
    logic write_enable;
    logic [31:0] holding_buffer;
    
    assign s00_axis_tready = (state == COLLECTING);
    assign m00_axis_tstrb = 4'b1111;

    always_ff @(posedge s00_axis_aclk) begin
        if (~s00_axis_aresetn) begin
            state <= IDLE;
            sample_counter <= 0;
            trigger_counter <= 0;
            output_counter <= 0;
            write_enable <= 0;
            m00_axis_tvalid <= 0;
            m00_axis_tlast <= 0;
            prev_valid_in <= 0;
            
            // Reset the accumulator and averaged data
            for (int i = 0; i < SAMPLES_PER_TRIGGER; i++) begin
                accumulator[i] <= 0;
                averaged_data[i] <= 0;
            end
        end else begin
            prev_valid_in <= s00_axis_tvalid;
            
            case (state)
                IDLE: begin
                    if (s00_axis_tvalid && ~prev_valid_in) begin
                        state <= COLLECTING;
                        sample_counter <= 0;
                        write_enable <= 1; // start writing to memory
                    end
                end
                
                COLLECTING: begin
                    if (s00_axis_tvalid) begin
                        // Start collecting 1000 samples per trigger
                        // Accumulate the current sample
                        accumulator[sample_counter] <= accumulator[sample_counter] + s00_axis_tdata;
                        sample_counter <= sample_counter + 1;
                        
                        if (sample_counter == SAMPLES_PER_TRIGGER-1) begin
                            trigger_counter <= trigger_counter + 1;
                            
                            if (trigger_counter == AVERAGES-1) begin
                                state <= AVERAGING;
                                write_enable <= 0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end
                end
                
                AVERAGING: begin
                    // Perform averaging for all samples
                    for (int i = 0; i < SAMPLES_PER_TRIGGER; i++) begin
                        averaged_data[i] <= accumulator[i] / AVERAGES;
                        accumulator[i] <= 0; // Reset accumulator at that index 
                    end
                    output_counter <= 0;
                    trigger_counter <= 0;
                    state <= OUTPUTTING;
                    m00_axis_tvalid <= 1;
                end
                
                OUTPUTTING: begin
                    if (m00_axis_tready) begin
                        m00_axis_tdata <= averaged_data[output_counter];
                        output_counter <= output_counter + 1;
                        
                        if (output_counter == SAMPLES_PER_TRIGGER-1) begin
                            m00_axis_tlast <= 1;
                            state <= IDLE;
                            m00_axis_tvalid <= 0;
                        end else begin
                            m00_axis_tlast <= 0;
                        end
                    end
                end
            endcase
        end
    end

    xilinx_true_dual_port_read_first_2_clock_ram #(
        .RAM_WIDTH(32),
        .RAM_DEPTH(1024)
    ) fifo_buffer (
        .addra(write_addr),
        .clka(s00_axis_aclk),
        .wea(write_enable),
        .dina(s00_axis_tdata),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(s00_axis_aresetn),
        .douta(),

        .addrb(read_addr),
        .dinb(),
        .clkb(m00_axis_aclk),
        .web(1'b0),
        .enb(1'b1),
        .regceb(1'b1),
        .rstb(m00_axis_aresetn),
        .doutb(holding_buffer)
    );

endmodule
