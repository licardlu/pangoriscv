# Fabric Debugger TCL - ILA capture smoke test (placeholders substituted by run_ila_capture.ps1)
# step 1: connect to JtagServer and program the ILA debug bitstream
dbg_connect -ip 127.0.0.1 -port 65420
dbg_scan_chain
dbg_program -device 0 -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila_debug/src/build/pango_native/generate_bitstream/pangoriscv_top.sbit
dbg_import_fic -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila_debug/src/platform/pango_native/pangoriscv_coremark.fic
dbg_list
dbg_add_all_to_waveform
# immediate trigger smoke test: captures whatever is in the pipeline right now
dbg_trig_immd
dbg_delay -time 45
dbg_stop
dbg_save_project -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/logs/ila_capture_smoke3/ila_capture.dprj
dbg_close

