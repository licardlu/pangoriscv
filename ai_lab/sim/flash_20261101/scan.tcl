cfg_connect -ip 127.0.0.1 -port 65420
puts "SCAN: [cfg_scan_chain]"
puts "ID: [cfg_read_device_property -mode 0]"
flush stdout
exit
