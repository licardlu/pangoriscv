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


def parse_args(argv):
    """Return (mode, per_switch) from the command line.

    Two forms are accepted:
      * the original bulk form  ``on`` / ``off`` / ``status`` (all three switches)
      * per-switch form          ``PERF_ENABLE=off`` (repeatable, any order)

    The per-switch form exists for the area workstream: the DELIVERY profile
    turns PERF_ENABLE off while the analysis/simulation profile keeps all three
    on.  Bulk ``off`` would silently change CACHE_ENABLE/PREDICT_ENABLE too,
    which invalidates any CoreMark comparison (lesson 4.10: a cached design and
    a cache-less design are different designs, not two configurations of one).
    """
    mode = ""
    per_switch = {}
    for arg in argv:
        if "=" in arg:
            name, _, value = arg.partition("=")
            name = name.strip()
            value = value.strip().lower()
            if name not in SWITCHES:
                raise SystemExit("unknown switch %r; known: %s"
                                 % (name, ", ".join(SWITCHES)))
            if value not in ("on", "off"):
                raise SystemExit("%s needs on or off, got %r" % (name, value))
            per_switch[name] = value
        elif mode == "":
            mode = arg
        else:
            raise SystemExit("unexpected argument %r" % arg)
    return mode, per_switch


def main():
    mode, per_switch = parse_args(sys.argv[1:])
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

    if per_switch:
        if mode:
            raise SystemExit("give either on|off|status or NAME=on|off, not both")
        wanted = per_switch
    elif mode in ("on", "off"):
        wanted = {name: mode for name in SWITCHES}
    else:
        raise SystemExit("usage: set_switches.py on|off|status\n"
                         "       set_switches.py PERF_ENABLE=off [CACHE_ENABLE=on ...]")

    changed = []
    for name, value in wanted.items():
        i = index[name]
        if state[name] == value:
            continue
        active, commented = forms(name)
        lines[i] = active if value == "on" else commented
        changed.append("%s->%s" % (name, value.upper()))

    if not changed:
        print("nothing to do (already in the requested state)")
        return 0

    CONFIG.write_bytes(b"\n".join(lines))
    print("switches updated: %s" % ", ".join(changed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
