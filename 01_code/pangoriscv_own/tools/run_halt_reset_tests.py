#!/usr/bin/env python3
"""Halt / reset drain regression for the native AXI SoC.

Assembles tests/halt_reset/halt_reset.S with the contest toolchain, converts it
to a ModelSim $readmemh word image, compiles the native manifest plus
tb/integration/tb_halt_reset_drain.sv and runs one simulation per scenario:

  1 halt   while a data read  is in flight
  2 halt   while a data write is in flight
  3 reset  while a data read  is in flight
  4 reset  while a data write is in flight
  5 reset  while the bus is idle

Each scenario must print exactly one `TEST_PASS HALT_RESET_DRAIN scen=<n>` and
no HR_FAIL / TEST_FAIL / HR_TIMEOUT line.

This is verification tooling only: it does not modify RTL, software or
constraints.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TOOLCHAIN = Path(
    r"E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin"
)
DEFAULT_MODELSIM = Path(r"E:\donwload\win64")

SCENARIO = {
    1: "halt during an in-flight data read",
    2: "halt during an in-flight data write",
    3: "reset during an in-flight data read",
    4: "reset during an in-flight data write",
    5: "reset while the bus is idle",
}

PROG_WORDS = 4096


def run(cmd, log_path, timeout=900):
    with open(log_path, "w", encoding="utf-8", errors="replace") as fh:
        fh.write("$ " + " ".join(str(c) for c in cmd) + "\n")
        fh.flush()
        proc = subprocess.run(
            [str(c) for c in cmd], stdout=fh, stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    return proc.returncode


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenarios", default="all",
                    help="'all' or a comma separated list such as 1,3,5")
    ap.add_argument("--toolchain-bin", type=Path, default=DEFAULT_TOOLCHAIN)
    ap.add_argument("--modelsim", type=Path, default=DEFAULT_MODELSIM)
    ap.add_argument("--out", type=Path, default=None,
                    help="evidence directory (default: a fresh .sim_runs dir)")
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()

    if args.scenarios == "all":
        scenarios = sorted(SCENARIO)
    else:
        scenarios = [int(x) for x in args.scenarios.split(",") if x.strip()]

    gcc = args.toolchain_bin / "riscv32-unknown-elf-gcc.exe"
    objcopy = args.toolchain_bin / "riscv32-unknown-elf-objcopy.exe"
    objdump = args.toolchain_bin / "riscv32-unknown-elf-objdump.exe"
    for tool in (gcc, objcopy, objdump):
        if not tool.exists():
            print(f"FAIL: toolchain tool missing: {tool}")
            return 1

    if args.out:
        work_dir = args.out
        work_dir.mkdir(parents=True, exist_ok=True)
    else:
        work_dir = Path(tempfile.mkdtemp(prefix="halt-reset-",
                                         dir=ROOT / ".sim_runs"))
    print(f"work dir: {work_dir}")

    vlib = args.modelsim / "vlib.exe"
    vmap = args.modelsim / "vmap.exe"
    vlog = args.modelsim / "vlog.exe"
    vsim = args.modelsim / "vsim.exe"

    src = ROOT / "tests" / "halt_reset" / "halt_reset.S"
    ld = ROOT / "tests" / "halt_reset" / "link.ld"
    elf = work_dir / "halt_reset.elf"
    raw = work_dir / "halt_reset.bin"

    rc = run([gcc, "-march=rv32im", "-mabi=ilp32", "-nostdlib", "-nostartfiles",
              "-static", "-Wl,--no-relax", "-T", str(ld), "-e", "_start",
              str(src), "-o", str(elf)],
             work_dir / "build.log")
    if rc != 0:
        print("ASSEMBLE FAILED - see", work_dir / "build.log")
        return 1

    rc = run([objdump, "-d", str(elf)], work_dir / "objdump.log")
    if rc != 0:
        print("OBJDUMP FAILED")
        return 1
    disasm = (work_dir / "objdump.log").read_text(errors="replace")
    # A compressed instruction disassembles as a two-byte cell with a mnemonic;
    # a data word does not. Anything that looks like that is a hard failure
    # because the CPU has no C extension.
    c_insns = [ln for ln in disasm.splitlines()
               if re.match(r"\s+[0-9a-f]+: [0-9a-f]{4} [a-z]", ln)]
    if c_insns:
        print(f"FAIL: {len(c_insns)} compressed-looking instructions")
        return 1
    print("image check: no compressed instructions")

    rc = run([objcopy, "-O", "binary", str(elf), str(raw)],
             work_dir / "objcopy_bin.log")
    if rc != 0:
        print("OBJCOPY FAILED")
        return 1
    image = raw.read_bytes()
    if len(image) > 16384:
        print(f"FAIL: image is {len(image)} bytes, program RAM is 16384")
        return 1
    print(f"image: {len(image)} bytes of 16384")

    padded = image + b"\x00" * ((4 - len(image) % 4) % 4)
    words = [int.from_bytes(padded[o:o + 4], "little")
             for o in range(0, len(padded), 4)]
    while len(words) < PROG_WORDS:
        words.append(0x00000013)  # NOP
    image_file = work_dir / "halt_reset.hex"
    image_file.write_text("\n".join(f"{w:08x}" for w in words) + "\n",
                          encoding="ascii")

    lib = work_dir / "work"
    rc = run([vlib, str(lib)], work_dir / "vlib.log")
    run([vmap, "work", str(lib)], work_dir / "vmap.log")
    if rc != 0:
        print("VLIB FAILED")
        return 1
    manifest = ROOT / "sim" / "native_axi_sources.f"
    rc = run([vlog, "-sv", "-work", str(lib),
              f"+incdir+{ROOT/'rtl'/'core'}", f"+incdir+{ROOT/'rtl'/'soc'}",
              "-f", str(manifest),
              str(ROOT / "tb" / "integration" / "tb_halt_reset_drain.sv")],
             work_dir / "compile.log")
    compile_text = (work_dir / "compile.log").read_text(errors="replace")
    if rc != 0 or "** Error" in compile_text:
        print("COMPILE FAILED - see", work_dir / "compile.log")
        for ln in compile_text.splitlines():
            if "** Error" in ln:
                print("  " + ln)
        return 1
    print("compile: 0 errors" if "Errors: 0" in compile_text else "compile: ok")

    passed = 0
    failed = []
    for scen in scenarios:
        log = work_dir / f"scen{scen}.log"
        cmd = [vsim, "-c", "-lib", str(lib), "work.tb_halt_reset_drain",
               "-do", "run -all; quit -f", "-l", str(log),
               f"+SCEN={scen}",
               f"+PROG={image_file}", f"+DATA={image_file}"]
        rc = run(cmd, work_dir / f"scen{scen}.cmd.log", timeout=1800)
        text = log.read_text(errors="replace") if log.exists() else ""
        problems = []
        n_pass = len(re.findall(rf"TEST_PASS HALT_RESET_DRAIN scen={scen}\b",
                                text))
        if n_pass != 1:
            problems.append(f"{n_pass} pass markers")
        for bad in ("HR_FAIL", "TEST_FAIL", "HR_TIMEOUT", "** Error", "** Fatal"):
            if bad in text:
                problems.append(bad)
        if rc != 0:
            problems.append(f"vsim exit {rc}")
        if problems:
            failed.append(scen)
            print(f"  scenario {scen}: FAIL ({', '.join(problems)})")
            for ln in text.splitlines():
                if ln.startswith("HR_") or ln.startswith("TEST_"):
                    print("      " + ln)
        else:
            passed += 1
            drain = [ln for ln in text.splitlines() if ln.startswith("HR_")]
            print(f"  scenario {scen}: PASS - {SCENARIO[scen]}")
            for ln in drain:
                print("      " + ln)

    print(f"SUMMARY {passed} / {len(scenarios)} PASS")
    if failed:
        print("failed scenarios: " + ", ".join(str(s) for s in failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
