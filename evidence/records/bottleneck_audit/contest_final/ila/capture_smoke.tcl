# Fabric Debugger TCL - ILA capture smoke test (placeholders substituted by run_ila_capture.ps1)
# step 1: connect to JtagServer and program the ILA debug bitstream
dbg_connect -ip __IP__ -port __PORT__
dbg_scan_chain
dbg_program -device 0 -file __SBIT__
dbg_import_fic -file __FIC__
dbg_list
dbg_add_all_to_waveform
# immediate trigger smoke test: captures whatever is in the pipeline right now
dbg_trig_immd
dbg_delay -time 45
dbg_stop
dbg_save_project -file __DPRJ__
dbg_close
