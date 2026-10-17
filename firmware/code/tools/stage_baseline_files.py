"""Stage a baseline RTL revision for resource_check.tcl (RESOURCE_BASELINE_DIR).

Writes `<out>/<path with '/' -> '__'>` byte for byte from `git show`, so the
naming matches the convention tools/run_fetch_ab.py uses and the working tree is
never touched.

Usage:
    python stage_baseline_files.py <out-dir> <rev> <file> [<file> ...]
"""

import subprocess
import sys
from pathlib import Path

if len(sys.argv) < 4:
    raise SystemExit(__doc__)

out = Path(sys.argv[1]).resolve()
rev = sys.argv[2]
files = sys.argv[3:]

# The package root is this script's grandparent: tools/ -> firmware/code.
repo = Path(__file__).resolve().parents[1]

out.mkdir(parents=True, exist_ok=True)
for rel in files:
    blob = subprocess.run(["git", "-C", str(repo), "show", "%s:./%s" % (rev, rel)],
                          capture_output=True, check=True).stdout
    target = out / rel.replace("/", "__")
    target.write_bytes(blob)
    print("%-32s %6d bytes -> %s" % (rel, len(blob), target.name))
