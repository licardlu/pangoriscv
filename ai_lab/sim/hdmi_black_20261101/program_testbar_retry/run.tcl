set fh [open {E:/file/pango/project/ai_lab/sim/hdmi_black_20261101/program_testbar_retry/trace.txt} w]
cfg_connect -ip 127.0.0.1 -port 65420
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
cfg_assign_file -file {C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/pangoriscv-verify/bitstreams/video1080p_testbar.sbit}
set result [cfg_program]
puts $fh "program: $result"
flush $fh
if {$result != 1} {error "Programming failed"}
puts $fh "after: [cfg_scan_chain]"
puts $fh "JTAG_SCRIPT_DONE"
flush $fh
close $fh
