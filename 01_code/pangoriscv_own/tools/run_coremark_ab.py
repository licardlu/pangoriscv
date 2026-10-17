#!/usr/bin/env python3
"""A/B evidence runner: run the *identical* CoreMark firmware image on the native
AXI SoC twice -- once with one feature define enabled and once without it -- and
compare cycles, retires, IPC, the branch statistics reported by the testbench
and the CoreMark CRC chain.  The CRC chain is the architectural-equivalence
check: it must be byte-identical between the two runs or the feature is not
transparent.

`--switch` selects the feature:

  CACHE    `CACHE_ENABLE`   (N13 two-way I/D caches + INCR bursts)
  PREDICT  `PREDICT_ENABLE` (N14 dynamic branch predictor; caches stay on)

The two designs are compiled into separate work libraries first (the
soc_config.vh toggle is flipped and restored around each compile), so the two
long simulations can then run concurrently.

This is verification tooling: it does not modify RTL, software or constraints.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time

REPO_DEFAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # this package root
MODELSIM_DEFAULT = r"E:\donwload\win64"
OUT_DEFAULT = r"build\coremark_ab"

# --switch value -> (define name in rtl/core/soc_config.vh, label prefix)
SWITCHES = {
    "CACHE": ("CACHE_ENABLE", "cache"),
    "PREDICT": ("PREDICT_ENABLE", "predict"),
}


# Testbench / simulator control lines inside a ModelSim transcript.  They are not
# anchored: the testbench prints the UART stream one character at a time and
# interleaves these lines with it, so a control marker can appear *after* the
# first character(s) of a printed line (e.g. "[0]crcs" + "PROGRESS cycles=...").
_CONTROL = re.compile(
    r"(LIVE |PROGRESS |CORE_SUMMARY|CORE_REPORT_SEEN|TEST_PASS|TEST_FAIL|"
    r"Errors:|Warnings:|\*\* |Time:|End time|Start time|Loading|vsim |Break|"
    r"Iteration:)")


def flatten(text: str) -> str:
    return "\n".join(line.split("//")[0] for line in text.splitlines())


def uart_stream(text: str) -> str:
    """Rebuild the simulated UART character stream from a transcript.

    Every transcript line is prefixed with "# "; the testbench then interleaves
    its own control lines with the UART stream it prints character by character,
    so a control marker can split a payload line in two ("[0]crcs" +
    "PROGRESS cycles=..." + "tate      : 0x8e3a").  Text before the first control
    marker is kept; when that happens the next fragment continues the same
    logical line, otherwise the transcript line end is treated as a line end so
    adjacent printed fields never merge (which produced "0x382fC" from
    "0x382f" followed by "Correct operation validated").
    """
    parts = []
    continuing = False
    for line in text.splitlines():
        body = line.strip()
        if body.startswith("# "):
            body = body[2:]
        elif body == "#":
            body = ""
        cut = _CONTROL.search(body)
        if cut:
            body = body[:cut.start()]
            split = True
        else:
            split = False
        parts.append(body if continuing else "\n" + body)
        continuing = split
    return "".join(parts)


def parse_transcript(text: str) -> dict:
    """Extract the CoreMark summary, branch statistics and CRC chain.

    The branch statistics must come from the testbench's CORE_SUMMARY line: a
    plain "ctrl=" search also matches "uart_ctrl=00000003" in a LIVE line, which
    reported ctrl=3 and a nonsensical misprediction rate.
    """
    stream = uart_stream(text)
    summary_line = next((ln for ln in text.splitlines()
                         if "CORE_SUMMARY" in ln), "")
    return {
        "stream": stream,
        "summary": re.search(r"CORE_SUMMARY cycles=(\d+) retires=(\d+)",
                             summary_line),
        "ctrl": re.search(r"\bctrl=(\d+)", summary_line),
        "mispred": re.search(r"\bmispred=(\d+)", summary_line),
        "crc": {key: (re.search(r"\]?" + key + r"\s*:\s*(0x[0-9a-fA-F]+)",
                                stream) or [None, None])[1]
                for key in ("seedcrc", "crclist", "crcmatrix", "crcstate",
                            "crcfinal")},
    }


def set_define(path: str, name: str, enable: bool) -> str:
    on = "`define " + name
    off = "// `define " + name
    with open(path, encoding="utf-8") as fh:
        original = fh.read()
    if enable:
        updated = re.sub(r"(?m)^//[ \t]*`define " + name + r"[ \t]*$", on, original)
        updated = re.sub(r"(?m)^`define " + name + r"[ \t]*$", on, updated)
    else:
        updated = re.sub(r"(?m)^`define " + name + r"[ \t]*$", off, original)
    active = re.search(r"(?m)^`define " + name + r"[ \t]*$", updated) is not None
    if active != enable:
        restore(path, original)
        raise SystemExit("%s could not be set to %s in %s" % (name, enable, path))
    if updated != original:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(updated)
    return original


def restore(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def sources(repo: str):
    out = []
    with open(os.path.join(repo, "sim", "native_axi_sources.f"), encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("//"):
                continue
            out.append(os.path.join(repo, line.replace("/", os.sep)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=REPO_DEFAULT)
    ap.add_argument("--modelsim", default=MODELSIM_DEFAULT)
    ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument(
        "--image-dir",
        default=r"build\native_software\coremark\performance",
    )
    ap.add_argument("--max-cycles", default="700000000")
    ap.add_argument("--switch", choices=sorted(SWITCHES), default="CACHE")
    ap.add_argument("--sides", choices=("both", "on", "off"), default="both",
                    help="run both sides (default) or only the on/off side")
    args = ap.parse_args()

    define_name, prefix = SWITCHES[args.switch]
    # vsim runs with cwd=<run dir>, so every path handed to it must be absolute.
    args.out = os.path.abspath(args.out)
    configs = ((prefix + "_on", True), (prefix + "_off", False))
    if args.sides != "both":
        configs = tuple(cfg for cfg in configs if cfg[0].endswith("_" + args.sides))

    repo = os.path.abspath(args.repo)
    image_dir = args.image_dir
    if not os.path.isabs(image_dir):
        image_dir = os.path.join(repo, image_dir)
    prog = os.path.join(image_dir, "program.hex")
    data = os.path.join(image_dir, "data.hex")
    for path in (prog, data):
        if not os.path.exists(path):
            print("FAIL missing image %s" % path)
            return 1

    cfg = os.path.join(repo, "rtl", "core", "soc_config.vh")
    tb = os.path.join(repo, "tb", "integration", "tb_coremark_uart.sv")
    rtl = os.path.join(repo, "rtl")
    incs = []
    for sub in ("core", "bus", "perips", "soc"):
        incs.append("+incdir+" + os.path.join(rtl, sub))
    incs.append("+incdir+" + os.path.join(repo, "tb"))
    incs.append("+incdir+" + os.path.join(repo, "tb", "integration"))
    srcs = sources(repo)

    env = dict(os.environ)
    env["PATH"] = args.modelsim + os.pathsep + env.get("PATH", "")
    tools = {name: os.path.join(args.modelsim, name + ".exe")
             for name in ("vlib", "vlog", "vsim")}
    for name, path in tools.items():
        if not os.path.exists(path):
            print("FAIL %s not found at %s" % (name, path))
            return 1

    os.makedirs(args.out, exist_ok=True)

    for tag, enable in configs:
        run_dir = os.path.join(args.out, tag)
        os.makedirs(run_dir, exist_ok=True)
        log_path = os.path.join(run_dir, "compile.log")
        print("=== compile %s (%s=%s) ===" % (tag, define_name, enable), flush=True)
        original = set_define(cfg, define_name, enable)
        try:
            with open(log_path, "w", encoding="utf-8", errors="replace") as log:
                rc = subprocess.run([tools["vlib"], "work"], cwd=run_dir, env=env,
                                    stdout=log, stderr=subprocess.STDOUT).returncode
                if rc != 0:
                    print("FAIL vlib rc=%d (%s)" % (rc, log_path))
                    return 1
                rc = subprocess.run([tools["vlog"], "-sv", "-work", "work"] + incs
                                    + srcs + [tb], cwd=run_dir, env=env,
                                    stdout=log, stderr=subprocess.STDOUT).returncode
        finally:
            restore(cfg, original)
        if rc != 0:
            print("FAIL vlog rc=%d (%s)" % (rc, log_path))
            return 1
        with open(log_path, encoding="utf-8", errors="replace") as fh:
            errors = [ln for ln in flatten(fh.read()).splitlines() if "Error" in ln]
        print("  compile ok, %d error lines" % len(errors), flush=True)

    # Both libraries are built: start the two long simulations together.
    # Each side writes straight into its own vsim.log: piping stdout into the
    # parent and draining the pipes one side after the other deadlocks the
    # second simulation as soon as its pipe buffer fills up.
    procs = []
    for tag, _enable in configs:
        run_dir = os.path.join(args.out, tag)
        transcript = os.path.join(run_dir, "transcript.txt")
        vsim_log = os.path.join(run_dir, "vsim.log")
        cmd = [tools["vsim"], "-c", "-do", "run -all; quit -f", "-l", transcript,
               "work.tb_coremark_uart", "+PROG=" + prog, "+DATA=" + data,
               "+MAX_CYCLES=" + str(args.max_cycles)]
        print("=== run %s ===" % tag, flush=True)
        log_fh = open(vsim_log, "w", encoding="utf-8", errors="replace")
        procs.append((tag, run_dir, transcript, vsim_log, log_fh,
                      subprocess.Popen(cmd, cwd=run_dir, env=env,
                                       stdout=log_fh, stderr=subprocess.STDOUT,
                                       text=True)))
    started = time.time()
    results = {}
    for tag, run_dir, transcript, vsim_log, log_fh, proc in procs:
        rc = proc.wait()
        log_fh.close()
        out = ""
        if os.path.exists(vsim_log):
            with open(vsim_log, encoding="utf-8", errors="replace") as fh:
                out = fh.read()
        text = ""
        if os.path.exists(transcript):
            with open(transcript, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        text = flatten(text) + "\n" + flatten(out or "")
        parsed = parse_transcript(text)
        summary_m, ctrl_m = parsed["summary"], parsed["ctrl"]
        miss_m, crc = parsed["mispred"], parsed["crc"]
        verdict = "PASS" if "TEST_PASS T_COREMARK_BOUNDED" in text else "FAIL"
        entry = {
            "tag": tag, "verdict": verdict,
            "cycles": int(summary_m.group(1)) if summary_m else None,
            "retires": int(summary_m.group(2)) if summary_m else None,
            "ctrl": int(ctrl_m.group(1)) if ctrl_m else None,
            "mispred": int(miss_m.group(1)) if miss_m else None,
            "crc": crc, "rc": rc,
            "log": os.path.join(run_dir, "transcript.txt"),
        }
        results[tag] = entry
        print("%s: rc=%d %s cycles=%s retires=%s ctrl=%s mispred=%s crcfinal=%s" %
              (tag, entry["rc"], verdict, entry["cycles"], entry["retires"],
               entry["ctrl"], entry["mispred"], crc["crcfinal"]), flush=True)

    on_tag, off_tag = (prefix + "_on"), (prefix + "_off")
    on, off = results.get(on_tag), results.get(off_tag)
    lines = []
    lines.append("CoreMark A/B on %s (identical image %s)" % (define_name, image_dir))
    lines.append("wall clock %.1f min" % ((time.time() - started) / 60.0))
    lines.append("switch: %s  %s=%s vs %s=%s"
                 % (args.switch, define_name, True, define_name, False))
    for tag, _ in configs:
        e = results[tag]
        cycles, retires = e["cycles"], e["retires"]
        ipc = (float(retires) / cycles) if (cycles and retires) else 0.0
        lines.append("%-14s %s cycles=%s retires=%s IPC=%.4f ctrl=%s mispred=%s crc=%s"
                     % (tag, e["verdict"], cycles, retires, ipc, e["ctrl"],
                        e["mispred"], e["crc"]["crcfinal"]))
    if on and off and on["cycles"] and off["cycles"]:
        lines.append("cycle ratio %s/%s = %.3fx  (reduction %.2f%%)"
                     % (off_tag, on_tag, off["cycles"] / on["cycles"],
                        100.0 * (off["cycles"] - on["cycles"]) / off["cycles"]))
    if on and off and on["mispred"] is not None and off["mispred"] is not None:
        ctrl = on["ctrl"] or off["ctrl"]
        for tag, e in ((off_tag, off), (on_tag, on)):
            if e["mispred"] is not None and e["ctrl"]:
                lines.append("%s misprediction rate = %d/%d = %.2f%%"
                             % (tag, e["mispred"], e["ctrl"],
                                100.0 * e["mispred"] / e["ctrl"]))
        if ctrl:
            lines.append("control transfers retired (same in both runs) = %d" % ctrl)
        removed = off["mispred"] - on["mispred"]
        if removed and on["cycles"] and off["cycles"]:
            lines.append("mispredictions removed = %d, cycles saved = %d, "
                         "cost per misprediction = %.1f cycles"
                         % (removed, off["cycles"] - on["cycles"],
                            float(off["cycles"] - on["cycles"]) / removed))
    if on and off:
        # Compare only the CRC keys actually emitted by BOTH runs: the simulation
        # TB prints a subset (crclist/crcmatrix/crcfinal) while the board
        # validation run prints all five.  A key absent from either transcript is
        # not evidence of a difference -- it is simply not reported there.
        both = [k for k in on["crc"] if on["crc"][k] and off["crc"][k]]
        same = [k for k in both if on["crc"][k] == off["crc"][k]]
        diff = [k for k in both if on["crc"][k] != off["crc"][k]]
        missing = [k for k in on["crc"] if k not in both]
        lines.append("CRC compared (present in both runs): %s"
                     % (", ".join(both) or "none"))
        lines.append("CRC identical for: %s" % ", ".join(same))
        lines.append("CRC differs for: %s" % (", ".join(diff) or "none"))
        if missing:
            lines.append("CRC not emitted by both runs (board-only): %s"
                         % ", ".join(missing))
        lines.append("architectural transparency: %s"
                     % ("PASS" if both and not diff and all(e["verdict"] == "PASS"
                                                            for e in results.values())
                        else "FAIL"))
    else:
        e = on or off
        lines.append("single-side run (%s): crc=%s verdict=%s"
                     % (e["tag"], e["crc"], e["verdict"]))
        lines.append("architectural transparency: %s"
                     % ("single side, compare CRC against the recorded reference"
                        if e["verdict"] == "PASS" else "FAIL (no TEST_PASS)"))
    report = os.path.join(args.out, "report.txt")
    with open(report, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
