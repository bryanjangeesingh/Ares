module trigger

    (input wire clk_in, # 150 MHz
    input wire rst_in,
    output logic trigger);

    logic [19:0] counter;

    assign trigger = (counter == 149999)
    always_ff @(posedge clk_in) begin
        if(~rst_in) begin
            counter <= 0;
        end else if (counter == 149999) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end

    end

endmodule