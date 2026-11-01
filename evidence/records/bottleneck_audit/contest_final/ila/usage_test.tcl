puts "HELP_START"
foreach c {dbg_connect dbg_scan_chain dbg_program dbg_run dbg_stop dbg_set_unit dbg_set_condition dbg_set_capture dbg_set_storage dbg_open_project dbg_save_project dbg_import_fic dbg_list dbg_trig_immd dbg_delay dbg_power_init dbg_set_cur_core} {
  puts "===CMDSEP=== $c"
  catch { eval $c } msg
  puts "MSG: $msg"
}
puts "HELP_DONE"
exit
