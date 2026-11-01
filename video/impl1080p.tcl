# 1080p60 video pipeline build script (Pango PDS 2022.2)
set RTL  "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/source/rtl"

add_design "$RTL/hdmi_ddr_ov5640_top.v"
add_design "$RTL/cam_diag.v"
add_design "$RTL/uart_cam_report.v"
add_design "$RTL/cmos_8_16bit.v"
add_design "$RTL/fram_buf.v"
add_design "$RTL/i2c_com.v"
add_design "$RTL/iic_dri.v"
add_design "$RTL/ms72xx_ctl.v"
add_design "$RTL/ms7200_ctl.v"
add_design "$RTL/ms7210_ctl.v"
add_design "$RTL/power_on_delay.v"
add_design "$RTL/rd_buf.v"
add_design "$RTL/rd_ctrl.v"
add_design "$RTL/reg_config.v"
add_design "$RTL/sync_vg.v"
add_design "$RTL/wr_buf.v"
add_design "$RTL/wr_cmd_trans.v"
add_design "$RTL/wr_ctrl.v"
add_design "$RTL/wr_rd_ctrl_top.v"

add_design "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/ipcore/pll/pll.idf"
add_design "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/ipcore/rd_fram_buf/rd_fram_buf.idf"
add_design "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/ipcore/wr_fram_buf/wr_fram_buf.idf"
add_design "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/ipcore/ddr3_test/ddr3_test.idf"

add_constraint "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/hdmi1080p/HDMI_DDR3_OV5640_test.fdc"

set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module hdmi_ddr_ov5640_top
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr
report_timing
gen_bit_stream
