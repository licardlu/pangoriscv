dbg_connect -ip 127.0.0.1 -port 65420
dbg_scan_chain
dbg_program -device 0 -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila_debug/src/build/pango_native/generate_bitstream/pangoriscv_top.sbit
dbg_open_project -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/logs/ila_capture_encA3/ila_capture.dprj
dbg_add_all_to_waveform
dbg_delay -time 600
dbg_close

