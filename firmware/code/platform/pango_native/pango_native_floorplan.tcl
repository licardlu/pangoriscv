# pango_native_floorplan.tcl -- P13 modular floorplanning (physical regions).
#
# Sourced by run_pds_flow.py --floorplan AFTER dev_map and the board PCF, i.e.
# exactly where build.tcl adds its PCF.  Plain Tcl so every def_* call can
# `catch` and print its own verdict into run.log -- a silently ignored region
# would otherwise look exactly like a region that worked (mistakes-log 34).
#
# Coordinate system (learned from PDS `show_device` output for PG2L100H):
#   floorplan (x,y) == the suffixes of the site names, e.g. CLMA_58_120 is at
#   (58,120).  CLMA/CLMS columns x = 10,14,18,22,30,...,122; the gaps at
#   x=26/54/106 are DRM columns and x=86 is the APM column; tile rows y=0..245.
#   Region format: def_region <name> <xmin> <xmax> <ymin> <ymax>
#   (Pango Design Suite User Guide section 2.10, pds_shell `def_region -help`).
#
# Layout follows the data flow left to right (module-area-plan section 9.9:
# the widest busiest bus must not cross a region; two LUTRAM arrays must not
# share a corridor; BRAM stays on its dedicated column):
#
#   x 10          28 30      50  58            86  90          108 110     122
#     [  R_ICACHE  ][ R_FETCH][    R_CORE      ][   R_DCACHE   ][   R_IO   ]
#     icache+prog   ifu+u_bp  cpu regs/ALU/APM   dcache+lsu+data  fabric+
#     ROM(DRM x=26)            (APM col x=86!)   ram(LUTRAM)      perips
#     |<-- 64b fetch bus -->|  |<-- lsu/mem -->|
#
# Two placement facts the geometry encodes:
#   * u_mul/u_mul_h are APM primitives and the only APM column is x=86, so
#     R_CORE must include x=86 or the multipliers cannot legally land in it.
#   * soc.data_ram is 2,048 LUTRAM (M2 to BRAM was blocked, area-M2), so it
#     needs CLMA columns, not a DRM column -- it sits with the D-side cluster.

# ---- instance-name resolution ----------------------------------------------
# Netlist paths print as soc/core/cpu/... ; constraint commands want the design
# instance name.  Try the documented dotted form first, fall back to slashes,
# and print which one the tool accepted.
proc fp_bind {inst region} {
    foreach form [list $inst [string map {. /} $inst]] {
        set r [catch {def_inst_region $form $region} m]
        puts "FLOORPLAN bind $form -> $region : catch=$r $m"
        if {$r == 0} { return 1 }
    }
    puts "FLOORPLAN bind FAILED for $inst -> $region"
    return 0
}

# ---- regions ---------------------------------------------------------------
foreach spec {
    {R_ICACHE  10 28 0 245}
    {R_FETCH   30 50 0 245}
    {R_CORE    58 86 20 225}
    {R_DCACHE  90 108 0 245}
    {R_IO      110 122 0 245}
} {
    lassign $spec n x1 x2 y1 y2
    set r [catch {def_region $n $x1 $x2 $y1 $y2} m]
    puts "FLOORPLAN region $n x\[$x1,$x2\] y\[$y1,$y2\] : catch=$r $m"
}

# ---- bindings (module-area-plan D1 field 8) --------------------------------
# Parents before children: soc.core.cpu.u_bp deliberately overrides the
# cpu-wide R_CORE binding for the BTB (field 8 of card M03 says R_FETCH --
# the BTB lookup sits in the fetch loop).  If the tool refuses the override,
# u_bp simply stays in R_CORE and the run still measures the rest.
fp_bind soc.core.instruction_cache R_ICACHE
fp_bind soc.program_ram R_ICACHE
fp_bind soc.core.ifu R_FETCH
fp_bind soc.core.cpu R_CORE
fp_bind soc.core.cpu.u_bp R_FETCH
fp_bind soc.core.data_cache R_DCACHE
fp_bind soc.core.lsu R_DCACHE
fp_bind soc.data_ram R_DCACHE
fp_bind soc.fabric R_IO
fp_bind soc.core.instruction_engine R_IO
fp_bind soc.core.data_engine R_IO
fp_bind soc.uart_inst R_IO
fp_bind soc.gpio_inst R_IO
fp_bind soc.timer_inst R_IO
fp_bind soc.spi_inst R_IO
fp_bind soc.irq_inst R_IO

puts "FLOORPLAN_DONE"
