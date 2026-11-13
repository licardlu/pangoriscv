set fh [open "D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/cap.log" w]
proc log {m} {global fh; puts $fh $m; flush $fh}
log "connect"
if {[catch {dbg_connect -ip 127.0.0.1 -port 65420} m]} {log "connect ERR $m"} else {log "connect OK"}
if {[catch {dbg_scan_chain} m]} {log "scan ERR $m"} else {log "scan OK $m"}
if {[catch {dbg_program -device 0 -file D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/pds_native_120/build/ila-003/generate_bitstream/pango_vexii_top.sbit} m]} {log "prog ERR $m"} else {log "prog OK"}
dbg_delay -time 2
if {[catch {dbg_list} m]} {log "list ERR $m"} else {log "list OK"}
if {[catch {dbg_set_cur_core -device 0 -core 0} m]} {log "core ERR $m"} else {log "core OK"}
if {[catch {dbg_import_fic -file D:/FPGA_Project/zi_guang_tong_chuang/tmp/ila/ila.fic} m]} {log "fic ERR $m"} else {log "fic OK"}
if {[catch {dbg_set_capture -type 1 -samples 4096} m]} {log "cap ERR $m"} else {log "cap OK"}
if {[catch {dbg_set_unit -unit 0 -func "==" -value "0001000000001000000000000000001XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" -radix 2} m]} {log "unit ERR $m"} else {log "unit OK"}
if {[catch {dbg_add_all_to_waveform} m]} {log "wave ERR $m"} else {log "wave OK"}
log "RUN"
if {[catch {dbg_run} m]} {log "run ERR $m"} else {log "run OK"}
log "DONE"
close $fh
