add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/region-probe-004/top.v}
add_constraint {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/region-probe-004/pins.fdc}
add_constraint {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/region-probe-004/region.pcf}
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module probe
synthesize -ads -selected_syn_tool_opt 2
dev_map
set f [open {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/region-probe-004/region.pcf} a]
puts $f {def_region test_region 20 80 20 100}
puts $f {def_inst_region {count[0]/opit_0_inv} test_region}
close $f
pnr -place_only
puts "PROBE_COMPLETE"
