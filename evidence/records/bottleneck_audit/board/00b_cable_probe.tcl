# Read-only cable/driver probe. Nothing is written to the board.
set ip "127.0.0.1"
set port "51015"
if {[info exists ::env(PANGO_JTAG_PORT)]} { set port $::env(PANGO_JTAG_PORT) }
foreach c {cfg_connect} {
  if {[catch {$c -ip $ip -port $port} m]} { puts "$c ERR: $m" } else { puts "$c OK: $m" }
}
foreach c {cfg_list_cable cfg_get_cable cfg_cable_info cfg_list_device cfg_scan_chain} {
  if {[catch {$c} m]} { puts "$c ERR: $m" } else { puts "$c OK: $m" }
}
puts "PROBE_DONE"
