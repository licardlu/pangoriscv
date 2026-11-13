set fh [open "D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/scan.txt" w]
if {[catch {cfg_scan_chain} m]} {puts $fh "scan ERR: $m"} else {puts $fh "scan OK: $m"}
if {[catch {cfg_read_device_property -mode 0} m]} {puts $fh "id ERR: $m"} else {puts $fh "id OK: $m"}
puts $fh "DONE"
close $fh
