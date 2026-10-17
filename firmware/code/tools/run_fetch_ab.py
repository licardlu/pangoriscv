#!/usr/bin/env python3
"""A/B runner for fetch-front-end work.

Runs the *identical* firmware image on the *identical* testbench twice: once from
the working tree and once with a listed set of RTL files taken from a git
revision.  Everything else -- image, testbench, include path, plusargs -- is
shared, so the only difference between the two runs is the RTL under test.

This is verification tooling: it never modifies RTL, software or constraints.  The
baseline side is materialised into a scratch directory with `git show`, so the
working tree is untouched.

Reported per side: Total ticks, cycles, retires, IPC, the five CoreMark CRCs, the
trap/fault counts, the perf counters (when the image is built with -DPERF_DUMP)
and the testbench's EX/MEM/STORE decomposition.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_coremark_ab import flatten, uart_stream  # noqa: E402

REPO_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELSIM_DEFAULT = r"D:\FPGA_Project\Modelism\win64"
OUT_DEFAULT = r"build\fetch_ab"
IMAGE_DEFAULT = r"build\native_software\coremark\performance\perf_on"

TICKS = re.compile(r"Total ticks\s*:\s*(\d+)")
SUMMARY = re.compile(r"CORE_SUMMARY cycles=(\d+) retires=(\d+) traps=(\d+) faults=(\d+)")
PERF = re.compile(r"^\s*#?\s*P (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)\s*$",
                  re.M)
STORE = re.compile(r"STORE_PATH st_wr_req=(\d+) st_wr_resp=(\d+) st_wr_hold=(\d+) st_total=(\d+)")


def sources(repo: str):
    out = []
    with open(os.path.join(repo, "sim", "native_axi_sources.f"), encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("//"):
                continue
            out.append(os.path.join(repo, line.replace("/", os.sep)))
    return out


def rel_key(repo: str, path: str) -> str:
    return os.path.relpath(path, repo).replace("\\", "/")


def build(repo, modelsim, side, run_dir, files, rev, image_dir, max_cycles):
    """Compile one side and return (rc, log_path)."""
    os.makedirs(run_dir, exist_ok=True)
    srcs = sources(repo)
    if rev:
        base_dir = os.path.join(run_dir, "baseline_src")
        os.makedirs(base_dir, exist_ok=True)
        patched = {}
        for rel in files:
            dump = subprocess.run(
                # `./` makes the path relative to the directory git runs in, so a
                # repository whose sources live below the git root still works.
                ["git", "-C", repo, "show", "%s:./%s" % (rev, rel)],
                capture_output=True, text=True, check=True).stdout
            target = os.path.join(base_dir, rel.replace("/", "__"))
            with open(target, "w", encoding="ascii", newline="") as fh:
                fh.write(dump)
            patched[rel] = target
            print("  baseline %s (%d bytes)" % (rel, len(dump)), flush=True)
        srcs = [patched.get(rel_key(repo, s), s) for s in srcs]

    rtl = os.path.join(repo, "rtl")
    incs = ["+incdir+" + os.path.join(rtl, sub) for sub in ("core", "bus", "perips", "soc")]
    incs += ["+incdir+" + os.path.join(repo, "tb"),
             "+incdir+" + os.path.join(repo, "tb", "integration")]
    tb = os.path.join(repo, "tb", "integration", "tb_coremark_uart.sv")

    env = dict(os.environ)
    env["PATH"] = modelsim + os.pathsep + env.get("PATH", "")
    tools = {name: os.path.join(modelsim, name + ".exe")
             for name in ("vlib", "vlog", "vsim")}
    for name, path in tools.items():
        if not os.path.exists(path):
            raise SystemExit("FAIL %s not found at %s" % (name, path))

    log_path = os.path.join(run_dir, "compile.log")
    with open(log_path, "w", encoding="utf-8", errors="replace") as log:
        rc = subprocess.run([tools["vlib"], "work"], cwd=run_dir, env=env,
                            stdout=log, stderr=subprocess.STDOUT).returncode
        if rc != 0:
            return rc, log_path
        rc = subprocess.run([tools["vlog"], "-sv", "-work", "work"] + incs + srcs + [tb],
                            cwd=run_dir, env=env,
                            stdout=log, stderr=subprocess.STDOUT).returncode
    return rc, log_path


def launch(repo, modelsim, run_dir, image_dir, max_cycles):
    env = dict(os.environ)
    env["PATH"] = modelsim + os.pathsep + env.get("PATH", "")
    vsim = os.path.join(modelsim, "vsim.exe")
    transcript = os.path.join(run_dir, "transcript.txt")
    cmd = [vsim, "-c", "-do", "run -all; quit -f", "-l", transcript,
           "work.tb_coremark_uart",
           "+PROG=" + os.path.join(image_dir, "program.hex"),
           "+DATA=" + os.path.join(image_dir, "data.hex"),
           "+MAX_CYCLES=" + str(max_cycles)]
    log_fh = open(os.path.join(run_dir, "vsim.log"), "w",
                  encoding="utf-8", errors="replace")
    proc = subprocess.Popen(cmd, cwd=run_dir, env=env, stdout=log_fh,
                            stderr=subprocess.STDOUT, text=True)
    return proc, log_fh, transcript


def parse(run_dir, transcript):
    out = ""
    vsim_log = os.path.join(run_dir, "vsim.log")
    if os.path.exists(vsim_log):
        with open(vsim_log, encoding="utf-8", errors="replace") as fh:
            out = fh.read()
    text = ""
    if os.path.exists(transcript):
        with open(transcript, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    flat = flatten(text) + "\n" + flatten(out)
    stream = uart_stream(flat)
    entry = {"verdict": "PASS" if "TEST_PASS T_COREMARK_BOUNDED" in flat else "FAIL",
             "validated": "Correct operation validated" in stream,
             "error_line": "Errors detected" in stream,
             # A short A/B image necessarily trips CoreMark's ">= 10 s" rule, which
             # prints "ERROR! Must execute for at least 10 secs" and makes
             # total_errors nonzero (so "Correct operation validated" is skipped).
             # That is expected here and identical on both sides; the CRC chain is
             # what the A/B compares.
             "under_10s": "at least 10 secs" in stream}
    m = TICKS.search(stream)
    entry["ticks"] = int(m.group(1)) if m else None
    m = SUMMARY.search(flat)
    entry["cycles"] = int(m.group(1)) if m else None
    entry["retires"] = int(m.group(2)) if m else None
    entry["traps"] = int(m.group(3)) if m else None
    entry["faults"] = int(m.group(4)) if m else None
    m = PERF.search(flat)
    if m:
        keys = ("cycle", "instret", "if_wait", "lsu_wait",
                "i_miss", "d_miss", "ret_cf", "mispred")
        entry["perf"] = dict(zip(keys, (int(v) for v in m.groups())))
    m = STORE.search(flat)
    if m:
        entry["store"] = dict(zip(("req", "resp", "hold", "total"),
                                  (int(v) for v in m.groups())))
    entry["crc"] = {k: (re.search(r"\]?" + k + r"\s*:\s*(0x[0-9a-fA-F]+)", stream)
                        or [None, None])[1]
                    for k in ("seedcrc", "crclist", "crcmatrix", "crcstate", "crcfinal")}
    return entry


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=REPO_DEFAULT)
    ap.add_argument("--modelsim", default=MODELSIM_DEFAULT)
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--image-dir", default=IMAGE_DEFAULT)
    ap.add_argument("--baseline-rev", required=True,
                    help="git revision the baseline side is taken from")
    ap.add_argument("--files", nargs="+", required=True,
                    help="RTL files replaced by the baseline revision (repo-relative)")
    ap.add_argument("--max-cycles", default="40000000")
    ap.add_argument("--sides", choices=("both", "base", "work"), default="both")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    out = os.path.abspath(args.out)
    image_dir = args.image_dir
    if not os.path.isabs(image_dir):
        image_dir = os.path.join(repo, image_dir)
    for name in ("program.hex", "data.hex"):
        path = os.path.join(image_dir, name)
        if not os.path.exists(path):
            print("FAIL missing image %s" % path)
            return 1

    sides = [("base", args.baseline_rev), ("work", None)]
    if args.sides != "both":
        sides = [s for s in sides if s[0] == args.sides]

    for tag, rev in sides:
        run_dir = os.path.join(out, tag)
        print("=== compile %s (%s) ===" % (tag, "baseline " + rev if rev else "working tree"),
              flush=True)
        rc, log_path = build(repo, args.modelsim, tag, run_dir, args.files, rev,
                             image_dir, args.max_cycles)
        if rc != 0:
            print("FAIL vlog rc=%d (%s)" % (rc, log_path))
            return 1
        with open(log_path, encoding="utf-8", errors="replace") as fh:
            errors = [ln for ln in flatten(fh.read()).splitlines() if "Error" in ln]
        print("  compile ok, %d error lines" % len(errors), flush=True)

    procs = []
    started = time.time()
    for tag, _rev in sides:
        run_dir = os.path.join(out, tag)
        print("=== run %s ===" % tag, flush=True)
        procs.append((tag, run_dir) + launch(repo, args.modelsim, run_dir,
                                             image_dir, args.max_cycles))
    results = {}
    for tag, run_dir, proc, log_fh, transcript in procs:
        proc.wait()
        log_fh.close()
        results[tag] = parse(run_dir, transcript)

    lines = ["CoreMark fetch A/B (image %s)" % image_dir,
             "baseline revision %s; replaced files: %s"
             % (args.baseline_rev, ", ".join(args.files)),
             "wall clock %.1f min" % ((time.time() - started) / 60.0), ""]
    for tag, _rev in sides:
        e = results[tag]
        ipc = (float(e["retires"]) / e["cycles"]) if e["cycles"] and e["retires"] else 0.0
        lines.append("%-5s %s ticks=%s cycles=%s retires=%s IPC=%.4f"
                     % (tag, e["verdict"], e["ticks"], e["cycles"],
                        e["retires"], ipc))
        lines.append("      validated=%s under-10s-rule=%s%s"
                     % (e["validated"], e["under_10s"],
                        "  (expected for a short A/B image; CRCs are the check)"
                        if e["under_10s"] else ""))
        lines.append("      crc seed=%s list=%s matrix=%s state=%s final=%s"
                     % (e["crc"]["seedcrc"], e["crc"]["crclist"], e["crc"]["crcmatrix"],
                        e["crc"]["crcstate"], e["crc"]["crcfinal"]))
        lines.append("      traps=%s faults=%s" % (e["traps"], e["faults"]))
        if "perf" in e:
            p = e["perf"]
            lines.append("      perf cycle=%d instret=%d if_wait=%d lsu_wait=%d "
                         "i_miss=%d d_miss=%d ret_cf=%d mispred=%d"
                         % (p["cycle"], p["instret"], p["if_wait"], p["lsu_wait"],
                            p["i_miss"], p["d_miss"], p["ret_cf"], p["mispred"]))
        if "store" in e:
            s = e["store"]
            lines.append("      store req=%d resp=%d hold=%d total=%d"
                         % (s["req"], s["resp"], s["hold"], s["total"]))

    base, work = results.get("base"), results.get("work")
    if base and work:
        lines.append("")
        if base["ticks"] and work["ticks"]:
            lines.append("ticks %d -> %d (%+.2f%%)"
                         % (base["ticks"], work["ticks"],
                            100.0 * (work["ticks"] - base["ticks"]) / base["ticks"]))
        if base["cycles"] and work["cycles"]:
            lines.append("cycles %d -> %d (%+.2f%%)"
                         % (base["cycles"], work["cycles"],
                            100.0 * (work["cycles"] - base["cycles"]) / base["cycles"]))
        if base.get("perf") and work.get("perf"):
            for key in ("if_wait", "i_miss", "lsu_wait", "d_miss", "ret_cf", "mispred"):
                b, w = base["perf"][key], work["perf"][key]
                delta = ("%+.2f%%" % (100.0 * (w - b) / b)) if b else "n/a"
                lines.append("perf %-8s %d -> %d (%s)" % (key, b, w, delta))
        both = [k for k in base["crc"] if base["crc"][k] and work["crc"][k]]
        diff = [k for k in both if base["crc"][k] != work["crc"][k]]
        lines.append("CRC compared: %s" % (", ".join(both) or "none"))
        lines.append("CRC differs: %s" % (", ".join(diff) or "none"))
        lines.append("architectural transparency: %s"
                     % ("PASS" if both and not diff else "FAIL"))
    report = os.path.join(out, "report.txt")
    os.makedirs(out, exist_ok=True)
    with open(report, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
