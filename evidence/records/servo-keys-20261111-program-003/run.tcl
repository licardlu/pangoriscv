set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/servo-keys-20261111-program-003/trace.txt} w]
cfg_connect -ip 127.0.0.1 -port 65420
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
cfg_assign_file -file {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/build/servo_keys_20261111_003/generate_bitstream/servo_key_test_top.sbit}
set result [cfg_program]
puts $fh "program: $result"
flush $fh
if {$result != 1} {error "Programming failed"}
puts $fh "after: [cfg_scan_chain]"
puts $fh "JTAG_SCRIPT_DONE"
flush $fh
close $fh
