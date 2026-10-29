# Run with PDS: pds_shell -file platform/open_project.tcl -work_dir project -project_name VexiiRiscv_improved
# This creates a portable project only. It does not synthesize or program hardware.
set root [file normalize [file join [file dirname [info script]] ..]]
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
foreach f {rtl/generated/MicroSoc.v rtl/pango_reset.sv rtl/pango_pll.sv rtl/pango_vexii_top.sv} {
  add_design [file join $root $f]
}
foreach f [glob [file join $root rtl generated *.bin]] {file copy -force $f [pwd]}
add_constraint [file join $root platform pango_vexii.fdc]
add_constraint [file join $root platform pango_vexii.pcf]
puts PROJECT_CREATED
