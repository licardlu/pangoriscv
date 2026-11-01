"""Run the conv3x3 RTL against the integer reference across all edge cases.

Each case regenerates vectors into vec/, re-elaborates the testbench with the
matching CIN/COUT, runs it, and records PASS/FAIL.  The log is the evidence that
the RTL matches the reference element by element -- not merely that the cosine
similarity looked good.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
def _find_iverilog():
    """Locate the Icarus install: env var first, then the usual local copies."""
    cands = []
    if os.environ.get("IVERILOG_BIN"):
        cands.append(os.environ["IVERILOG_BIN"])
    cands += [
        os.path.join(HERE, "..", "..", "toolchain", "iverilog", "bin"),
        r"C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/toolchain/iverilog/bin",
        r"E:/file/pango/toolchains/iverilog/bin",
        r"C:/iverilog/bin",
    ]
    for c in cands:
        c = os.path.abspath(c)
        if os.path.exists(os.path.join(c, "iverilog.exe")):
            return c
    raise SystemExit("iverilog not found; set IVERILOG_BIN to its bin directory")


IVERILOG_BIN = _find_iverilog()
IVERILOG = os.path.join(IVERILOG_BIN, "iverilog.exe")
VVP = os.path.join(IVERILOG_BIN, "vvp.exe")

CASES = [
    # pattern, cin, cout, h, w, seed, why
    ("rand",      8,  8,  4, 4,  7, "baseline"),
    ("zero",      8,  8,  4, 4, 11, "degenerate scale, M == 0"),
    ("extreme",   8,  8,  4, 4, 13, "activations at +-127"),
    ("sat",       8,  8,  4, 4, 17, "clip to +-127/-128"),
    ("neg",       8,  8,  4, 4, 19, "leaky branch only"),
    ("rand",     16, 16,  4, 4, 23, "real layer shape"),
    ("rand",     32,  8,  3, 5, 29, "odd spatial, COUT < CIN"),
    ("rand",      8, 16,  2, 7, 31, "COUT > CIN"),
]


def run(cmd, env=None, cwd=HERE):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


def main():
    env = dict(os.environ)
    env["PATH"] = os.path.abspath(IVERILOG_BIN) + os.pathsep + env.get("PATH", "")
    logdir = os.path.join(HERE, "logs")
    os.makedirs(logdir, exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    logpath = os.path.join(logdir, f"layer_tests_{stamp}.log")

    lines, npass = [], 0
    for pattern, cin, cout, h, w, seed, why in CASES:
        vec = os.path.join(HERE, "vec")
        g = run([sys.executable, "gen_vectors.py", "--cin", str(cin),
                 "--cout", str(cout), "--h", str(h), "--w", str(w),
                 "--seed", str(seed), "--pattern", pattern, "--out", vec], env=env)
        if g.returncode != 0:
            lines.append(f"FAIL  {pattern:<8} {cin:>2}->{cout:<2} {h}x{w}  gen error: {g.stderr.strip()[:120]}")
            continue

        sim = run([IVERILOG, "-g2012", f"-Ptb_conv3x3.CIN={cin}",
                   f"-Ptb_conv3x3.COUT={cout}",
                   "-o", "tb_run.vvp", "rtl/conv3x3_core.v", "tb/tb_conv3x3.v"], env=env)
        if sim.returncode != 0:
            lines.append(f"FAIL  {pattern:<8} {cin:>2}->{cout:<2} {h}x{w}  compile error")
            continue

        r = run([VVP, "tb_run.vvp"], env=env)
        out = r.stdout
        ok = "PASS:" in out
        m = re.search(r"PASS: (\d+) pixels, (\d+) output bytes", out)
        if ok:
            npass += 1
            lines.append(f"PASS  {pattern:<8} {cin:>2}->{cout:<2} {h}x{w}  "
                         f"{m.group(1)} px / {m.group(2)} bytes exact   ({why})")
        else:
            bad = [l for l in out.splitlines() if "MISMATCH" in l or "FAIL" in l][:2]
            lines.append(f"FAIL  {pattern:<8} {cin:>2}->{cout:<2} {h}x{w}  "
                         f"{'; '.join(bad)[:140]}   ({why})")

    header = [f"conv3x3 RTL vs integer reference  --  {time.strftime('%Y-%m-%d %H:%M:%S')}",
              f"iverilog: {run([IVERILOG, '-V'], env=env).stdout.splitlines()[0]}",
              ""]
    body = lines + ["", f"RESULT: {npass}/{len(CASES)} cases bit-exact"]
    text = "\n".join(header + body)
    print(text)
    with open(logpath, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(f"\nlog: {logpath}")
    return 0 if npass == len(CASES) else 1


if __name__ == "__main__":
    sys.exit(main())
