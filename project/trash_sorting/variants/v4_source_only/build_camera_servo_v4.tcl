# ---------------------------------------------------------------------------
# v4 变体构建脚本（仅源码，无可用位流）
#
# 这个脚本**没有在交付包里被验证过能跑完**：v4 那次构建停在许可证检查
# （见同目录 pds_camera_servo_v4.log，fabric_shell 日期已过期）。留着是为了
# 记录 v4 相对 v3 改了哪两个文件、以及 P&R 参数怎么设的。
#
# 原工程里它的工作目录是 .../yolo/build_camera_servo_v4_full_20261103/，
# 所以脚本里用了 [pwd] 和 ../../extensions 这类相对路径。搬到 variants/ 之后
# 这两条都会失效，下面加了自动兜底：找不到就回落到 source/yolo 下的运行目录。
# ---------------------------------------------------------------------------
set here [file dirname [file normalize [info script]]]
if {[info exists ::env(TRASH_YOLO_ROOT)]} {
    set pkg_dir [file normalize $::env(TRASH_YOLO_ROOT)]
} elseif {[file isdirectory [file join $here sources]]} {
    set pkg_dir $here
} else {
    # variants/v4_source_only/ -> ../../source/yolo
    set pkg_dir [file normalize [file join $here .. .. source yolo]]
}
if {![file isdirectory [file join $pkg_dir sources]]} {
    error "Cannot locate the yolo source tree. Set TRASH_YOLO_ROOT to <package>/project/trash_sorting/source/yolo"
}

# trash_voice_rom_player.v 用 "../../extensions/..." 找语音 ROM，只有工作目录
# 在 yolo/<子目录> 时才成立。不成立就切到一个专用的运行目录。
if {![file isdirectory [file normalize [file join [pwd] .. .. extensions business application]]]} {
    set run_dir [file join $pkg_dir build_v4_run]
    file mkdir $run_dir
    cd $run_dir
}

set src_dir [file join $pkg_dir sources]
set business_dir [file normalize [file join $pkg_dir .. extensions business application]]

# Memory initialization paths are resolved from the implementation directory.
# Stage all eight firmware lanes before compile, and fail on missing input.
for {set lane 0} {$lane < 8} {incr lane} {
    set image [file join $src_dir firmware_lane${lane}.bin]
    if {![file exists $image]} {error "Missing firmware lane: $image"}
    file copy -force $image [file join [pwd] firmware_lane${lane}.bin]
}

add_design [file join $src_dir 000_Decoder_2.v]
add_design [file join $src_dir 001_WidthAdapter_1.v]
add_design [file join $src_dir 002_PeripheralDemo.v]
add_design [file join $src_dir 003_TilelinkUartCtrl.v]
add_design [file join $src_dir 004_TilelinkPlic.v]
add_design [file join $src_dir 005_Decoder_1.v]
add_design [file join $src_dir 006_Decoder.v]
add_design [file join $src_dir 007_TilelinkClint.v]
add_design [file join $src_dir 008_WidthAdapter.v]
add_design [file join $pkg_dir portable 009_Ram.v]
add_design [file join $src_dir 010_Arbiter.v]
add_design [file join $src_dir 011_BufferCC_5.v]
add_design [file join $src_dir 012_BufferCC_4.v]
add_design [file join $src_dir 013_BufferCC_3.v]
add_design [file join $src_dir 014_BufferCC_2.v]
add_design [file join $src_dir 015_pango_replica_core.v]
add_design [file join $src_dir 016_StreamArbiter_6.v]
add_design [file join $src_dir 017_BufferCC_1.v]
add_design [file join $src_dir 018_StreamFifo_1.v]
add_design [file join $src_dir 019_UartCtrl.v]
add_design [file join $src_dir 020_StreamArbiter_5.v]
add_design [file join $src_dir 021_StreamArbiter_4.v]
add_design [file join $src_dir 022_ContextAsyncBufferFull.v]
add_design [file join $src_dir 023_StreamArbiter_3.v]
add_design [file join $src_dir 024_RegFileMem.v]
add_design [file join $src_dir 025_StreamArbiter_2.v]
add_design [file join $src_dir 026_StreamArbiter_1.v]
add_design [file join $src_dir 027_StreamArbiter.v]
add_design [file join $src_dir 028_DivRadix.v]
add_design [file join $src_dir 029_StreamFifo.v]
add_design [file join $src_dir 030_UartCtrlRx.v]
add_design [file join $src_dir 031_UartCtrlTx.v]
add_design [file join $src_dir 032_RamSyncMwMux.v]
add_design [file join $src_dir 033_BufferCC.v]
add_design [file join $src_dir 034_RamAsyncMwReg.v]
add_design [file join $src_dir 035_replica_early0_shifter.v]
add_design [file join $src_dir 036_replica_late0_shifter.v]
add_design [file join $src_dir 037_replica_early1_shifter.v]
add_design [file join $src_dir 038_replica_late1_shifter.v]
add_design [file join $src_dir 039_branch_eq_pipeline.v]
add_design [file join $src_dir 040_vexii_ai_soc.v]
add_design [file join $src_dir 041_tlul_to_axil.v]
add_design [file join $src_dir 042_conv_band_rt.v]
add_design [file join $src_dir 043_mac_array.v]
add_design [file join $src_dir 044_conv_engine_axil.v]
add_design [file join $src_dir 045_ddr_axi_bridge.v]
add_design [file join $src_dir 046_bridge_to_cdc.v]
add_design [file join $src_dir 047_axi_cdc.v]
add_design [file join $src_dir 048_camera_snapshot.v]
add_design [file join [pwd] 049_video_ai_frontend_camera_repair.v]
add_design [file join $src_dir 050_ddr_native_arbiter.v]
add_design [file join $src_dir 051_yolo_ai_client.v]
add_design [file join [file dirname [file normalize [info script]]] 052_yolo_camera_top_camera_servo.v]
add_design [file join $business_dir rtl bcd32.sv]
add_design [file join $business_dir rtl ui_light_panel.sv]
add_design [file join $business_dir rtl light_split_video.sv]
add_design [file join $business_dir rtl servo_pwm4.sv]
add_design [file join $business_dir rtl key_debounce4.sv]
add_design [file join $business_dir rtl servo_key_controller.sv]
add_design [file join $business_dir rtl trash_quiz_controller.sv]
add_design [file join $business_dir rtl trash_peripherals.sv]
add_design [file join $business_dir rtl snapshot_cdc.sv]
add_design [file join $business_dir rtl yolo_class_to_bin.v]
add_design [file join $business_dir rtl trash_voice_rom_player.v]
add_design [file join $business_dir rtl trash_i2s_tx.v]
add_design [file join $business_dir rtl trash_voice_i2s.v]
add_design [file join $business_dir rtl ms7210_audio_init.v]
add_design [file join $src_dir 053_cam_diag.v]
add_design [file join $src_dir 054_cmos_8_16bit.v]
add_design [file join $src_dir 055_fram_buf.v]
add_design [file join $src_dir 056_i2c_com.v]
add_design [file join $src_dir 057_iic_dri.v]
add_design [file join $src_dir 058_ms7200_ctl.v]
add_design [file join $src_dir 059_ms7210_ctl.v]
add_design [file join $src_dir 060_ms72xx_ctl.v]
add_design [file join $src_dir 061_power_on_delay.v]
add_design [file join $src_dir 062_rd_buf.v]
add_design [file join $src_dir 063_rd_ctrl.v]
add_design [file join $src_dir 064_reg_config.v]
add_design [file join $src_dir 065_sync_vg.v]
add_design [file join $src_dir 066_uart_cam_report.v]
add_design [file join $src_dir 067_wr_buf.v]
add_design [file join $src_dir 068_wr_cmd_trans.v]
add_design [file join $src_dir 069_wr_ctrl.v]
add_design [file join $src_dir 070_wr_rd_ctrl_top.v]
add_design [file join $pkg_dir ipcore ddr3_test ddr3_test.idf]
add_design [file join $pkg_dir ipcore pll pll.idf]
add_design [file join $pkg_dir ipcore rd_fram_buf rd_fram_buf.idf]
add_design [file join $pkg_dir ipcore wr_fram_buf wr_fram_buf.idf]
add_constraint [file join $src_dir camera.fdc]
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module yolo_camera_top -system_verilog -include_path [list [file join $src_dir include] [file join $business_dir rtl]]
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr -plc_decongestion 2 -share_router_control_signal TRUE -gplace_seed 2 -groute_seed 2 -fix_hold_violation_iterations 50 -fix_hold_violation_threshold_for_clock_path_cross_srb 0 -fix_hold_violation_threshold_for_clk_tree 0
report_timing
gen_bit_stream
puts "CAMERA_SERVO_V3_BITSTREAM_COMPLETE"

