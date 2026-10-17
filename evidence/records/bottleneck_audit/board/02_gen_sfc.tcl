# ------------------------------------------------------------------
# 02_gen_sfc.tcl —— 纯文件转换：.sbit -> .sfc（用于烧板载 SPI Flash）
# 用法: cdt_cfg.exe -file 02_gen_sfc.tcl -work_dir <本目录>
# 本脚本不访问下载电缆，可在任何机器上安全执行。
# ------------------------------------------------------------------
set sbit "E:/file/pango/project/01_code/tinyriscv_axi4/build/pango_native/generate_bitstream/pango_native_top.sbit"
set sfc  "E:/file/pango/project/09_validation_results/board_material_audit/_board/flash_kit/pango_native_top.sfc"
if {[info exists ::env(PANGO_SBIT)]} { set sbit $::env(PANGO_SBIT) }
if {[info exists ::env(PANGO_SFC)]}  { set sfc  $::env(PANGO_SFC) }

puts "sbit = $sbit"
puts "sfc  = $sfc"
if {![file exists $sbit]} { puts "ERROR: sbit 文件不存在，终止"; return }

# -device_name 默认 N25Q256（板载 Flash 型号；若实际型号不同请改这里）
puts "===== cfg_gen_sfc ====="
if {[catch {cfg_gen_sfc -sbit $sbit -sfc $sfc} m]} { puts "gen_sfc ERR: $m" } else { puts "gen_sfc OK: $m" }

if {[file exists $sfc]} { puts "生成成功: $sfc  ($::tcl_platform(platform))" } else { puts "警告: 未找到生成的 sfc 文件" }
puts "GEN_SFC_DONE"
