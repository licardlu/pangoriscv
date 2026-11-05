add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/sources/057_iic_dri.v}
add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/sources/059_ms7210_ctl.v}
add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/sources/065_sync_vg.v}
add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/sources/hdmi_startup_top.v}
add_design {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/ipcore/pll/pll.idf}
add_constraint {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/hdmi.fdc}
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module hdmi_startup_top -include_path {D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/yolo120/build/hdmi-vic4-001/sources}
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr -fix_hold_violation_iterations 100 -fix_hold_violation_in_route TRUE -gplace_seed 2 -groute_seed 2
report_timing
gen_bit_stream
puts "HDMI_DIAG_FLOW_COMPLETE"
