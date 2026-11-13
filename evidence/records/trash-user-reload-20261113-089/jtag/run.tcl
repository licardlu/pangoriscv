set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/trash-user-reload-20261113-089/jtag/trace.txt} w]
set failed [catch {
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
cfg_assign_file -file {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/trash_sorting/bitstream/full_54mhz_20261113/yolo_camera_top.sbit}
set result [cfg_program]
puts $fh "program: $result"
flush $fh
if {$result != 1} {error "Programming failed"}
puts $fh "after: [cfg_scan_chain]"
set status [cfg_read_device_property -mode 3]
puts $fh "status: $status"
flush $fh
if {[scan $status %x status_value] != 1 || ($status_value & 0x0007d000) != 0x0007d000 || ($status_value & 0x00000007) != 0} {error "FPGA configuration is not active or has configuration errors"}
after 5000
set status [cfg_read_device_property -mode 3]
puts $fh "status_after_5s: $status"
flush $fh
if {[scan $status %x status_value] != 1 || ($status_value & 0x0007d000) != 0x0007d000 || ($status_value & 0x00000007) != 0} {error "FPGA configuration did not remain active"}
} detail]
set release_failed [catch {cfg_disconnect} release_detail]
puts $fh "disconnect: $release_detail"
if {$release_failed || $release_detail != 1} {set failed 1; append detail "; JTAG disconnect failed: $release_detail"}
if {$failed} {puts $fh "JTAG_SCRIPT_FAILED: $detail"} else {puts $fh "JTAG_SCRIPT_DONE"}
flush $fh
close $fh
