# Fabric Debugger TCL - quick dbg_set_unit syntax probe (board still holds ILA bitstream)
dbg_connect -ip 127.0.0.1 -port 65420
dbg_scan_chain
dbg_import_fic -file E:/file/pango/project/evidence/records/bottleneck_audit/contest_final/ila_debug/src/platform/pango_native/pangoriscv_coremark.fic
dbg_set_unit -unit 0 -func "==" -value 1000_0111_0000_0001_0000_0000_0000_0000_XXX1_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX_XXXX -radix 2
dbg_list
dbg_close

