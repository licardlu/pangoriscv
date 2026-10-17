# Program one .sbit into the FPGA SRAM, WITHOUT the read-back verify step.
# The delivered kit's cfg_verify needs a full read-back and can abort on long
# cable / high TCK; the program step itself already reported 100%.
# Usage:
#   cdt_cfg.exe -file 01b_program_only.tcl -ip 127.0.0.1 -port <N> -work_dir <this dir>
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
# A previous aborted verify leaves the server in an error state; clean first.
if {[catch {cfg_clean} m]} { puts "clean ERR: $m" } else { puts "clean OK: $m" }
if {[catch {cfg_scan_chain} m]} { puts "scan_chain ERR: $m" } else { puts "scan_chain OK: $m" }

puts "===== cfg_assign_file ====="
if {[catch {cfg_assign_file -file $sbit} m]} { puts "assign_file ERR: $m" } else { puts "assign_file OK: $m" }

puts "===== cfg_program (download to SRAM, no verify) ====="
if {[catch {cfg_program} m]} { puts "program ERR: $m" } else { puts "program OK: $m" }

puts "===== cfg_scan_chain (done bit after program) ====="
if {[catch {cfg_scan_chain} m]} { puts "scan2 ERR: $m" } else { puts "scan2 OK: $m" }
if {[catch {cfg_read_device_property -mode 0} m]} { puts "id ERR: $m" } else { puts "id OK: $m" }

if {[catch {cfg_disconnect} m]} { puts "disconnect ERR: $m" } else { puts "disconnect OK" }
puts "PROGRAM_ONLY_DONE"
