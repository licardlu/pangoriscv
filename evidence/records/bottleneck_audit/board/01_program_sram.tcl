# Program one .sbit into the FPGA SRAM (volatile: lost on power-off).
# Usage:
#   cdt_cfg.exe -file 01_program_sram.tcl -ip 127.0.0.1 -port <N> -work_dir <this dir>
# Environment:
#   PANGO_SBIT       absolute path of the bitstream (forward slashes recommended)
#   PANGO_JTAG_PORT  overrides the port set by the caller
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
if {[catch {cfg_scan_chain} m]} { puts "scan_chain ERR: $m" } else { puts "scan_chain OK: $m" }

puts "===== cfg_assign_file ====="
if {[catch {cfg_assign_file -file $sbit} m]} { puts "assign_file ERR: $m" } else { puts "assign_file OK: $m" }

puts "===== cfg_program (download to SRAM) ====="
if {[catch {cfg_program} m]} { puts "program ERR: $m" } else { puts "program OK: $m" }

puts "===== cfg_verify ====="
if {[catch {cfg_verify} m]} { puts "verify ERR: $m" } else { puts "verify OK: $m" }

if {[catch {cfg_disconnect} m]} { puts "disconnect ERR: $m" } else { puts "disconnect OK" }
puts "PROGRAM_SRAM_DONE"
