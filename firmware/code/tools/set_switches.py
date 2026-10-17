#!/usr/bin/env python3
"""Toggle the three build-time feature switches in rtl/core/soc_config.vh.

The repository default is **all three off**; the delivered CoreMark/PDS build
turns them on explicitly and restores them afterwards.  This script exists
because that flip must never go through a text regex: the file has UTF-8 Chinese
comments, and a lossy rewrite once dropped unrelated rules from a tracked file.

It is **line based**: only the exact switch lines are compared and rewritten, so
every other byte (comments, CRLF endings, trailing newline) is preserved, and
running `off` twice is a no-op instead of corrupting the commented form.

Usage (from the package root, i.e. firmware/code):
    python tools/set_switches.py on
    python tools/set_switches.py off
    python tools/set_switches.py status
"""

import sys
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[1] / "rtl" / "core" / "soc_config.vh"
BT = bytes([96])  # backtick: the Verilog directive prefix
SWITCHES = ("CACHE_ENABLE", "PREDICT_ENABLE", "PERF_ENABLE")


def forms(name):
    active = BT + b"define " + name.encode()
    commented = b"// " + active
    return active, commented


def classify(line):
    """Return (switch_name, state) for a switch line, else (None, None)."""
    body = line.rstrip(b"\r")
    for name in SWITCHES:
        active, commented = forms(name)
        if body.strip() == active:
            return name, "on"
        if body.strip() == commented:
            return name, "off"
    return None, None


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    raw = CONFIG.read_bytes()
    lines = raw.split(b"\n")

    # Locate every switch line.  Each must appear exactly once as either form.
    index = {}
    state = {}
    for i, line in enumerate(lines):
        name, st = classify(line)
        if name is None:
            continue
        if name in state:
            raise SystemExit("%s appears more than once; nothing written" % name)
        index[name] = i
        state[name] = st

    missing = [n for n in SWITCHES if n not in state]
    if missing:
        raise SystemExit("cannot find switch line(s): %s; nothing written"
                         % ", ".join(missing))

    if mode == "status":
        for name in SWITCHES:
            print("%-16s %s" % (name, state[name].upper()
                                if state[name] == "on" else "off"))
        return 0

    if mode not in ("on", "off"):
        raise SystemExit("usage: set_switches.py on|off|status")

    for name in SWITCHES:
        i = index[name]
        active, commented = forms(name)
        lines[i] = active if mode == "on" else commented

    CONFIG.write_bytes(b"\n".join(lines))
    print("three switches %s" % mode.upper())
    return 0


if __name__ == "__main__":
    sys.exit(main())
