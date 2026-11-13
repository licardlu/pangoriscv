set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/servo-keys-20261111-status-005/trace.txt} w]
puts $fh "scan: [cfg_scan_chain]"
puts $fh {status}
flush $fh
catch {cfg_read_device_property -mode 3} r
puts $fh $r
flush $fh
puts $fh {usercode}
flush $fh
catch {cfg_read_device_property -mode 2} r
puts $fh $r
flush $fh
puts $fh {verify}
flush $fh
catch {cfg_assign_file -file {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/build/servo_keys_20261111_003/generate_bitstream/servo_key_test_top.sbit}} r
puts $fh $r
flush $fh
puts $fh {verify_result}
flush $fh
catch {cfg_verify} r
puts $fh $r
flush $fh
puts $fh {pins}
flush $fh
catch {cfg_debug_operate -mode 5} r
puts $fh $r
flush $fh
puts $fh DONE
close $fh
