set fh [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/evidence/records/validation_20261104/coremark_program_2/trace.txt} w]
cfg_connect -ip 127.0.0.1 -port 65420
puts $fh "scan: [cfg_scan_chain]"
flush $fh
set id [cfg_read_device_property -mode 0]
puts $fh "id: $id"
flush $fh
if {![string equal -nocase [string trim $id] "0x00602899"] && ![string equal -nocase [string trim $id] "00602899"]} {error "Unexpected device ID"}
cfg_assign_file -file {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/pds_native_120/bitstream/current/pango_replica_core_120.sbit}
set result [cfg_program]
puts $fh "program: $result"
flush $fh
if {$result != 1} {error "Programming failed"}
puts $fh "after: [cfg_scan_chain]"
puts $fh "JTAG_SCRIPT_DONE"
flush $fh
close $fh
