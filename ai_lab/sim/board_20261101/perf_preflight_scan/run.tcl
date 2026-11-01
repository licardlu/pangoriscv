set fh [open {E:/file/pango/project/ai_lab/sim/board_20261101/perf_preflight_scan/trace.txt} w]
cfg_connect -ip 127.0.0.1 -port 65420
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
puts $fh "JTAG_SCRIPT_DONE"
flush $fh
close $fh
