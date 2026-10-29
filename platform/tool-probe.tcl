add_design [file normalize [file join [file dirname [info script]] .. tb tool_probe.v]]
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
if {[catch {compile -top_module tool_probe} msg]} {
  puts "TOOL_PROBE_FAILED: $msg"
  puts $::errorInfo
  exit 1
}
puts TOOL_PROBE_PASS
