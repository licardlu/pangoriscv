set fh [open scan.txt w]
cfg_connect -ip 127.0.0.1 -port 65420
puts $fh "scan: [cfg_scan_chain]"
puts $fh "id: [cfg_read_device_property -mode 0]"
flush $fh
close $fh
exit
