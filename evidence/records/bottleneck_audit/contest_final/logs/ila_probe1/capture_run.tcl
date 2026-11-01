# Fabric Debugger TCL - probe: list debug core / trigger port channel mapping
# (the board still holds the ILA debug bitstream from the smoke test; no re-program)
dbg_connect -ip 127.0.0.1 -port 65420
dbg_scan_chain
dbg_import_fic -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila_debug/src/platform/pango_native/pangoriscv_coremark.fic
dbg_list
dbg_get_buses
dbg_list -trig_port1
dbg_delay -time 15
dbg_save_project -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/logs/ila_probe1/ila_capture.dprj
dbg_close

