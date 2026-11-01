# Fabric Debugger TCL - real ILA capture on the frozen candidate debug bitstream.
# Board already holds the ILA debug bitstream (programmed by capture_smoke.tcl);
# if the board was power-cycled, add dbg_program -device 0 -file __SBIT__ first.
dbg_connect -ip __IP__ -port __PORT__
dbg_scan_chain
dbg_import_fic -file __FIC__
dbg_list
dbg_set_unit -unit 0 -func "==" -value __TRIGVAL__ -radix 2
dbg_set_condition -select 0 -set "TU0"
dbg_set_capture -type 0 -windows 1 -position 256
dbg_set_storage -storage "AllData"
dbg_add_all_to_waveform
dbg_run
dbg_delay -time 45
dbg_stop
dbg_save_project -file __DPRJ__
dbg_close
