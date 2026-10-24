"""Drive one PDS implementation in a private build directory.

Why a script instead of a hand-run tcl: the two expensive mistakes in
`docs/lessons/mistakes-log.md` both come from hand-made build directories --
a directory without `program.hex` silently produces a bitstream with no program
(section 0), and re-running an implementation in the same directory overwrites
the evidence it was supposed to prove (section 2.1).  This driver always

  * creates a fresh `<build>/<tag>` (never reuses one),
  * copies `program.hex` / `data.hex` in before synthesis and then *proves* the
    synthesizer loaded them (`Loading memory data from file`),
  * keeps every stage log inside that directory, and
  * writes the timing report next to them.

usage:
  python tools/run_pds_flow.py --tag p6_ex2 --freq 126 --mode synth
  python tools/run_pds_flow.py --tag p6_ex2 --freq 126 --mode full --seed 7
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

CODE = Path(__file__).resolve().parents[1]          # firmware/code
RTL = CODE / "rtl"
PLATFORM = CODE / "platform" / "pango_native"
PDS_BIN = Path(r"D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin")

# Source order matters: leaf modules first, `rv32_top`/`pangoriscv` last.
CORE = [
    "div", "div_adapter", "ctrl", "ex", "ex_alu", "id", "id_alu", "pipe_slot",
    "id_ex", "if_id", "pc_reg", "regs", "retire_ctrl", "csr_native",
    "branch_predictor", "rv32/rv32_alu", "rv32/rv32_mul", "rv32/rv32_decode",
    "rv32/rv32_regfile", "rv32/rv32_top",
    "pangoriscv", "ifu_axi", "lsu_axi", "axi_read_engine", "axi_data_engine",
    "icache_axi", "dcache_axi", "pangoriscv_axi_top",
]
BUS = ["axi_error_slave", "axi_interconnect"]
PERIPS = ["axi_ram", "axi_reg_slave", "axi_gpio", "axi_timer", "axi_uart",
          "axi_spi", "irq_ctrl", "perf_regs"]
SOC = ["pangoriscv_axi_soc", "pangoriscv_top"]


def stage(tag: str, image_from: Path) -> Path:
    bdir = CODE / "build" / tag
    if bdir.exists():
        raise SystemExit("build/%s already exists -- one implementation per "
                         "directory (mistakes-log 2.1). Pick a new tag." % tag)
    (bdir / "sources").mkdir(parents=True)
    for sub in ("core", "bus", "perips", "soc"):
        dst = bdir / "sources" / "rtl" / sub
        # The flow feeds SystemVerilog to `compile`, so the staged copies carry
        # the .sv extension even though the repository keeps .v names.
        for f in sorted((RTL / sub).rglob("*")):
            if not f.is_file():
                continue
            rel = f.relative_to(RTL / sub)
            out = dst / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            # `defines.v` is an include-only header, not a module: renaming it
            # breaks every `include "defines.v"` in the tree (the compile step
            # then dies with a bare "Program Error Out").
            if f.suffix == ".v" and f.stem != "defines":
                shutil.copy2(f, out.with_suffix(".sv"))
            else:
                shutil.copy2(f, out)
    for name in ("program.hex", "data.hex"):
        shutil.copy2(image_from / name, bdir / name)
    for name in PLATFORM.glob("*.fdc"):
        shutil.copy2(name, bdir / name.name)
    shutil.copy2(PLATFORM / "pango_native.pcf", bdir / "pango_native.pcf")
    return bdir


def write_tcl(bdir: Path, freq: str, mode: str, seed: int | None,
              floorplan: Path | None = None, place_only: bool = False,
              pnr_extra: str | None = None, plain_pnr: bool = False,
              place_db: Path | None = None,
              syn_extra: str | None = None) -> Path:
    src = bdir / "sources" / "rtl"
    files = ([src / "core" / (m + ".sv") for m in CORE]
             + [src / "bus" / (m + ".sv") for m in BUS]
             + [src / "perips" / (m + ".sv") for m in PERIPS]
             + [src / "soc" / (m + ".sv") for m in SOC])
    fdc = bdir / ("pango_native_%smhz.fdc" % freq)
    lines = ["add_design \"%s\"" % f.as_posix() for f in files]
    lines.append("add_constraint \"%s\"" % fdc.as_posix())
    lines += [
        "set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676",
        "compile -top_module {pangoriscv_top} -include_path {%s}" % (src / "core").as_posix(),
        "synthesize -ads -selected_syn_tool_opt 2"
        + (" " + syn_extra if syn_extra else ""),
        "dev_map",
    ]
    if mode == "full":
        # Floorplanning (P13): region constraints ride in the SAME constraint
        # file as the board IO LOCs.  PDS allows only one .pcf per flow
        # (`PhysicalConstraintEditor-4040: Only one .pcf file can be added,
        # old .pcf file is cleared`), so the floorplan lines are appended to
        # the staged copy of pango_native.pcf.  Constraint-file form, NOT
        # `source`d Tcl: pds_shell evaluates sourced scripts during project
        # creation, when no design database exists yet, and a bare def_region
        # then kills the whole shell with no error and exit 0.
        #
        # A `.fdc` floorplan (PAP_REGION attributes) instead merges into the
        # staged frequency FDC -- the channel that survives dev_map, which is
        # where the PCF def_inst_region bindings crash pnr (P13, see
        # evidence/records/optimization/p13-modular-pnr/).
        if floorplan is not None:
            if floorplan.suffix == ".fdc":
                target = bdir / ("pango_native_%smhz.fdc" % freq)
            else:
                target = bdir / "pango_native.pcf"
            with target.open("a", encoding="utf-8") as fh:
                fh.write("\n# ---- P13 modular floorplanning (%s) ----\n" % floorplan.name)
                fh.write(floorplan.read_text(encoding="utf-8"))
        lines.append("add_constraint \"%s\"" % (bdir / "pango_native.pcf").as_posix())
        # The place-and-route action is `pnr`, not `place_route`: the latter is a
        # report directory name, and calling it as a command aborts the flow with
        # `invalid command name "place_route"` *after* dev_map, i.e. it looks like
        # a successful synthesis plus a silent failure.  The hold-fix argument set
        # is the one the delivered build uses (platform/pango_native/build.tcl);
        # nothing in it relaxes a constraint, it only asks for more hold fixing.
        pr = ["pnr"]
        if not plain_pnr:
            pr += ["-fix_hold_violation_threshold", "0",
                   "-fix_hold_violation_threshold_for_clk_tree", "0",
                   "-fix_hold_violation_threshold_for_clock_path_cross_srb", "0",
                   "-fix_hold_violation_iterations", "50",
                   "-fix_hold_violation_in_route", "TRUE"]
        if seed is not None:
            pr += ["-seed", str(seed)]
        if place_db is not None:
            # Two-step flow (P60): place once under a MUCH tighter period than
            # the one we intend to ship, then route that placement under the
            # real period.
            #
            # Why: the placer's effort is driven by the SDC period, not by
            # -place_worst_slack (measured: asking for +8 ns at 55 MHz gave a
            # WORSE placement, 17.18 ns, than the default 16.93 ns, while the
            # same netlist constrained at 120 MHz placed at 14.07 ns).  So the
            # only way to get the 14 ns placement while shipping a 55 MHz
            # implementation is to place at 120 and route at 55.
            pr += ["-input_place_db_file", Path(place_db).as_posix()]
        if pnr_extra:
            pr += pnr_extra.split()
        # place_only: stop after placement.  At constraints where routing never
        # converges (120 MHz, P13) the router spins forever and the only
        # comparable number is the placement WNS -- a half-routed WNS is not a
        # measurement (mistakes-log 34).  `pnr -place_only` is a documented pnr
        # flag ("Place Only"), so the same action/hold args stay in place.
        if place_only:
            pr += ["-place_only"]
        lines.append(" ".join(pr))
        if place_only:
            # Placement-only builds stop here on purpose: `report_timing` reads
            # the PnR database only (no route => no .rtr), and there is no
            # bitstream to generate.  The placement WNS/TNS is already printed
            # by pnr itself ("Worst slack ... after placement") in run.log.
            lines.append("puts \"PLACE_ONLY_DONE (pnr -place_only) -- no route, no bitstream\"")
        else:
            lines.append("report_timing")
            lines.append("gen_netlist")
            lines.append("gen_bit_stream")
    else:
        lines.append("report_timing")
    tcl = bdir / "impl.tcl"
    tcl.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return tcl


def run(bdir: Path, tcl: Path, log_name: str) -> int:
    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "no_proxy"):
        env.pop(k, None)
    with (bdir / log_name).open("w", encoding="utf-8", errors="replace") as fh:
        p = subprocess.run([str(PDS_BIN / "pds_shell.exe"), "-file", tcl.name,
                            "-work_dir", ".", "-continue"],
                           cwd=str(bdir), stdout=fh, stderr=subprocess.STDOUT,
                           env=env)
    return p.returncode


def check_image(bdir: Path) -> bool:
    """First iron rule: a bitstream only exists if the hex files were loaded."""
    log = bdir / "run.log"
    if not log.exists():
        print("!! run.log missing")
        return False
    text = log.read_text(encoding="utf-8", errors="replace")
    bad = "Cannot open specified data file" in text
    good = "Loading memory data from file" in text
    print("   image: loading=%s  cannot_open=%s" % (good, bad))
    for m in re.finditer(r"(?:Loading memory data from file|Cannot open specified data file).*",
                         text):
        print("   " + m.group(0).strip()[:120])
    return good and not bad


def pll_check(bdir: Path, freq: str) -> None:
    """Refuse to implement a build whose PLL does not produce the constrained clock.

    This exists because of a real 2-hour loss (P30): two full implementations were
    routed with `--freq 45` and `--freq 50` while `pangoriscv_top.v` still held the
    120.46 MHz ratio (I=1/M=1/F=58/O=13).  The timing verdicts were still valid --
    the .fdc declares the clock on the PLL output pin, and that declaration is what
    the analyser uses -- but the resulting bitstreams would have run at 120 MHz, so
    they were unusable.  Checking is cheap; a wasted route is not.

    Chain: f_out = 27 MHz / I * F / (M * O).
    """
    top = bdir / "sources" / "rtl" / "soc" / "pangoriscv_top.sv"
    txt = top.read_text(encoding="utf-8", errors="ignore")
    v = {}
    for key in ("STATIC_RATIOI", "STATIC_RATIOM", "STATIC_RATIOF", "STATIC_RATIO0"):
        m = re.search(r"\.%s\(\s*([0-9.]+)\s*\)" % key, txt)
        if m:
            v[key] = float(m.group(1))
    if len(v) != 4:
        raise SystemExit("pll: GTP_PPLL instantiation not found in %s" % top)
    mhz = 27.0 / v["STATIC_RATIOI"] * v["STATIC_RATIOF"] / (
        v["STATIC_RATIOM"] * v["STATIC_RATIO0"])
    want = float(freq)
    vco = 27.0 / v["STATIC_RATIOI"] * v["STATIC_RATIOF"] / v["STATIC_RATIOM"]
    print("pll      : I=%g M=%g F=%g O0=%g -> %.4f MHz  (constraint %s MHz, VCO %.1f MHz)"
          % (v["STATIC_RATIOI"], v["STATIC_RATIOM"], v["STATIC_RATIOF"],
             v["STATIC_RATIO0"], mhz, freq, vco))
    if not (1330.0 <= vco <= 2133.0):
        raise SystemExit("pll: VCO %.1f MHz is outside the legal 1330..2133 MHz" % vco)
    if abs(mhz - want) > 0.01 * want:
        raise SystemExit(
            "pll: the RTL produces %.4f MHz but --freq %s was requested.\n"
            "     Set the GTP_PPLL ratios in rtl/soc/pangoriscv_top.v for %s MHz first,\n"
            "     otherwise the analysis is at %s MHz while the bitstream runs at %.4f MHz."
            % (mhz, freq, freq, freq, mhz))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--freq", default="126",
                    choices=["126", "120", "100", "80", "60", "58", "57", "56", "55", "54", "53", "52", "51", "50", "48",
                             "45", "42", "40", "39", "36", "27"])
    ap.add_argument("--mode", default="synth", choices=["synth", "full"])
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--image", default=str(CODE / "build" / "p5_126"))
    ap.add_argument("--floorplan", default=None,
                    help="PCF-format region file (def_region/def_inst_region), "
                         "added as a constraint after dev_map")
    ap.add_argument("--place-only", action="store_true",
                    help="stop after placement (pnr -place_only); for non-routeable constraints")
    ap.add_argument("--pnr-extra", default=None,
                    help="extra pnr args appended verbatim (e.g. "
                         "'-number_of_router_thread 4 -dump_router_congestion_plot TRUE')")
    ap.add_argument("--place-db", default=None,
                    help="route from an existing placement DB (-input_place_db_file). "
                         "Used for the two-step flow: place under a much tighter "
                         "period than the one being shipped, then route under the "
                         "real period with the real constraint file.")
    ap.add_argument("--syn-extra", default=None,
                    help="extra `synthesize` args appended verbatim, e.g. "
                         "'-retiming -fanout_guide 32'. Retiming moves logic "
                         "across existing registers (latency preserved) and is "
                         "the only way to shorten the critical path without "
                         "spending a pipeline stage; always re-run the CoreMark "
                         "and ISA simulations before trusting it.")
    ap.add_argument("--plain-pnr", action="store_true",
                    help="omit the hold-fix pnr args (H1 routing test: do they cause "
                         "rip-up thrash that never converges?)")
    ap.add_argument("--pll-freq", default=None,
                    help="frequency the PLL must actually produce; defaults to --freq. "
                         "Set it only for an over-constraint probe: --freq 55 --pll-freq 52 "
                         "places/routes against 55 MHz while the bitstream runs at 52 MHz. "
                         "A probe build is NOT deliverable evidence -- its report_timing "
                         "verdict belongs to 55 MHz.")
    a = ap.parse_args()

    bdir = stage(a.tag, Path(a.image))
    pll_check(bdir, a.pll_freq or a.freq)
    if a.pll_freq and a.pll_freq != a.freq:
        print("overconstraint probe: RTL runs at %s MHz, timing is checked at %s MHz"
              % (a.pll_freq, a.freq))
    fp = Path(a.floorplan).resolve() if a.floorplan else None
    if fp is not None and not fp.is_file():
        raise SystemExit("floorplan file not found: %s" % fp)
    pdb = Path(a.place_db).resolve() if a.place_db else None
    if pdb is not None and not pdb.is_file():
        raise SystemExit("placement DB not found: %s" % pdb)
    tcl = write_tcl(bdir, a.freq, a.mode, a.seed, floorplan=fp,
                    place_only=a.place_only, pnr_extra=a.pnr_extra,
                    plain_pnr=a.plain_pnr, place_db=pdb,
                    syn_extra=a.syn_extra)
    print("build dir : %s" % bdir)
    print("mode      : %s  freq %s MHz  seed %s" % (a.mode, a.freq, a.seed))
    rc = run(bdir, tcl, "run.log")
    ok = check_image(bdir)
    print("exit      : %s   image %s" % (rc, "OK" if ok else "MISSING"))
    return 0 if ok else 3


if __name__ == "__main__":
    sys.exit(main())
