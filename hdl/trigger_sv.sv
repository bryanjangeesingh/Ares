module trigger_sv(
    input wire clk_in, //150 MHz
    input wire rstn,
    output logic trigger);

    logic [19:0] counter;

    assign trigger = (counter == 99999);
    
    always_ff @(posedge clk_in) begin
        if(~rstn) begin
            counter <= 0;
        end else if (counter == 99999) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end

    end

endmodule