set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/servo-keys-20261111-status-004/trace.txt} w]
puts $fh [info commands cfg*]
puts $fh {HELP cfg_help}
catch {cfg_help -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_read_register}
catch {cfg_read_register -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_read_device_property}
catch {cfg_read_device_property -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_verify}
catch {cfg_verify -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_readback}
catch {cfg_readback -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_debug_operate}
catch {cfg_debug_operate -help} r
puts $fh $r
flush $fh
puts $fh {HELP cfg_set_options}
catch {cfg_set_options -help} r
puts $fh $r
flush $fh
puts $fh DONE
close $fh
