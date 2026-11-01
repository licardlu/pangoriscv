module pango_cpu_top(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [7:0] led
);
    wire core_clk, locked, reset;

    pango_pll u_core_pll (
        .clk      (clk),
        .rst_n    (rst_n),
        .core_clk (core_clk),
        .locked   (locked)
    );

    pango_reset u_reset (
        .clk    (core_clk),
        .rst_n  (rst_n),
        .locked (locked),
        .reset  (reset)
    );

    pango_soc u_soc (
        .clk     (core_clk),
        .rst     (reset),
        .uart_tx (uart_tx),
        .uart_rx (uart_rx),
        .led     (led),
        .btn     (!key)
    );
endmodule
