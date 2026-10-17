# Run manually in PDS after external RTL validation. This script synthesizes,
# maps, places and routes the native CPU SoC and writes a bitstream.
#
# Batch use:  pds_shell.exe -file <abs path to this script>
# Under `pds_shell -file` the interpreter does not always report a usable
# [info script] (it came back as "." and made the constraints resolve to
# ./pango_native.fdc and ./pango_native.pcf, which failed with Flow-0049), so
# the layout directory is resolved explicitly and can be forced by the caller.

if {[info exists ::env(PANGO_NATIVE_REPO)]} {
    set repo [file normalize $::env(PANGO_NATIVE_REPO)]
}
if {[info exists ::env(PANGO_NATIVE_BOARD_DIR)]} {
    set board_dir [file normalize $::env(PANGO_NATIVE_BOARD_DIR)]
} else {
    set script_path [info script]
    set board_dir ""
    if {[string length $script_path] > 0} {
        set candidate [file dirname [file normalize $script_path]]
        if {[file isfile [file join $candidate native_sources.tcl]]} {
            set board_dir $candidate
        }
    }
}
if {$board_dir eq ""} {
    error "Cannot locate platform/pango_native from the script path. Set PANGO_NATIVE_BOARD_DIR to its absolute path (and optionally PANGO_NATIVE_REPO to the project root), or source this script by absolute path."
}
if {![info exists repo]} {
    set repo [file normalize [file join $board_dir ../..]]
}
foreach required {native_sources.tcl pango_native.fdc pango_native.pcf} {
    if {![file isfile [file join $board_dir $required]]} {
        error "Missing $required in $board_dir"
    }
}
set fdc_file [file join $board_dir pango_native.fdc]
# The delivered constraint is pango_native.fdc = the real 27 MHz board clock. Set
# PANGO_NATIVE_FDC to the absolute path of pango_native_50mhz_overconstraint.fdc to run the
# frequency-margin experiment instead; that run is an over-constraint, never the board clock.
if {[info exists ::env(PANGO_NATIVE_FDC)]} {
    set fdc_file [file normalize $::env(PANGO_NATIVE_FDC)]
    if {![file isfile $fdc_file]} {
        error "PANGO_NATIVE_FDC does not exist: $fdc_file"
    }
}
set pcf_file [file join $board_dir pango_native.pcf]
puts "Constraint file: $fdc_file"

source [file join $board_dir native_sources.tcl]
set sources [native_board_sources $repo]
set image_dir [file join $repo build native_software coremark performance]
if {[info exists ::env(NATIVE_IMAGE_DIR)]} {
    set image_dir [file normalize $::env(NATIVE_IMAGE_DIR)]
}
foreach image {program.hex data.hex} {
    if {![file isfile [file join $image_dir $image]]} {
        error "Missing $image in $image_dir; compile native software first"
    }
}
# Board configuration check (MES2L676-100HP): a 27 MHz single-ended oscillator drives D18.
# The firmware's CoreMark seconds conversion and its UART baud write both derive from
# CPU_FREQ_MHZ, so an image built for another frequency gives a wrong serial baud rate and a
# wrong reported run time on hardware. Warn instead of failing so the flow stays usable.
set board_clk_hz 27000000
set manifest_file [file join $image_dir manifest.json]
if {[file isfile $manifest_file]} {
    set fh [open $manifest_file r]
    set manifest_text [read $fh]
    close $fh
    if {[regexp {"cpu_hz"[ \t]*:[ \t]*([0-9]+)} $manifest_text -> image_cpu_hz]} {
        if {$image_cpu_hz ne $board_clk_hz} {
            puts "WARNING: image cpu_hz=$image_cpu_hz does not match the 27 MHz board clock."
            puts "WARNING: rebuild with --cpu-mhz 27 or the UART baud rate and the CoreMark"
            puts "WARNING: run time will be wrong on hardware."
        } else {
            puts "Board check: image cpu_hz=$image_cpu_hz matches the 27 MHz board clock."
        }
    }
} else {
    puts "Board check: no manifest.json beside the images; cannot verify cpu_hz."
}
set run_dir [file join $repo build pango_native]
file mkdir $run_dir
set source_dir [file join $run_dir sources]
file mkdir $source_dir
# Preserve source hierarchy; use .sv extensions rather than undocumented flags.
foreach source $sources {
    set relative [string range $source [expr {[string length $repo]+1}] end]
    set staged [file join $source_dir [file rootname $relative].sv]
    file mkdir [file dirname $staged]
    file copy -force $source $staged
    add_design $staged
}
foreach image {program.hex data.hex} {
    file copy -force [file join $image_dir $image] [file join $run_dir $image]
}
# RAM $readmemh paths resolve from this explicit working directory.
cd $run_dir
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
# Absolute constraint paths: after `cd $run_dir` a relative path would resolve
# against the run directory instead of the layout directory.
add_constraint $fdc_file
compile -top_module pangoriscv_top -include_path [list [file join $repo rtl core]]
# Guard against the silent empty-memory failure: if the working directory is wrong, axi_ram's
# $readmemh cannot open program.hex/data.hex, PDS still completes, and the bitstream comes out
# with no program content (observed 2026-10-10 in the project-root stray run: "Cannot open
# specified data file" plus zero GTP_DRM36K_E1 in the netlist). Require the compile log to
# show both memory images being loaded before the flow is allowed to continue.
set compile_log [file join $run_dir compile run.log]
if {[file isfile $compile_log]} {
    set fh [open $compile_log r]
    set log_text [read $fh]
    close $fh
    set loaded [llength [regexp -all -inline {Loading memory data from file} $log_text]]
    if {$loaded < 2} {
        error "Only $loaded of 2 memory images were loaded (program.hex/data.hex) according to $compile_log. Refusing to continue: that bitstream would carry empty program/data memory."
    }
    puts "Board check: $loaded memory images loaded into the design."
} else {
    puts "Board check: compile log not found at $compile_log; memory load not verified."
}
synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint $pcf_file
# Hold closure (board-material audit round, 2026-10-11): the plain `pnr` run at the real
# 27 MHz board clock finished with ONE failing hold endpoint at -0.007 ns, even though the
# identical RTL placed under the 20 ns experiment met hold with +0.124 ns. Hold checks do not
# depend on the clock period, so the fix is a routing/placement objective, not a constraint.
# The thresholds are integer PICOSECONDS - `pnr -help` prints
#   [ -fix_hold_violation_threshold integer_number ]  Fix Hold Violation Threshold(ps)
# (and the same "(ps)" for the clock-tree / cross-SRB variants; the first attempt with a
#  fractional "0.05" was rejected by the flow with
#   E: Flow-0079: Can not convert string "0.05" to integer.)
# So: 50 ps = 0.05 ns on all three threshold classes, plus a larger iteration budget.
# Nothing is relaxed by this: no timing exception, no false path, no reduced clock period.
#
# Follow-up (an early build): with the two-way I/D caches in the netlist the
# same flow left ONE failing hold endpoint at -0.027 ns (slow) / -0.015 ns (fast):
# soc/core/data_cache/set_q[4] -> soc/core/data_cache/tag_mem_12/ram64x1d/WADDR[4]
# (distributed-RAM write-address path, capture clock routed to the far column
# CLMS_171_1015 -> 0.55 ns of clock skew that the 50 ps setting did not repair; the
# fixer stopped after 6 of its 20 iterations). Raise the effort further - 0 ps on all
# three threshold classes, in-route hold optimisation enabled, 50 iterations. This only
# asks the placer/router for MORE hold fixing; no constraint, exception or clock period
# is relaxed.
pnr -fix_hold_violation_threshold 0 \
    -fix_hold_violation_threshold_for_clk_tree 0 \
    -fix_hold_violation_threshold_for_clock_path_cross_srb 0 \
    -fix_hold_violation_iterations 50 \
    -fix_hold_violation_in_route TRUE
report_timing
gen_bit_stream
