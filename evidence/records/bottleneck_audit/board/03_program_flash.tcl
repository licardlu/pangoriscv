# ------------------------------------------------------------------
# 03_program_flash.tcl —— 路线 B：把 .sfc 烧到板载 SPI Flash（掉电保留）
# 前置: 先运行 02_gen_sfc.tcl 生成 .sfc
# 用法: cdt_cfg.exe -file 03_program_flash.tcl -ip 127.0.0.1 -port <端口> -work_dir <本目录>
# ------------------------------------------------------------------
set ip   "127.0.0.1"
set port "51015"
set sfc  "E:/file/pango/project/09_validation_results/board_material_audit/_board/flash_kit/pango_native_top.sfc"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }
if {[info exists ::env(PANGO_SFC)]}      { set sfc  $::env(PANGO_SFC) }

puts "sfc = $sfc"
if {![file exists $sfc]} { puts "ERROR: 未找到 sfc，请先运行 02_gen_sfc.tcl；终止"; return }

if {[catch {cfg_connect -ip $ip -port $port} m]} { puts "connect: $m" } else { puts "connect OK" }
if {[catch {cfg_scan_chain} m]} { puts "scan_chain ERR: $m" } else { puts "scan_chain OK: $m" }

puts "===== cfg_jtag_flash_scan_device ====="
if {[catch {cfg_jtag_flash_scan_device} m]} { puts "flash_scan ERR: $m" } else { puts "flash_scan OK: $m" }

puts "===== cfg_jtag_flash_assign_file ====="
if {[catch {cfg_jtag_flash_assign_file -file $sfc} m]} { puts "flash_assign ERR: $m" } else { puts "flash_assign OK: $m" }

puts "===== cfg_jtag_flash_program (烧写 Flash，耗时较长) ====="
if {[catch {cfg_jtag_flash_program} m]} { puts "flash_program ERR: $m" } else { puts "flash_program OK: $m" }

puts "===== cfg_jtag_flash_verify ====="
if {[catch {cfg_jtag_flash_verify} m]} { puts "flash_verify ERR: $m" } else { puts "flash_verify OK: $m" }

puts "===== cfg_reset_fpga (让 FPGA 从 Flash 重新加载) ====="
if {[catch {cfg_reset_fpga} m]} { puts "reset ERR: $m" } else { puts "reset OK: $m" }

if {[catch {cfg_disconnect} m]} { puts "disconnect ERR: $m" } else { puts "disconnect OK" }
puts "PROGRAM_FLASH_DONE"
