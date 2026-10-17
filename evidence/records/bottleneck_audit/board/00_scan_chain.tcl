# Read-only: connect to the JtagServer and scan the JTAG chain.
# Usage: cdt_cfg.exe -file 00_scan_chain.tcl -ip 127.0.0.1 -port <N> -work_dir <this dir>
# Nothing on the board is written by this script.
# ASCII only on purpose: cdt_cfg reads this file with the ANSI code page.

set ip "127.0.0.1"
set port "51015"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }

puts "===== cfg_connect $ip : $port ====="
if {[catch {cfg_connect -ip $ip -port $port} m]} { puts "connect ERR: $m" } else { puts "connect OK" }

puts "===== cfg_scan_chain ====="
if {[catch {cfg_scan_chain} m]} { puts "scan_chain ERR: $m" } else { puts "scan_chain OK: $m" }

puts "===== cfg_read_device_property -mode 0 (Device ID) ====="
if {[catch {cfg_read_device_property -mode 0} m]} { puts "device_id ERR: $m" } else { puts "device_id OK: $m" }

puts "===== cfg_disconnect ====="
if {[catch {cfg_disconnect} m]} { puts "disconnect ERR: $m" } else { puts "disconnect OK" }
puts "SCAN_CHAIN_DONE"
