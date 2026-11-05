# Single-step P&R from a frozen mapped ADF. No RTL, compile or synthesize commands.
set_arch -input_db_file {D:/FPGA_Project/trash_white_split_voice_source_v1/yolo/build_camera_servo_v3_seed3_20261103/mapped_input/yolo_camera_top_map.adf}
add_constraint {D:/FPGA_Project/trash_white_split_voice_source_v1/yolo/build_camera_servo_v3_seed3_20261103/mapped_input/yolo_camera_top.pcf}
puts "DIRECT_MAPPED_PNR_START"
pnr -input_db_file {D:/FPGA_Project/trash_white_split_voice_source_v1/yolo/build_camera_servo_v3_seed3_20261103/mapped_input/yolo_camera_top_map.adf} -plc_decongestion 3 -share_router_control_signal TRUE -gplace_seed 3 -groute_seed 2 -fix_hold_violation_iterations 50 -fix_hold_violation_threshold_for_clock_path_cross_srb 0 -fix_hold_violation_threshold_for_clk_tree 0
puts "DIRECT_MAPPED_PNR_COMPLETE"
