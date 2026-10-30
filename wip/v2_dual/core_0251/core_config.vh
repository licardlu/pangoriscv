`ifndef CORE_CONFIG_VH
`define CORE_CONFIG_VH

// ---------------------------- 基本机器参数 -----------------------------------
`define CFG_XLEN                 32
`define CFG_RESET_VECTOR         32'h8000_0000
`define CFG_RAM_BYTES            65536        // --ram-bytes=65536
`define CFG_RAM_BASE             32'h8000_0000
`define CFG_ISA                  "RV32IMC_Zicsr_Zifencei"

// ---------------------------- 取指 / 译码 ------------------------------------
// --dual-issue 把 decoders/lanes 都设为 2；--max-ipc 在 lanes>1 时再打开
// aligner/dispatcher buffer。V1 只启用车通道 0，但结构保留 2 份译码位置。
`define CFG_DECODERS             2
`define CFG_LANES                2
`define CFG_ACTIVE_LANES         1            // V1 集成交付值; V2 起改 2
`define CFG_IF_WIDTH             32           // V1: 32b 取指字 (参考为 64b/2 lane)
`define CFG_WITH_RVC             1
`define CFG_WITH_ALIGNER_BUF     1            // --max-ipc + lanes>1

// ---------------------------- 寄存器堆 ---------------------------------------
// Param.scala: regFileSync 默认 true, allowBypassFrom=0 (--max-ipc / --with-late-alu)
// => 同步读 + 全前递。
`define CFG_REGFILE_SYNC         1
`define CFG_REGFILE_BYPASS       1
`define CFG_MUL_LATENCY          2            // 输入寄存 1 拍 + 结果 1 拍
`define CFG_DIV_RADIX            2            // 参考 --max-ipc 设 divRadix=4; V1=2 (差异已登记)

// ---------------------------- 分支预测 ---------------------------------------
// V1 不启用 (P10 才接入), 参数在此冻结容量, 供 V2 直接展开。
`define CFG_BTB_SETS             256          // --with-btb: 256x51 x2 组
`define CFG_BTB_CHUNKS           2
`define CFG_BTB_ENTRY_BITS       51
`define CFG_RAS_DEPTH            4            // --with-ras
`define CFG_GSHARE_BYTES         4096         // --with-gshare: 4096x8
`define CFG_GSHARE_HISTORY       12           // Param.scala historyWidth=12
`define CFG_GSHARE_BANKS         1
`define CFG_V1_BPREDICT          0            // V1 关闭, 静态顺序取指

// ---------------------------- Cache (V3 才接入) -------------------------------
// 参考: --with-fetch-l1 --fetch-l1-sets=128 --fetch-l1-ways=2
//       --fetch-l1-refill-count=8 --fetch-l1-mem-data-width-min=64
`define CFG_ICACHE_SETS          128
`define CFG_ICACHE_WAYS          2
`define CFG_ICACHE_LINE_BYTES    64
`define CFG_ICACHE_REFILL        8
// 参考: --with-lsu-l1 --lsu-l1-sets=64 --lsu-l1-ways=2
//       注意 --max-ipc 先设 ways=4, 被后面的 --lsu-l1-ways=2 覆盖回 2。
`define CFG_DCACHE_SETS          64
`define CFG_DCACHE_WAYS          2
`define CFG_DCACHE_LINE_BYTES    64
`define CFG_DCACHE_REFILL        8
`define CFG_DCACHE_WRITEBACK     8
`define CFG_STORE_BUF_SLOTS      4            // --max-ipc
`define CFG_STORE_BUF_OPS        32
`define CFG_RPT_ENTRIES          128
`define CFG_V1_CACHES            0            // V1 直连 RAM, 无 Cache

// ---------------------------- 外设地址映射 -----------------------------------
// 与参考 MicroSoc.scala 一致: uart at 0x10001000, demo(gpio) at 0x10003000
`define CFG_UART_BASE            32'h1000_1000
`define CFG_GPIO_BASE            32'h1000_3000
`define CFG_CLINT_BASE           32'h1000_0000     // 待核实: 参考由 TilelinkClint 提供
`define CFG_UART_CLKDIV          4'd8              // 120.46MHz/(131*8)≈114944 见固件

// ---------------------------- 结构常量 ---------------------------------------
`define CFG_PC_WIDTH             32
`define CFG_ADDR_WIDTH           32
`define CFG_MEM_WORDS            (`CFG_RAM_BYTES/4)

`endif // CORE_CONFIG_VH
