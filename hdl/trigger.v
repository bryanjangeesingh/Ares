module trigger(input wire clk_in, input wire rst_in, output wire trigger);

    trigger_sv trigger_inst(
        .clk_in(clk_in),
        .rstn(rstn),
        .trigger(trigger)
    );
endmodule