# compile + synthesize only, for Fabric Inserter
set run [pwd]
foreach stage {compile synthesize} {
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
puts "SYNTH_ONLY_COMPLETE"
