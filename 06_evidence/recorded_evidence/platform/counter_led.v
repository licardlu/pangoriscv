`timescale 1ns/1ns

module counter_led
(
    input               clk,
    input               rst_n,
    output reg [7:0]    led
);

    parameter CNT_MAX = 26'd24_999_999;

    reg [25:0] cnt;

    always @(posedge clk) begin
        if (!rst_n)
            cnt <= 26'd0;
        else if (cnt == CNT_MAX)
            cnt <= 26'd0;
        else
            cnt <= cnt + 26'd1;
    end

    always @(posedge clk) begin
        if (!rst_n)
            led <= 8'b0000_0001;
        else if (cnt == CNT_MAX)
            led <= {led[6:0], led[7]};
    end

endmodule