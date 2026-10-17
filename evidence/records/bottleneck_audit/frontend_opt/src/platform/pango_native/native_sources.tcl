# Return shared production sources, adding board top only when absent.
proc native_board_sources {repo} {
    set manifest [file join $repo sim native_axi_sources.f]
    set channel [open $manifest r]
    set text [read $channel]
    close $channel
    set sources {}
    foreach line [split $text "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line]} { continue }
        set path [file normalize [file join $repo $line]]
        if {![file isfile $path]} { error "Missing production source: $path" }
        lappend sources $path
    }
    set board_top [file normalize [file join $repo rtl soc pangoriscv_top.v]]
    if {[lsearch -exact $sources $board_top] < 0} {
        lappend sources $board_top
    }
    return $sources
}
