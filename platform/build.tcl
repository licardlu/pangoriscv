if {![info exists ::env(VEXII_ROOT)]} { error "VEXII_ROOT is required" }
set root [file normalize $::env(VEXII_ROOT)]
set run [pwd]
foreach stage {compile synthesize device_map place_route} {
  if {[file exists [file join $run $stage]]} { error "Use a fresh build directory" }
}
file mkdir [file join $run sources]
foreach f [list [file join $root rtl generated MicroSoc.v] [file join $root rtl pango_reset.sv] [file join $root rtl pango_pll.sv] [file join $root rtl pango_vexii_top.sv]] {
  set staged [file join $run sources [file tail $f]]
  file copy -force $f $staged
  add_design $staged
}
foreach f [glob [file join $root rtl generated *.bin]] {file copy -force $f $run}
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
add_constraint [file join $root platform pango_vexii.fdc]
compile -top_module pango_vexii_top
set fh [open [file join $run compile run.log] r]
set log [read $fh]
close $fh
if {[regexp -all {Loading memory data from file} $log] < 8 || [regexp {Cannot open specified data} $log]} {
  error "Eight firmware memory lanes must load successfully"
}
synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint [file join $root platform pango_vexii.pcf]
pnr -fix_hold_violation_threshold 0 -fix_hold_violation_threshold_for_clk_tree 0 -fix_hold_violation_threshold_for_clock_path_cross_srb 0 -fix_hold_violation_iterations 50 -fix_hold_violation_in_route TRUE
report_timing
gen_bit_stream
puts "BUILD_FLOW_COMPLETE"
