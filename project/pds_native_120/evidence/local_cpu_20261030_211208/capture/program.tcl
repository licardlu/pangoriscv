set sbit {E:/file/pango/project/project/pds_native_120/build/standalone-001/generate_bitstream/pango_vexii_top.sbit}
set fh [open {E:/file/pango/project/project/pds_native_120/evidence/local_cpu_20261030_211208/capture/program_trace.txt} w]
puts $fh "sbit = $sbit"
puts $fh "exists = [file exists $sbit]"
flush $fh
if {[catch {cfg_scan_chain} m]} {puts $fh "scan ERR: $m"} else {puts $fh "scan OK: $m"}
flush $fh
if {[catch {cfg_assign_file -file $sbit} m]} {puts $fh "assign ERR: $m"} else {puts $fh "assign OK: $m"}
flush $fh
if {[catch {cfg_program} m]} {puts $fh "program ERR: $m"} else {puts $fh "program OK: $m"}
flush $fh
if {[catch {cfg_scan_chain} m]} {puts $fh "scan2 ERR: $m"} else {puts $fh "scan2 OK: $m"}
if {[catch {cfg_read_device_property -mode 0} m]} {puts $fh "id ERR: $m"} else {puts $fh "id OK: $m"}
puts $fh "PROGRAM_DONE"
close $fh