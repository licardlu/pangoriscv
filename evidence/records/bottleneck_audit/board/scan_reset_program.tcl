set ip "127.0.0.1"
set port "51015"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }
set sbit $::env(PANGO_SBIT)
if {[catch {cfg_connect -ip $ip -port $port} m]} { puts "connect ERR: $m" } else { puts "connect OK" }
if {[catch {cfg_scan_chain} m]} { puts "scan1 ERR: $m" } else { puts "scan1 OK" }
if {[catch {cfg_reset_fpga} m]} { puts "reset ERR: $m" } else { puts "reset OK" }
if {[catch {cfg_scan_chain} m]} { puts "scan2 ERR: $m" } else { puts "scan2 OK" }
cfg_assign_file -file $sbit
cfg_program
cfg_disconnect
puts "SCAN_RESET_PROGRAM_DONE"
