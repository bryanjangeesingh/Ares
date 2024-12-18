module trigger(input wire clk_in, 
                input wire rstn, 
                output wire trigger);

    reg [19:0] counter;
    assign trigger = (counter == 409600);
    
    always @(posedge clk_in) begin
        if (~rstn) begin
            counter <= 0;
        end else if (counter == 409600) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule