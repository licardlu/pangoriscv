set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/optimization/trash-speed-20261111-status-001/trace.txt} w]
set failed [catch {
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
set status [cfg_read_device_property -mode 3]
puts $fh "status: $status"
flush $fh
} detail]
set release_failed [catch {cfg_disconnect} release_detail]
puts $fh "disconnect: $release_detail"
if {$release_failed || $release_detail != 1} {set failed 1; append detail "; JTAG disconnect failed: $release_detail"}
if {$failed} {puts $fh "JTAG_SCRIPT_FAILED: $detail"} else {puts $fh "JTAG_SCRIPT_DONE"}
flush $fh
close $fh
