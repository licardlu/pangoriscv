# Synthesis-only resource check.
#
# Same front end as build.tcl -- same source list (sim/native_axi_sources.f via
# native_sources.tcl), same include path, same constraints, same memory image --
# but the flow STOPS after dev_map.  Resource utilisation is decided by
# synthesis + device mapping, so this reproduces the LUT / FF / DRAM numbers of a
# delivered bitstream in about three minutes instead of a full place-and-route,
# which is what makes an RTL-revision resource A/B practical.
#
# Baseline side: set RESOURCE_BASELINE_DIR to a directory holding staged copies
# of the files named in RESOURCE_BASELINE_FILES (space separated, repo relative,
# '/' written as '__' in the staged file name -- the convention
# tools/run_fetch_ab.py uses).  The working tree is never modified.
#
# Run from a fresh, empty directory: PDS resolves the $readmemh image paths
# against the PROCESS working directory, not against the `cd` below.  Running
# from anywhere else silently produces a design with empty program/data memory.

foreach required {PANGO_NATIVE_REPO PANGO_NATIVE_BOARD_DIR} {
    if {![info exists ::env($required)]} {
        error "Set $required"
    }
}
set repo [file normalize $::env(PANGO_NATIVE_REPO)]
set board_dir [file normalize $::env(PANGO_NATIVE_BOARD_DIR)]
set fdc_file [file join $board_dir pango_native.fdc]
set pcf_file [file join $board_dir pango_native.pcf]
source [file join $board_dir native_sources.tcl]
set sources [native_board_sources $repo]

# ---- optional baseline substitution ------------------------------------------
if {[info exists ::env(RESOURCE_BASELINE_DIR)]} {
    set bdir [file normalize $::env(RESOURCE_BASELINE_DIR)]
    if {![info exists ::env(RESOURCE_BASELINE_FILES)]} {
        error "RESOURCE_BASELINE_DIR needs RESOURCE_BASELINE_FILES"
    }
    foreach rel [split $::env(RESOURCE_BASELINE_FILES) " "] {
        if {$rel eq ""} { continue }
        set staged [file join $bdir [string map {"/" "__"} $rel]]
        if {![file isfile $staged]} {
            error "Missing staged baseline file: $staged"
        }
        set live [file normalize [file join $repo $rel]]
        set at [lsearch -exact $sources $live]
        if {$at < 0} { error "Not in the source list: $live" }
        set sources [lreplace $sources $at $at $staged]
        puts "Substitute $rel -> $staged"
    }
}

# ---- image ----------------------------------------------------------------
set image_dir [file join $repo build native_software coremark performance]
if {[info exists ::env(NATIVE_IMAGE_DIR)]} {
    set image_dir [file normalize $::env(NATIVE_IMAGE_DIR)]
}
foreach image {program.hex data.hex} {
    if {![file isfile [file join $image_dir $image]]} {
        error "Missing $image in $image_dir; compile native software first"
    }
}

# ---- stage sources --------------------------------------------------------
set run_name resource_check
if {[info exists ::env(RESOURCE_RUN_DIR)]} { set run_name $::env(RESOURCE_RUN_DIR) }
set run_dir [file join $repo build $run_name]
file mkdir $run_dir
set source_dir [file join $run_dir sources]
file mkdir $source_dir
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
cd $run_dir
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
add_constraint $fdc_file
compile -top_module pangoriscv_top -include_path [list [file join $repo rtl core]]

# Same empty-memory guard as build.tcl: a wrong working directory still finishes
# and yields a bitstream with zeroed memories, so require both images to load.
set compile_log [file join $run_dir compile run.log]
if {[file isfile $compile_log]} {
    set fh [open $compile_log r]
    set log_text [read $fh]
    close $fh
    set loaded [llength [regexp -all -inline {Loading memory data from file} $log_text]]
    if {$loaded < 2} {
        error "Only $loaded of 2 memory images were loaded according to $compile_log"
    }
    puts "Board check: $loaded memory images loaded into the design."
} else {
    error "compile log not found at $compile_log; memory load not verified"
}

synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint $pcf_file
puts "RESOURCE_CHECK_DONE (no place and route)"