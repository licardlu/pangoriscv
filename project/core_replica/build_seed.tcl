# -----------------------------------------------------------------------------
# project/core_replica/build.tcl -- 新核 PDS 全流程 (解析 -> 综合 -> 映射 -> 布局布线 -> 位流)
#
# 用法 (在全新的空目录里启动 pds_shell):
#   export REPLICA_ROOT=/d/FPGA_Project/zi_guang_tong_chuang/pangoriscv
#   export REPLICA_FDC=pango_cpu_120.fdc          # 或 pango_cpu_50.fdc
#   export REPLICA_HEX=.../firmware.hex
#   cd build/<tag> && pds_shell -f $REPLICA_ROOT/project/core_replica/build.tcl
#
# 为什么必须在 build/<tag> 目录里启动:
#   RAM 用 $readmemh("firmware.hex") 做初始化。PDS 的相对路径以启动目录为准,
#   不在该目录放 firmware.hex 就会得到存储器全零的位流 (历史教训)。
# -----------------------------------------------------------------------------
if {![info exists ::env(REPLICA_ROOT)]} { error "REPLICA_ROOT is required" }
set root [file normalize $::env(REPLICA_ROOT)]

set run [pwd]
foreach stage {compile synthesize device_map place_route} {
  if {[file exists [file join $run $stage]]} { error "Use a fresh build directory" }
}

set fdc "pango_cpu_120.fdc"
if {[info exists ::env(REPLICA_FDC)]} { set fdc $::env(REPLICA_FDC) }

# ---------------------------- 源文件清单 -------------------------------------
set fh [open [file join $root rtl core core_sources.f] r]
set listing [read $fh]
close $fh

file mkdir [file join $run sources]

# 头文件必须与 .v 同目录: 各 .v 用 `include "core_defs.vh"`, 由编译器按相对路径解析
foreach h {core_config.vh core_defs.vh} {
  file copy -force [file join $root rtl core $h] [file join $run sources $h]
}

set nsrc 0
foreach line [split $listing "\n"] {
  set line [string trim $line]
  if {$line eq ""} { continue }
  if {[string index $line 0] eq "#"} { continue }
  if {[string index $line 0] eq "/" && [string index $line 1] eq "/"} { continue }
  set f [file join $root $line]
  if {![file exists $f]} { error "missing source: $f" }
  set staged [file join $run sources [file tail $f]]
  file copy -force $f $staged
  add_design $staged
  incr nsrc
}
puts "REPLICA_SOURCES $nsrc"

# ---------------------------- 频率变体 (可选) --------------------------------
# REPLICA_PLL 指向一个替换用的 pango_pll*.sv。以前换频要手工覆盖 rtl/pango_pll.sv,
# 很容易忘了改回来, 让"约束 90 MHz / 实际 PLL 120 MHz"这种错配混过去。
# 现在只覆盖本次 run 目录里那份暂存副本, rtl/ 一个字节都不动。
if {[info exists ::env(REPLICA_PLL)]} {
  set pll [file normalize $::env(REPLICA_PLL)]
  if {![file exists $pll]} { error "REPLICA_PLL not found: $pll" }
  file copy -force $pll [file join $run sources pango_pll.sv]
  puts "REPLICA_PLL [file tail $pll]"
}

# ---------------------------- 存储器初始化 -----------------------------------
if {[info exists ::env(REPLICA_HEX)]} {
  file copy -force $::env(REPLICA_HEX) [file join $run firmware.hex]
} elseif {[file exists [file join $root build replica_sim firmware.hex]]} {
  file copy -force [file join $root build replica_sim firmware.hex] [file join $run firmware.hex]
} else {
  error "firmware.hex not found; set REPLICA_HEX"
}

# ---------------------------- 器件与约束 -------------------------------------
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
add_constraint [file join $root project core_replica $fdc]

compile -top_module pango_cpu_top

# 检查 RAM 初始化确实被加载 (否则位流里没有程序)
set fh [open [file join $run compile run.log] r]
set log [read $fh]
close $fh
if {[regexp {Cannot open specified data} $log]} {
  error "firmware.hex failed to load into the RAM model"
}

synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint [file join $root project core_replica pango_cpu.pcf]
# ★ 与参考工程 build/board120/impl.tcl 逐字对齐 (只保留它用的那四个选项):
#   pnr -fix_hold_violation_iterations 50
#       -fix_hold_violation_threshold_for_clock_path_cross_srb 0
#       -fix_hold_violation_threshold_for_clk_tree 0
#   以前这里多加过 -fix_hold_violation_threshold 0 与 -fix_hold_violation_in_route TRUE,
#   那两条参考没有。既然要求"完全仿照", 就把差异清零, 这样两边的频率才可比。
# 试验用: 换一个摆放随机种子 (build.tcl 里不写死, 只在这个变体里加)
set gs 2
if {[info exists ::env(REPLICA_GPLACE_SEED)]} { set gs $::env(REPLICA_GPLACE_SEED) }
puts "REPLICA_GPLACE_SEED $gs"
pnr -fix_hold_violation_iterations 50 \
    -fix_hold_violation_threshold_for_clock_path_cross_srb 0 \
    -fix_hold_violation_threshold_for_clk_tree 0 \
    -gplace_seed $gs
report_timing
gen_bit_stream
puts "BUILD_FLOW_COMPLETE"
