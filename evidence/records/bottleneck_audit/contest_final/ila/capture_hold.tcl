dbg_connect -ip __IP__ -port __PORT__
dbg_scan_chain
dbg_program -device 0 -file __SBIT__
dbg_open_project -file __DPRJ__
dbg_add_all_to_waveform
dbg_run
dbg_delay -time 2
dbg_stop
dbg_save_project -file __DPRJ__
dbg_delay -time 150
