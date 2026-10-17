# Program one .sbit into FPGA SRAM after resetting the device state.
# The kit's cfg_verify can abort ("Try to abort Verifying") and then every later
# command reports "Error has occurred, please run command clean" -- cfg_reset_fpga
# clears that device-side state without a power cycle.
# Usage:
#   cdt_cfg.exe -file 01c_program_reset.tcl -ip 127.0.0.1 -port <N> -work_dir <this dir>
# Environment: PANGO_SBIT (absolute path), PANGO_JTAG_PORT (optional override)
# ASCII only on purpose: cdt_cfg reads this file with the ANSI code page.

set ip   "127.0.0.1"
set port "51015"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }
if {![info exists ::env(PANGO_SBIT)]} {
    puts "ERROR: PANGO_SBIT is not set"
    return
}
set sbit $::env(PANGO_SBIT)

puts "sbit = $sbit"
if {![file exists $sbit]} { puts "ERROR: sbit file does not exist"; return }

if {[catch {cfg_connect -ip $ip -port $port} m]} { puts "connect ERR: $m" } else { puts "connect OK" }

puts "===== cfg_reset_fpga (clear stale device state) ====="
if {[catch {cfg_reset_fpga} m]} { puts "reset ERR: $m" } else { puts "reset OK: $m" }

puts "===== cfg_scan_chain ====="
if {[catch {cfg_scan_chain} m]} { puts "scan_chain ERR: $m" } else { puts "scan_chain OK: $m" }

puts "===== cfg_assign_file ====="
if {[catch {cfg_assign_file -file $sbit} m]} { puts "assign_file ERR: $m" } else { puts "assign_file OK: $m" }

puts "===== cfg_program (download to SRAM, no verify) ====="
if {[catch {cfg_program} m]} { puts "program ERR: $m" } else { puts "program OK: $m" }

puts "===== cfg_scan_chain (done bit after program) ====="
if {[catch {cfg_scan_chain} m]} { puts "scan2 ERR: $m" } else { puts "scan2 OK: $m" }

if {[catch {cfg_disconnect} m]} { puts "disconnect ERR: $m" } else { puts "disconnect OK" }
puts "PROGRAM_RESET_DONE"
