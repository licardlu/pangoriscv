# Fabric Debugger TCL - probe: list debug core / trigger port channel mapping
# (the board still holds the ILA debug bitstream from the smoke test; no re-program)
dbg_connect -ip __IP__ -port __PORT__
dbg_scan_chain
dbg_import_fic -file __FIC__
dbg_list
dbg_get_buses
dbg_list -trig_port1
dbg_delay -time 15
dbg_save_project -file __DPRJ__
dbg_close
