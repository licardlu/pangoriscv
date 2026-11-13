"""Stage a PDS build directory that stops after synthesis (for Fabric Inserter)."""
import re, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(r"D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/pds_native_120")
OUT = ROOT / "build" / sys.argv[1]
if OUT.exists():
    raise SystemExit("build dir exists: " + str(OUT))
OUT.mkdir(parents=True)


def tcl_path(p):
    return "{" + p.as_posix() + "}"


staged = []
for line in (ROOT / "sources.f").read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    src = (ROOT / line).resolve()
    target = OUT / "sources" / src.name
    text = src.read_text(encoding="utf-8")
    includes = re.findall(r'`include\s+"([^"]+)"', text)
    for inc in includes:
        orig = (src.parent / inc).resolve()
        copied = OUT / "sources/sections" / orig.name
        copied.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(orig, copied)
        text = text.replace('"' + inc + '"', '"' + copied.as_posix() + '"')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8", newline="\n")
    staged.append(target)

shutil.copytree(ROOT / "constraints", OUT / "constraints")
for image in (ROOT / "firmware/image").glob("*.bin"):
    shutil.copy2(image, OUT / image.name)

(OUT / "source_list.tcl").write_text(
    "set exact_sources {\n" + "".join("  " + tcl_path(p) + "\n" for p in staged) + "}\n",
    encoding="utf-8")

for name in ("synth.tcl",):
    shutil.copy2(Path(__file__).with_name(name), OUT / name)
print("STAGED", OUT)
