"""Verdict helpers shared by the ModelSim test runners.

Why this module exists
----------------------
The runners dump the simulator output into ``*.log`` and ``transcript.txt`` with
every line prefixed by ``# `` (a ModelSim/format convention).  The original
pass criterion was::

    fails = [ln for ln in text.splitlines() if ln.strip().startswith('FAIL')]

which can never match ``# FAIL ...`` -- so a testbench that printed FAIL still
reported PASS.  Independent review 2026-10-18 found five runners with this bug.
Use these helpers instead, and always require the explicit success marker.
"""

PREFIX = "#"


def content(line: str) -> str:
    """Strip the log prefix (``# ``, ``> ``, ...) and surrounding blanks."""
    s = line.strip()
    while s and (s[0] == PREFIX or s[0] == ">" or s[0] == "!"):
        s = s[1:].strip()
    return s


def failures(text: str):
    """Lines that report a check failure, prefix-insensitive."""
    return [content(ln) for ln in text.splitlines() if content(ln).startswith("FAIL")]


def fatals(text: str):
    return [ln.strip() for ln in text.splitlines() if "Fatal" in ln or "** Fatal" in ln]


def passed(text: str, marker: str) -> bool:
    """True only when the testbench printed its explicit success marker."""
    return marker in text


def verdict(text: str, marker: str):
    """-> (ok, reason).  ok is True only with no FAIL, no Fatal and the marker."""
    bad = failures(text)
    fat = fatals(text)
    if bad:
        return False, "fails=%d first=%s" % (len(bad), bad[0][:60])
    if fat:
        return False, "fatal=%s" % fat[0][:60]
    if not passed(text, marker):
        return False, "missing success marker %r" % marker
    return True, "ok"
