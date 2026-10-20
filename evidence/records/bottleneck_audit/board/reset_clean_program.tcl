set ip "127.0.0.1"
set port "51015"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }
set sbit $::env(PANGO_SBIT)
if {[catch {cfg_connect -ip $ip -port $port} m]} { puts "connect ERR: $m" } else { puts "connect OK" }
if {[catch {cfg_clean} m]} { puts "cfg_clean ERR: $m" } else { puts "cfg_clean OK" }
if {[catch {clean} m]} { puts "clean ERR: $m" } else { puts "clean OK" }
if {[catch {cfg_reset_fpga} m]} { puts "reset ERR: $m" } else { puts "reset OK" }
if {[catch {cfg_scan_chain} m]} { puts "scan ERR: $m" } else { puts "scan OK" }
cfg_assign_file -file $sbit
cfg_program
cfg_disconnect
puts "CLEAN_RESET_PROGRAM_DONE"
