"""Validate a DDR region map before it reaches hardware.

Why this exists: the previous closed loop lost 109 bytes because bias/M were
placed inside the weight region, and this round lost another day to a
byte-per-word testbench where regions that *looked* 512 bytes apart actually
overlapped after the x4 addressing stride.  Both were silent.

Checks, in order:
  1. start is aligned to `align`
  2. physical span (length * word_stride) does not overlap the next region
  3. the whole map fits `--limit`
Failures print the exact pair and exit non-zero.

Usage:
    python scripts/check_ddr_map.py conv_int8/layer10/map.json --limit 0x80000
"""
import argparse
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("map_json", type=Path)
    ap.add_argument("--limit", default="0x80000")
    a = ap.parse_args()
    cfg = json.loads(a.map_json.read_text(encoding="utf-8"))
    stride = int(cfg.get("word_stride", 1))
    limit = int(a.limit, 0)

    regions = sorted(cfg["regions"], key=lambda r: int(r["start"]))
    bad = 0
    prev = None
    for r in regions:
        start = int(r["start"])
        length = int(r["length"])
        align = int(r.get("align", 1))
        span = length * stride
        if start % align:
            print("FAIL align  %-8s start=0x%X align=%d" % (r["name"], start, align))
            bad += 1
        if prev is not None:
            prev_end = int(prev["start"]) + int(prev["length"]) * stride
            if start < prev_end:
                print("FAIL overlap %-8s [0x%X,0x%X) vs %-8s ends 0x%X"
                      % (r["name"], start, start + span, prev["name"], prev_end))
                bad += 1
        if start + span > limit:
            print("FAIL limit  %-8s ends 0x%X > 0x%X" % (r["name"], start + span, limit))
            bad += 1
        print("ok   %-8s start=0x%06X bytes=%d footprint=%d end=0x%06X"
              % (r["name"], start, length, span, start + span))
        prev = r

    if bad:
        print("MAP_FAIL %d problem(s)" % bad)
        return 1
    print("MAP_PASS %d regions, limit 0x%X" % (len(regions), limit))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
