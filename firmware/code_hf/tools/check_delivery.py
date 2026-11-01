#!/usr/bin/env python3
"""Nine gates for promoting one build directory to the delivery bitstream.

Why: plan v23 / skill section 3 says the three scored metrics must come out of
ONE implementation.  Every promotion so far has been done by hand-reading four
log files, which is exactly how a stale number gets into the README.  This
script reads the build directory and prints PASS/FAIL per gate plus the three
metrics; a non-zero exit means "do not promote".

usage:
  python tools/check_delivery.py --build build/p61r51 --freq 51 --ticks 3810700 --iterations 20
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

CODE = Path(__file__).resolve().parents[1]


def read_summary(bdir: Path) -> dict:
    """One row per seed in multiseed_summary.csv; we only ever implement one."""
    out = {}
    path = bdir / "multiseed_summary.csv"
    if not path.exists():
        return out
    text = path.read_text(errors="replace")
    header = None
    for line in text.splitlines():
        if line.startswith("Seed,State"):
            header = next(csv.reader([line]))
        elif line.startswith("single,") and header:
            row = next(csv.reader([line]))
            out["row"] = dict(zip(header, row))
            break
    m = re.search(r"slack value,([-0-9.]+),", text)
    if m:
        out["synth_wns"] = float(m.group(1))
    m = re.search(r"^Used,([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)", text, re.M)
    if m:
        out["lut"], out["ff"], out["drm"], out["apm"], out["lutram"] = (
            int(x) for x in m.groups())
    return out


def routed_delay(bdir: Path) -> tuple[float | None, int | None]:
    """Worst setup slack and failing-endpoint count from the routed report."""
    path = bdir / "report_timing" / "pangoriscv_top.rtr"
    if not path.exists():
        return None, None
    text = path.read_text(errors="replace")
    m = re.search(r"Slack \((?:VIOLATED|MET)\)\s+([-0-9.]+)", text)
    if not m:
        return None, None
    return float(m.group(1)), None


def failing_endpoints(bdir: Path) -> int | None:
    path = bdir / "report_timing" / "pangoriscv_top.rtr"
    if not path.exists():
        return None
    text = path.read_text(errors="replace")
    # Setup summary table row for core_clk: WNS, TNS, failing endpoints
    m = re.findall(r"core_clk\s+core_clk\s+([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+(\d+)", text)
    if not m:
        return None
    return min(int(x[2]) for x in m)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", required=True)
    ap.add_argument("--freq", type=float, required=True)
    ap.add_argument("--ticks", type=int, required=True,
                    help="Total ticks from the 20-iteration simulation")
    ap.add_argument("--iterations", type=int, default=20,
                    help="iterations of that simulation image")
    ap.add_argument("--max-lut", type=int, default=18000)
    a = ap.parse_args()

    bdir = Path(a.build)
    if not bdir.is_absolute():
        bdir = CODE / bdir
    if not bdir.is_dir():
        print("no such build dir:", bdir)
        return 2

    period = 1000.0 / a.freq
    s = read_summary(bdir)
    run_log = (bdir / "run.log").read_text(errors="replace") if (bdir / "run.log").exists() else ""
    flow = (bdir / "flow.log").read_text(errors="replace") if (bdir / "flow.log").exists() else ""

    gates = []

    def gate(name, ok, detail):
        gates.append((name, bool(ok), detail))

    # 1 routing complete
    unrouted = re.findall(r"Unrouted nets (\d+) at the end of iteration \d+", flow)
    last = int(unrouted[-1]) if unrouted else None
    gate("1 unrouted nets = 0", last == 0, "last reported = %s" % last)

    # 2 design summary (only report_timing writes this verdict; flow.log does not)
    rtr = bdir / "report_timing" / "pangoriscv_top.rtr"
    rtr_text = rtr.read_text(errors="replace") if rtr.exists() else ""
    acm = "All Constraints Met" in rtr_text
    gate("2 All Constraints Met", acm, "report_timing says %s" %
         ("All Constraints Met" if acm else "NOT met / no report"))

    # 3/4 setup + hold
    row = s.get("row") or {}

    def cell(key):
        v = row.get(key)
        try:
            return float(v)
        except (TypeError, ValueError):
            return None

    wns = cell("Setup(Slow)")
    whs = cell("Hold(Slow)")
    fail_ep = cell("Setup(Slow) Total Failing Endpoints")
    fail_h = cell("Hold(Slow) Total Failing Endpoints")
    gate("3 setup WNS >= 0", wns is not None and wns >= 0, "WNS = %s ns" % wns)
    gate("4 hold  WHS >= 0", whs is not None and whs >= 0, "WHS = %s ns" % whs)
    gate("3b setup failing endpoints = 0", fail_ep == 0, "%s endpoints" % fail_ep)
    gate("4b hold  failing endpoints = 0", fail_h == 0, "%s endpoints" % fail_h)

    # 5 area
    lut = s.get("lut")
    gate("5 LUT <= %d" % a.max_lut, lut is not None and lut <= a.max_lut, "LUT = %s" % lut)

    # 6 image inside the bitstream
    good = "Loading memory data from file" in run_log
    bad = "Cannot open specified data file" in run_log
    n_load = run_log.count("Loading memory data from file")
    gate("6 program/data image loaded", good and not bad, "%d load lines, cannot_open=%s"
         % (n_load, bad))

    # 7 bitstream exists
    sbit = bdir / "generate_bitstream" / "pangoriscv_top.sbit"
    gate("7 bitstream generated", sbit.is_file(),
         "%s (%d bytes)" % (sbit.name, sbit.stat().st_size) if sbit.is_file() else "missing")

    print("build      :", bdir.name)
    print("constraint : %.4f MHz -> %.6f ns" % (a.freq, period))
    print("synthesis  : WNS %s ns" % s.get("synth_wns"))
    print("resources  : LUT %s / FF %s / LUTRAM %s / DRM %s / APM %s"
          % (s.get("lut"), s.get("ff"), s.get("lutram"), s.get("drm"), s.get("apm")))
    print()
    ok_all = True
    for name, ok, detail in gates:
        print("  [%s] %-34s %s" % ("PASS" if ok else "FAIL", name, detail))
        ok_all &= ok
    print()

    per_iter = a.ticks / a.iterations
    score = a.iterations * 1e6 / a.ticks
    print("score      : %d ticks / %d it = %.1f ticks/iter -> CoreMark/MHz %.4f"
          % (a.ticks, a.iterations, per_iter, score))
    if lut:
        print("efficiency : CoreMark/MHz per kLUT = %.4f" % (score / (lut / 1000.0)))
    print()
    print("VERDICT    :", "PROMOTE" if ok_all else "DO NOT PROMOTE")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
