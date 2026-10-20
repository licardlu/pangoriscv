#!/usr/bin/env python3
"""Area budget gate for the area/efficiency workstream.

This tool is the enforcement half of docs/architecture/module-area-plan.md and
docs/architecture/area-budget.csv. It answers one question: "is this build
within the area budget recorded in the CSV?" and exits non-zero when it is not,
so the rule is not prose-only.

Two modes
---------
budget (default)
    Actual totals must not exceed the ``budget,__max__`` row
    (LUT / FF / LUTRAM / DRM / APM). Use it after every synthesis of a
    delivery-profile build.

baseline
    Actual totals must equal the ``baseline,__totals__`` row within
    --tolerance percent. Use it to prove that a change you believe is
    area-neutral really is (and that nothing drifted accidentally).

Where the numbers come from
---------------------------
``--from-used`` accepts either
  * a ``multiseed_summary.csv`` produced by PDS (looks for the ``Used,`` row), or
  * a ``device_map/run.log`` (looks for the ``Used`` utilisation row).
Column order in that row is LUT, FF, DRM, APM, Distributed RAM.

Usage
-----
    python tools/check_area_budget.py
    python tools/check_area_budget.py --mode baseline --tolerance 1.0
    python tools/check_area_budget.py --from-used build/<stage>/build/pango_native/multiseed_summary.csv

Notes
-----
* The per-module ``delta`` rows are a plan, not a measurement: the synthesis
  netlist only samples part of the LUT primitive types, so per-module LUT
  numbers cannot be summed (see module-area-plan.md section 3.2). Only the
  whole-design ``Used`` row is authoritative, and that is what this gate uses.
* Output is ASCII so it survives a cp437 console.
"""

import argparse
import csv
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
# tools/ -> code/ -> firmware/ -> pangoriscv/
DEFAULT_CSV = os.path.normpath(
    os.path.join(HERE, "..", "..", "..", "docs", "architecture", "area-budget.csv"))

FIELDS = ("lut", "ff", "lutram", "drm", "apm")


def die(msg):
    print("ERROR: " + msg)
    sys.exit(2)


def load_budget(path):
    if not os.path.exists(path):
        die("budget CSV not found: %s" % path)
    rows = []
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            rows.append(row)
    base = [r for r in rows if r["kind"] == "baseline"]
    maxr = [r for r in rows if r["kind"] == "budget"]
    if len(base) != 1 or len(maxr) != 1:
        die("CSV must contain exactly one 'baseline' row and one 'budget' row")
    return base[0], maxr[0], rows


def ints(row):
    out = {}
    for f in FIELDS:
        v = (row.get(f) or "").strip()
        out[f] = None if v == "" else int(v)
    return out


def parse_used(path):
    """Return {lut, ff, drm, apm, lutram} from a PDS artefact."""
    if not os.path.exists(path):
        die("actual-results file not found: %s" % path)
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    # multiseed_summary.csv:  Used,21949,14104,4,6,3628,NA,1,0,0
    m = re.search(r"^Used,([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)", text, re.M)
    if m:
        return dict(zip(("lut", "ff", "drm", "apm", "lutram"),
                        (int(x) for x in m.groups())))

    # device_map/run.log "Device Utilization Summary" table:
    #   | Logic Utilization | Used  | Available | Utilization(%)
    #   | LUT               | 21949 | 66600     | 33
    #   | Distributed RAM   | 3628  | 19900     | 19
    if "Device Utilization Summary" in text:
        table = {
            "lut": r"\|\s*LUT\s*\|\s*([0-9]+)",
            "ff": r"\|\s*FF\s*\|\s*([0-9]+)",
            "lutram": r"\|\s*Distributed RAM\s*\|\s*([0-9]+)",
            "drm": r"\|\s*DRM\s*\|\s*([0-9]+)",
            "apm": r"\|\s*APM\s*\|\s*([0-9]+)",
        }
        got = {}
        for key, pat in table.items():
            mm = re.search(pat, text)
            if mm:
                got[key] = int(mm.group(1))
        if len(got) == 5:
            return got

    # device_map/run.log style:  Used | 21949 | 14104 | ...  (pipe or space separated)
    m = re.search(r"^\s*Used\s*[\|,]?\s*([0-9]+)\s*[\|,]?\s*([0-9]+)\s*[\|,]?\s*([0-9]+)"
                  r"\s*[\|,]?\s*([0-9]+)\s*[\|,]?\s*([0-9]+)", text, re.M)
    if m:
        return dict(zip(("lut", "ff", "drm", "apm", "lutram"),
                        (int(x) for x in m.groups())))

    die("no 'Used,' utilisation row found in %s" % path)


def fmt(v):
    return "-" if v is None else "{:,}".format(v)


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--csv", default=DEFAULT_CSV)
    ap.add_argument("--mode", choices=("budget", "baseline"), default="budget")
    ap.add_argument("--from-used", dest="actual")
    ap.add_argument("--tolerance", type=float, default=1.0,
                    help="baseline mode tolerance in percent (default 1.0)")
    args = ap.parse_args()

    base, maxr, rows = load_budget(args.csv)
    b, mx = ints(base), ints(maxr)

    print("== area budget gate ==")
    print("csv   : %s" % args.csv)
    print("mode  : %s" % args.mode)
    print("baseline totals : " + " ".join("%s=%s" % (f, fmt(b[f])) for f in FIELDS))

    if not args.actual:
        # Nothing to compare: summarise the plan and succeed (useful in CI logs).
        print("")
        print("-- no --from-used given: printing the budget plan only --")
        print("%-18s %8s %8s %8s %8s %8s  %-12s %s"
              % ("module", "dLUT", "dFF", "dRAM", "dDRM", "dAPM", "stage", "note"))
        for r in rows:
            if r["kind"] != "delta":
                continue
            d = ints(r)
            print("%-18s %8s %8s %8s %8s %8s  %-12s %s"
                  % (r["module"],
                     "0" if d["lut"] in (None, 0) else "{:+d}".format(d["lut"]),
                     "0" if d["ff"] in (None, 0) else "{:+d}".format(d["ff"]),
                     "0" if d["lutram"] in (None, 0) else "{:+d}".format(d["lutram"]),
                     "0" if d["drm"] in (None, 0) else "{:+d}".format(d["drm"]),
                     "0" if d["apm"] in (None, 0) else "{:+d}".format(d["apm"]),
                     r["stage"], r["note"]))
        print("")
        print("PASS (plan only; no build given)")
        return 0

    a = parse_used(args.actual)
    print("actual totals   : " + " ".join("%s=%s" % (f, fmt(a[f])) for f in FIELDS))
    print("")

    failures = []
    if args.mode == "baseline":
        print("%-8s %10s %10s %8s" % ("metric", "baseline", "actual", "delta%"))
        for f in FIELDS:
            if b[f] in (None, 0) or a[f] is None:
                continue
            pct = 100.0 * (a[f] - b[f]) / b[f]
            print("%-8s %10s %10s %+8.2f" % (f.upper(), fmt(b[f]), fmt(a[f]), pct))
            if abs(pct) > args.tolerance:
                failures.append("%s drifted %+0.2f%% (limit %.2f%%)" % (f, pct, args.tolerance))
    else:
        print("%-8s %10s %10s %8s" % ("metric", "budget", "actual", "margin"))
        for f in FIELDS:
            if mx[f] is None or a[f] is None:
                continue
            margin = mx[f] - a[f]
            print("%-8s %10s %10s %+8d" % (f.upper(), fmt(mx[f]), fmt(a[f]), margin))
            if margin < 0:
                failures.append("%s over budget by %d (%s > %s)" % (f, -margin, a[f], mx[f]))

    print("")
    if failures:
        for msg in failures:
            print("FAIL: " + msg)
        print("")
        print("FAIL (%d violation(s)) -- see docs/architecture/module-area-plan.md" % len(failures))
        return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
