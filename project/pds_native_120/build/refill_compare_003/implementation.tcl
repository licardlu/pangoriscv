# Self-contained: cwd is a fresh run staged entirely from this package.
# Device, clock/pin constraints and implementation options match native-pds-001.
set run [pwd]
foreach stage {compile synthesize device_map place_route} {
  if {[file exists [file join $run $stage]]} { error "Use a fresh build directory" }
}
source [file join $run source_list.tcl]
foreach f $exact_sources { add_design $f }
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
add_constraint [file join $run constraints pango_vexii.fdc]
compile -top_module pango_vexii_top
set fh [open [file join $run compile run.log] r]
set log [read $fh]
close $fh
if {[regexp -all {Loading memory data from file} $log] != 8 || [regexp {Cannot open specified data} $log]} {
  error "Exactly eight firmware memory lanes must load successfully"
}
synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint [file join $run constraints pango_vexii.pcf]
pnr -fix_hold_violation_threshold 0 -fix_hold_violation_threshold_for_clk_tree 0 -fix_hold_violation_threshold_for_clock_path_cross_srb 0 -fix_hold_violation_iterations 50 -fix_hold_violation_in_route TRUE
report_timing
gen_bit_stream
puts "EXACT_BUILD_FLOW_COMPLETE"
