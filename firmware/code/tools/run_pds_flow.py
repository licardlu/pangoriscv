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


def write_tcl(bdir: Path, freq: str, mode: str, seed: int | None) -> Path:
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
        "synthesize -ads -selected_syn_tool_opt 2",
        "dev_map",
    ]
    if mode == "full":
        lines.append("add_constraint \"%s\"" % (bdir / "pango_native.pcf").as_posix())
        # The place-and-route action is `pnr`, not `place_route`: the latter is a
        # report directory name, and calling it as a command aborts the flow with
        # `invalid command name "place_route"` *after* dev_map, i.e. it looks like
        # a successful synthesis plus a silent failure.  The hold-fix argument set
        # is the one the delivered build uses (platform/pango_native/build.tcl);
        # nothing in it relaxes a constraint, it only asks for more hold fixing.
        pr = ["pnr",
              "-fix_hold_violation_threshold", "0",
              "-fix_hold_violation_threshold_for_clk_tree", "0",
              "-fix_hold_violation_threshold_for_clock_path_cross_srb", "0",
              "-fix_hold_violation_iterations", "50",
              "-fix_hold_violation_in_route", "TRUE"]
        if seed is not None:
            pr += ["-seed", str(seed)]
        lines.append(" ".join(pr))
        lines.append("report_timing")
        lines.append("gen_netlist")
        lines.append("bit_gen")
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--freq", default="126", choices=["126", "27", "50", "40"])
    ap.add_argument("--mode", default="synth", choices=["synth", "full"])
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--image", default=str(CODE / "build" / "p5_126"))
    a = ap.parse_args()

    bdir = stage(a.tag, Path(a.image))
    tcl = write_tcl(bdir, a.freq, a.mode, a.seed)
    print("build dir : %s" % bdir)
    print("mode      : %s  freq %s MHz  seed %s" % (a.mode, a.freq, a.seed))
    rc = run(bdir, tcl, "run.log")
    ok = check_image(bdir)
    print("exit      : %s   image %s" % (rc, "OK" if ok else "MISSING"))
    return 0 if ok else 3


if __name__ == "__main__":
    sys.exit(main())
