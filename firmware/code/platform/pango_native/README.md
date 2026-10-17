# Native AXI board configuration

Target: MES2L676-100HP, PG2L100H-6IFBG676, **27 MHz** single-ended oscillator on
`clk` (pin D18). The board has no 50 MHz oscillator: the core board's second
oscillator is 125 MHz differential and feeds the DDR3 reference clock only.

> Board material confirmation (board-material audit round, 2026-10-11): the FPGA
> part `PG2L100H-6IFBG676`, the board product name `MES2L676-100HP` and the board
> version V1.2 are all confirmed from the vendor's own documentation
> (`1_Demo_document/实验例程说明篇/教程1_硬件实验指导手册_盘古676系列100Pro+开发板.pdf`
> and `教程2_...pdf`). The earlier closure-round caveat that
> `MES2L676-100HP` had no independent source is resolved.
> The 27 MHz clock comes from tutorial 1 section 2.1.2.2.3.2 (U11 oscillator,
> table row `FPGA_GCLK_27M | FPGA 输入全局时钟 | D18`), tutorial 2 section 7.2
> ("在 100K 板卡上单端时钟有一个 27MHZ 的时钟。所以其周期约为 37.037ns") and the
> vendor's own UART demo (`2_8_uart_test/source/uart_top.v:34`,
> `parameter BPS_NUM = 16'd234` = 27e6/115200).
> Full comparison tables: `the project validation archive`.

Status (2026-10-11, **board-material audit round**; `platform/pango_native/build.tcl`
run end to end with the installed PDS 2022.2-SP6.4): native CPU synthesis, device
mapping, place-and-route, timing reports and bitstream generation all completed
with `Design Summary : All Constraints Met.` at the board's **real 27 MHz
(37.037 ns)** clock, and all 13 pins were re-matched against the vendor material.
**Final post-route numbers** (delivered constraints): slow-corner setup WNS
**16.366 ns** and hold WHS **0.023 ns** (0 failing endpoints of 29177); fast
corner setup WNS 24.018 ns, hold WHS 0.011 ns; no other violation class. The
final `report_timing` re-analysis agrees (setup 16.189 ns, hold 0.031 ns, 0
`Slack (VIOLATED)` path blocks) and estimates **47.9662 MHz** against the
requested 27.0000 MHz. Resources: 7509 / 66600 LUTs (4172 CLMA + 3337 CLMS;
11.27%), 2984 / 133200 registers (2219 CLMA + 765 CLMS; 2.24%), 4 / 155 DRM,
6 / 240 APM, 13 / 300 IO, 2080 / 19900 distributed RAM. Bitstream
`build/pango_native/generate_bitstream/pango_native_top.sbit` (3,791,112 B,
SHA256 `AC049EB57946429A381C56BB0D3AD58608A453A08446F12B6D6666150D9EF576`).
Note: the 20 ns over-constraint experiment (run F) reuses the same
`build/pango_native/` directory and therefore overwrote the delivered artifacts
there; after run F the delivered run E state was restored from the archive and
re-verified byte-for-byte (`.sbit` `AC049EB5…`, `report_timing/pango_native_top.rtr`
136,183 B `8898EDA6…`). Run F's own bitstream stays archived under
`pds_50mhz_holdopt/`.
Two honest caveats: the **hold margin is only 23-31 ps** - the default `pnr`
options left one endpoint at -0.007 ns, and the margin above was obtained by
giving the router a 50 ps hold-optimisation target (see "Build" below) - and
"47.97 MHz" is the tool's estimate derived from the reported slack, not a
measured maximum frequency. Evidence: this round's delivered run
`the project validation archive`, plus the
historical runs `pds_27mhz/` (default `pnr`: hold -0.007 ns,
`Some Constraints Violated`), `pds_27mhz_final/` (the rejected
`set_clock_uncertainty` experiment), `pds_50mhz_holdopt/` (20 ns over-constraint
margin experiment: setup +5.219 ns, hold +0.096 ns, tool-estimated 67.3310 MHz)
and `the project validation archive` (the pre-audit 50 MHz run,
kept only for comparison).
The generated bitstream still carries
`Bitstream-2001: SCBV has not been set. Please set SCBV value based on PCB
board`. **This warning is benign for this design and no SCBV value may be
guessed**: the PDS 2022.2-SP6.4 release notes (page 11) list SCBV as applying to
PG2T390H/PG2L25H/PG2L50H only - this board's PG2L100H is not among them - and
SCBV configures Bank L4/L5, while all pins used here are on Bank L3 (3.3 V, per
the official manual). The vendor's own `2_8_uart_test` demo produces the same
warning when it generates its bitstream (`.../run.log:1132`). No download to
hardware has been performed and no on-board signal has been measured. The older
counter LED implementation is separate evidence and is not CPU evidence.

## Board behavior

KEY0/C22 is active-low reset. Its assertion is asynchronous in the two-stage
reset synchronizer; deassertion is synchronous to the oscillator. All CPU,
AXI fabric, RAM and peripheral instances receive this one reset. Their
internal synchronous reset logic resets on clock edges. Hold KEY0 through
initial configuration and release it while the oscillator is running.
No implicit power-on register initialization is required by the wrapper.

KEY1/C23 feeds GPIO input bit 0; GPIO input bit 1 is tied high.
The inverted KEY1 feeds external-event bit 0, so a press makes a rising
event. Event bit 1 is zero. Peripheral synchronizers handle these inputs.
There is no mechanical debounce: software must tolerate repeated events.

Each LED is active high and displays gpio_data[i] only when its two-bit
gpio_ctrl mode is 01 (output), and the shared reset is released.
All other modes drive the LED off. Halt and debug address are tied to zero;
trap_ready is high. External IRQ override inputs are zero; local timer and
interrupt controller IRQs remain connected inside the SoC. Architectural
mtvec is owned by the CPU CSR block; direct trap_vector is tied to zero.
SPI is internal and unused on this board wrapper, with MISO tied high.

## Pin provenance

All values were re-confirmed in the board-material audit round against the
official vendor material rooted at
`E:\daiduwangpan\盘古100Pro+开发板（MES2L676-100HP）配套资料`.
**All 13 pins matched, so no `def_port` value was changed** (only a comment
header was added to `pango_native.pcf`). Per-pin evidence with page/line numbers:
`the project validation archive`.

- Clock `clk` = D18: tutorial 1 section 2.1.2.2.3.2.
- Reset `rst_n` = C22 (KEY0, active low): tutorial 1 key table.
- KEY `key` = C23 (KEY1): tutorial 1 key table.
- UART `uart_tx` = C24, `uart_rx` = B24: tutorial 1 UART table and the official
  demo `2_8_uart_test` `.fdc` (`uart_test.fdc`).
- LEDs `led[0..7]` = A20 C18 C19 E18 A17 A18 C17 B17: tutorial 1 LED table,
  matching the official `uart_test.fdc`, `key_led_test.fdc` and `led_test.fdc`.
  Bank L3, 3.3 V LVCMOS33, active high.
- Extracted demos are kept under
  `the project validation archive`.

## Build

Build native software first using `tools/build_native_software.py`.
The default image directory is `build/native_software/coremark/performance`.
Set environment variable `NATIVE_IMAGE_DIR` to an absolute directory containing
`program.hex` and `data.hex` to select another native application.
The shipped CoreMark performance configuration is:

```
python tools/build_native_software.py coremark --mode performance \
    --iterations 200 --cpu-mhz 27 \
    --toolchain-bin "E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin"
```

200 iterations is chosen so the measured **3 274 904 ticks per 2K iteration give
654 980 800 cycles**, i.e. **24.26 s at the board's real 27 MHz clock**, which
clears the contest's "not less than 10 seconds" requirement with a wide margin.
Under the old 50 MHz assumption the same tick count looked like 13.10 s, which is
why the frequency constant had to be corrected.
**Audit-round re-measurement at 27 MHz** (200 iterations, ModelSim,
`Errors: 0, Warnings: 0`): the serial report gives `Total ticks : 655032761`,
`Total time (secs): 24`, `Iterations/Sec : 8`, the full CRC set
(`seedcrc 0xe9f5`, `[0]crclist 0xe714`, `[0]crcmatrix 0x1fd7`,
`[0]crcstate 0x8e3a`, `[0]crcfinal 0x382f` - every `[0]` prefix means no error),
`CPM_TICKS hi=0 lo=655213669` (raw 64-bit stop time, no wrap: `t0 = 180908`,
`t1 - t0 = 655032761`), and no `Errors detected`. The testbench reports
`TEST_PASS T_COREMARK_BOUNDED retires=61179051 traps=0 cycles=656846181`. The
derived score is `200 / 24.26 / 27 ~= 0.305` CoreMark/MHz. The firmware cannot
print the standard `CoreMark 1.0 : <score>` line because `HAS_FLOAT` is 0 in
`tests/example/coremark/core_portme.h:16`, so the score must be computed as
shown. Evidence: `the project validation archive*.log`
(the testbench drains only 12000 cycles after the first report line, so the last
~50 characters of the closing sentence, `Correct operation validated. See
README.md for run and reporting rules.`, were not decoded - all numeric fields
and CRCs were); the 1-iteration run in
`the project validation archive`; the 10000-iteration image is kept
in `basic_final/coremark/performance_10000_iter/` for reference.

`build.tcl` now also checks that the image it is about to load matches the board
clock: it reads `manifest.json` beside `program.hex`/`data.hex` and prints
`Board check: image cpu_hz=27000000 matches the 27 MHz board clock.`, warning if
a stale 50 MHz image is used instead. After `compile` it additionally requires
the compile log to contain two `Loading memory data from file` lines (one per
memory image) and aborts otherwise, because a run started from the wrong working
directory silently produces a bitstream with empty program/data memory.

Drive PDS from a batch shell (no interactive Tcl console needed):

```
$env:PANGO_NATIVE_REPO     = "<package root>"              # this package root
$env:PANGO_NATIVE_BOARD_DIR = "<repo>\platform\pango_native"
Set-Location "<repo>\build\pango_native"
& "E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe" `
    -file "<repo>\platform\pango_native\build.tcl"
```

`PANGO_NATIVE_REPO` and `PANGO_NATIVE_BOARD_DIR` are optional: without them
`build.tcl` falls back to its own location. They exist because in `pds_shell
-file` batch mode the Tcl `info script` path is relative and a bare
`info script` therefore resolves to `.`, which made the earlier version look
for `./pango_native.fdc` after it had changed directory. `build.tcl` now
validates that `native_sources.tcl`, `pango_native.fdc` and `pango_native.pcf`
exist and refers to all three by absolute path.

The SystemVerilog project option is **not** required for this delivery. That
was only needed while `rtl/perips/axi_ram.v` used an inline
`for (integer lane = 0; ...)` declaration; the loop variable is now declared at
the top of the module, which is the only construct in the 29-source manifest
that the PDS Verilog-2001 analyzer rejected. The successful run above was made
with the analyzer's default settings, so staging `.sv` file names is now
sufficient. (The local ADS Synthesis User Guide PDF pages 124-125 documents the
Compile > Project Settings switch if a future source needs it.)

`native_sources.tcl` reads `sim/native_axi_sources.f` directly and adds the
board wrapper only if it is absent. `build.tcl` stages unchanged RTL with `.sv`
extensions under `build/pango_native/sources`, copies both memory images into
`build/pango_native`, then explicitly changes to that directory. Include paths
are absolute and resolved relative to the script, not to a user-specific
checkout path. Standalone wrapper users must supply its
PROGRAM_INIT_FILE/DATA_INIT_FILE parameters or place both files in their
execution working directory.

PDS local `doc/Pango_Design_Suite_User_Guide.pdf` PDF pages 167 and 250
document `compile -include_path`; the flow follows the repository's
`docs/evidence/platform/verify.tcl`. The clock FDC creates the **real 37.037 ns
(27 MHz) board clock** and deliberately does not mask asynchronous UART/key pins
or the reset path with a blanket false-path constraint, so PDS reports
`Timing-4087`/`Timing-4086` for `led[0..7]`, `uart_tx`, `key`, `rst_n` and
`uart_rx`. Those warnings are the expected consequence of declaring only the real
clock; they are not a timing failure.

`build.tcl` runs `pnr` with an explicit hold-optimisation target, in the form of an
argument list that an environment variable can extend:

```tcl
set pnr_args [list \
    -fix_hold_violation_threshold 0 \
    -fix_hold_violation_threshold_for_clk_tree 0 \
    -fix_hold_violation_threshold_for_clock_path_cross_srb 0 \
    -fix_hold_violation_iterations 50 \
    -fix_hold_violation_in_route TRUE]
if {[info exists ::env(PANGO_NATIVE_PNR_EXTRA)]} {
    set pnr_args [concat $pnr_args $::env(PANGO_NATIVE_PNR_EXTRA)]
}
eval pnr $pnr_args
```

The thresholds are **integer picoseconds** (`pnr -help` prints
`Fix Hold Violation Threshold(ps)`; the PDS User Guide section 9.12 / PDF page
253 describes the option as optimising hold for paths whose slack is below the
value). The plain `pnr` default left one hold endpoint at **-0.007 ns** under the
real 37.037 ns constraint, because the router then only has to reach 0.000 ns and
stopped after its six default iterations; a 50 ps target reached **+0.023 ns**.
No constraint is relaxed anywhere in this: no timing exception, no false path and
no clock-period change. An earlier attempt to reach the same goal by adding
`set_clock_uncertainty -hold 0.05` to the FDC was **withdrawn**: it only raises the
reported target the router cannot meet, so the report stays negative forever
(evidence in `the project validation archive` section 5).

### Hold closure, 2026-10-18 (two-way caches + deeper fetch front end)

With the two-way I/D caches in the netlist the default list above is no longer
enough: the 27 MHz flow finished with setup WNS +16.521 ns and **four failing hold
endpoints at -0.020 ns**, all on the I-cache distributed-RAM write ports
(`instruction_cache/set_q[0] -> soc/m_araddr[5] -> data_mem_*/ram64x1d/WADDR[4]`).
The cause is **clock-tree branch skew, not a long data path**: launch clock on
`HCKBROUTE_2` arrives at 3.238 ns, capture clock on `HCKBROUTE_1` at 3.832 ns, in
different columns; the 0.312 ns broadcast net on the data side is what eats the
margin. Raising the target above zero gives the router a positive goal to chase:

```powershell
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 150 " +
  "-fix_hold_violation_threshold_for_clk_tree 150 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 150 " +
  "-fix_hold_violation_iterations 400 -max_hold_violated_paths_num 4000 " +
  "-groute_seed 23 -gplace_seed 23"
```

Result: `All Constraints Met`, setup WNS **+14.127 ns** and hold WHS **+0.154 ns
(slow) / +0.113 ns (fast)**, 0 of 52,349 endpoints failing. This asks only for MORE
hold fixing (a positive slack target plus different placement/routing seeds).

### Resource check without place-and-route

`resource_check.tcl` reuses the whole front end of `build.tcl` (same source list,
include path, constraints and memory image, and the same "both images loaded"
guard) but stops after `dev_map`. LUT / FF / DRAM are decided there, so this
reproduces the delivered resource numbers in about three minutes, which is what
makes an RTL-revision resource A/B practical. Set `RESOURCE_RUN_DIR` to a fresh
directory name and, for the baseline side, `RESOURCE_BASELINE_DIR` +
`RESOURCE_BASELINE_FILES` to stage in an older revision (the naming convention is
the one `tools/run_fetch_ab.py` uses: `rtl/core/ifu_axi.v` becomes
`rtl__core__ifu_axi.v`). Run it from a fresh empty directory for the same
`$readmemh` reason as `build.tcl`.

`pango_native_50mhz_overconstraint.fdc` is an **experiment-only** file (20 ns) kept
so the frequency margin of the final RTL can be re-measured without pretending
50 MHz is the board clock. Select it with
`$env:PANGO_NATIVE_FDC = "<repo>\platform\pango_native\pango_native_50mhz_overconstraint.fdc"`.
Its bitstream is not the delivered bitstream.

## On-chip logic analyzer probe list

The board pinout is fixed, so the events needed for the contest's
"ILA waveform of CoreMark key algorithms" evidence are kept as named internal
nets in `rtl/soc/pangoriscv_top.v` (port name `obs_*` after PDS flattening).
PDS instruments internal nets by name.

**Syntax note (closure round)**: the nets are kept with the vendor's documented
Synplify pragma form, i.e. `wire obs_x /* synthesis syn_keep = 1 */;` for the
combinational nets and
`reg [31:0] obs_retire_count /* synthesis syn_keep = 1, syn_preserve = 1 */;`
for the two free-running counters (`syn_preserve` is what keeps a register that
otherwise drives nothing outside the design). The earlier
`(* keep = "true" *)` form is **not** usable here: PDS translates it to
`PAP_KEEP` and rejects the value
(`The value of attribute PAP_KEEP is invalid, ignore it.`), and the earlier
`(* ASYNC_REG = "TRUE" *)` on the reset synchronizer produced
`W: Sdm-2008: The attribute named ASYNC_REG is not legal`. With the illegal
attributes, only 4 of the 19 observation names and neither counter survived into
the post-synthesis netlist; with the pragmas above, all 18 names are present in
`build/pango_native/synthesize/pango_native_top_syn.vm` (pre-rename build tree;
the top module is `pangoriscv_top` from 2026-10-13 on, so fresh builds write
`pangoriscv_top_syn.vm`). Reference: Synplify Pro
for Pango Attribute Reference (`syn_keep` p.85/87, `syn_preserve` p.123;
`syn_probe` p.127 is deliberately not used because it would add top-level
ports).

| Probe | Width | Meaning |
| --- | --- | --- |
| `obs_retire_fire` | 1 | one instruction retired this cycle |
| `obs_retire_order` | 64 | monotonic retirement index |
| `obs_retire_pc` | 32 | retired instruction PC |
| `obs_retire_inst` | 32 | retired instruction encoding |
| `obs_rd_valid` / `obs_rd` / `obs_wdata` | 1/5/32 | architectural writeback |
| `obs_trap_fire` / `obs_trap_cause` / `obs_trap_pc` / `obs_trap_tval` | 1/32/32/32 | trap entry |
| `obs_halted` / `obs_arch_next_pc` | 1/32 | halt state and resume PC |
| `obs_protocol_fault` | 1 | any CPU or fabric protocol fault |
| `obs_csr_mtvec` | 32 | architectural trap vector |
| `obs_uart_tx` | 1 | serial output line |
| `obs_retire_count` / `obs_trap_count` | 32/32 | free-running counters, convenient ILA qualifiers |

Suggested trigger for the CoreMark key-algorithm capture: qualify on
`obs_retire_pc` inside the region of interest (for a 2K performance run the
list kernels live near `0x1044`-`0x127c`, the matrix kernels near
`0x17e8`-`0x18a8` in `build/native_software/coremark/performance/firmware.dump`)
and trigger on `obs_protocol_fault` or `obs_trap_fire` to catch a fault.
`obs_retire_count` makes a "capture N retirements and stop" trigger trivial.
Timing a capture so the window covers a meaningful slice of a >= 10 s run is
still an open board activity; no capture has been taken.
