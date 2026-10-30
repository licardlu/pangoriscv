// -----------------------------------------------------------------------------
// pango_cpu_top.sv -- 板级顶层 (MES2L676-100HP / PG2L100H-6IFBG676)
//
// 与参考顶层 pango_vexii_top.sv 保持同样的端口与时钟方案:
//   27 MHz 晶振 -> GTP_PPLL -> core_clk -> 复位同步 -> SoC
// 差别只在被例化的 SoC: 这里是 rtl/soc/pango_soc.v (新核), 不是 MicroSoc.v。
// -----------------------------------------------------------------------------
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
