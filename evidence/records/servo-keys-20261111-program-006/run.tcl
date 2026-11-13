set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/servo-keys-20261111-program-006/trace.txt} w]
puts $fh "scan: [cfg_scan_chain]"
puts $fh "before: [cfg_read_device_property -mode 3]"
flush $fh
puts $fh "assign: [cfg_assign_file -file {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/build/servo_keys_20261111_003/generate_bitstream/servo_key_test_top.sbit}]"
flush $fh
puts $fh "program: [cfg_program]"
flush $fh
puts $fh "after: [cfg_read_device_property -mode 3]"
flush $fh
after 5000
puts $fh "after5s: [cfg_read_device_property -mode 3]"
flush $fh
puts $fh "disconnect: [cfg_disconnect]"
puts $fh DONE
close $fh
