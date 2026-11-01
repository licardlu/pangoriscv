# Fabric Debugger TCL - quick dbg_set_unit syntax probe (board still holds ILA bitstream)
dbg_connect -ip __IP__ -port __PORT__
dbg_scan_chain
dbg_import_fic -file __FIC__
dbg_set_unit -unit 0 -func "==" -value __TRIGVAL__ -radix 2
dbg_list
dbg_close
