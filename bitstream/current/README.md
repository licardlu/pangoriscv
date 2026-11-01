# 本轮021实验候选

board021_gshare10_route20；120.461538 MHz PPLL配置；最终setup +0.148ns、最小hold +0.028ns，十项检查全部为正。来源、固件与STA绑定见 provenance/SELECTED_IMPLEMENTATION.json。

未上板；未达到5.6；没有证明7000次长期提分；面积仍超旧预算282。只能作为新候选续验，不能标成已验证稳定版。原已板测014位流在 bitstream/board_verified，上版020在 bitstream/previous020。

生成日志保留SCBV默认未设置提示；本次沿用原JTAG/SRAM验证流程，没有宣称SPI Flash固化启动已验证。板外异步IO不属于本次核心时钟STA全覆盖保证。
