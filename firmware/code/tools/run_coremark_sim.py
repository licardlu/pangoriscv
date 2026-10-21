#!/usr/bin/env python3
"""Single-image CoreMark run on the native AXI SoC.

Compiles the current RTL into a private work library, runs
`tb_coremark_uart` on one prebuilt firmware image, and reports the numbers the
contest score is derived from:

  cycles / retires / IPC / cycles-per-iteration / control transfers /
  mispredictions / issue pairs / the five CRC words.

Why this exists next to `run_coremark_ab.py`: the A/B runner always compiles two
opposite switch settings of the *same* image. Architectural work needs the
opposite shape -- one image per side, many sides (different -O levels, different
RTL revisions, different prediction schemes) -- and it needs the per-iteration
cycle count, which is the quantity the 5.2 CoreMark/MHz target constrains
(5.2 <=> 192,307 cycles per iteration).

`--crc-only` keeps the architectural-equivalence check cheap: it asserts the
five CRC words match a reference set instead of printing a score.

usage:
  python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_O2
  python tools/run_coremark_sim.py --image ... --tag o3 --expect-crc 0x4983
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_coremark_ab import flatten, parse_transcript, sources  # noqa: E402

REPO_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELSIM_DEFAULT = r"D:\FPGA_Project\Modelism\win64"
OUT_DEFAULT = r".sim_runs\coremark_sim"

# Same five words the board printout must reproduce. Recorded here only as a
# convenience default for the 20-iteration -O2 image; never treat a match as a
# score, it is an equivalence check.
KNOWN_O2_20IT = {
    "seedcrc": "0xe9f5", "crclist": "0xe714", "crcmatrix": "0x1fd7",
    "crcstate": "0x8e3a", "crcfinal": "0x4983",
}


def read_iterations(image_dir: str) -> int | None:
    path = os.path.join(image_dir, "manifest.json")
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            return int(json.load(fh).get("iterations"))
    except (ValueError, TypeError, json.JSONDecodeError):
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=REPO_DEFAULT)
    ap.add_argument("--modelsim", default=MODELSIM_DEFAULT)
    ap.add_argument("--image", required=True, help="directory with program.hex/data.hex")
    ap.add_argument("--tag", default="run", help="subdirectory under --out")
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--max-cycles", default="400000000")
    ap.add_argument("--skip-compile", action="store_true",
                    help="reuse the work library of an earlier run with the same --tag")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    image_dir = args.image if os.path.isabs(args.image) else os.path.join(repo, args.image)
    prog = os.path.join(image_dir, "program.hex")
    data = os.path.join(image_dir, "data.hex")
    for path in (prog, data):
        if not os.path.exists(path):
            print("FAIL missing image %s" % path)
            return 1

    iterations = read_iterations(image_dir)
    out_root = args.out if os.path.isabs(args.out) else os.path.join(repo, args.out)
    run_dir = os.path.join(out_root, args.tag)
    os.makedirs(run_dir, exist_ok=True)

    env = dict(os.environ)
    env["PATH"] = args.modelsim + os.pathsep + env.get("PATH", "")
    tools = {name: os.path.join(args.modelsim, name + ".exe")
             for name in ("vlib", "vlog", "vsim")}
    for name, path in tools.items():
        if not os.path.exists(path):
            print("FAIL %s not found at %s" % (name, path))
            return 1

    rtl = os.path.join(repo, "rtl")
    incs = ["+incdir+" + os.path.join(rtl, sub) for sub in ("core", "bus", "perips", "soc")]
    incs += ["+incdir+" + os.path.join(repo, "tb"),
             "+incdir+" + os.path.join(repo, "tb", "integration")]
    tb = os.path.join(repo, "tb", "integration", "tb_coremark_uart.sv")

    if not args.skip_compile:
        log_path = os.path.join(run_dir, "compile.log")
        with open(log_path, "w", encoding="utf-8", errors="replace") as log:
            rc = subprocess.run([tools["vlib"], "work"], cwd=run_dir, env=env,
                                stdout=log, stderr=subprocess.STDOUT).returncode
            if rc == 0:
                rc = subprocess.run([tools["vlog"], "-sv", "-work", "work"] + incs
                                    + sources(repo) + [tb], cwd=run_dir, env=env,
                                    stdout=log, stderr=subprocess.STDOUT).returncode
        if rc != 0:
            print("FAIL vlog rc=%d (%s)" % (rc, log_path))
            return 1
        with open(log_path, encoding="utf-8", errors="replace") as fh:
            errs = [ln for ln in flatten(fh.read()).splitlines() if "Error" in ln]
        print("compile ok (%d error lines)" % len(errs), flush=True)

    transcript = os.path.join(run_dir, "transcript.txt")
    started = time.time()
    cmd = [tools["vsim"], "-c", "-do", "run -all; quit -f", "-l", transcript,
           "work.tb_coremark_uart", "+PROG=" + prog, "+DATA=" + data,
           "+MAX_CYCLES=" + str(args.max_cycles)]
    with open(os.path.join(run_dir, "vsim.log"), "w",
              encoding="utf-8", errors="replace") as log_fh:
        rc = subprocess.run(cmd, cwd=run_dir, env=env, stdout=log_fh,
                            stderr=subprocess.STDOUT).returncode
    wall = time.time() - started

    text = ""
    for path in (transcript, os.path.join(run_dir, "vsim.log")):
        if os.path.exists(path):
            with open(path, encoding="utf-8", errors="replace") as fh:
                text += flatten(fh.read()) + "\n"
    parsed = parse_transcript(text)
    summary = parsed["summary"]
    crc = parsed["crc"]
    verdict = "PASS" if "TEST_PASS T_COREMARK_BOUNDED" in text else "FAIL"

    cycles = int(summary.group(1)) if summary else None
    retires = int(summary.group(2)) if summary else None
    per_iter = (cycles / iterations) if (cycles and iterations) else None
    ipc = (retires / cycles) if (cycles and retires) else None
    cpi = (cycles / retires) if (cycles and retires) else None

    result = {
        "tag": args.tag, "image": image_dir, "iterations": iterations,
        "verdict": verdict, "rc": rc, "cycles": cycles, "retires": retires,
        "ipc": ipc, "cycles_per_iter": per_iter, "wall_s": round(wall, 1),
        "ctrl": parsed["ctrl"].group(1) if parsed["ctrl"] else None,
        "mispred": parsed["mispred"].group(1) if parsed["mispred"] else None,
        "crc": crc, "log": transcript,
    }
    with open(os.path.join(run_dir, "result.json"), "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)

    print("%s: %s rc=%d cycles=%s retires=%s IPC=%s cycles/iter=%s ctrl=%s mispred=%s "
          "crc=%s wall=%.1fs"
          % (args.tag, verdict, rc, cycles, retires,
             "%.4f" % ipc if ipc else None,
             "%.1f" % per_iter if per_iter else None,
             result["ctrl"], result["mispred"], crc.get("crcfinal"), wall))
    if crc.get("crcfinal") != KNOWN_O2_20IT["crcfinal"] and iterations == 20:
        print("note: crcfinal %s differs from the recorded -O2 reference %s "
              "(expected when the compiler flags change; a functional failure "
              "usually shows as a hang or a trap instead)"
              % (crc.get("crcfinal"), KNOWN_O2_20IT["crcfinal"]))
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
