import os
from pathlib import Path
import argparse
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(executable: Path, args: list[str], work: Path) -> str:
    result = subprocess.run(
        [str(executable), *args], cwd=work, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    print(result.stdout, end="")
    if result.returncode:
        raise SystemExit(result.returncode)
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--modelsim", default=os.environ.get("MODELSIM_BIN", "D:/modeltech64_10.6e/win64"))
    args = parser.parse_args()
    modelsim = Path(args.modelsim)
    work = ROOT / "build" / "sim_light_split_video"
    work.mkdir(parents=True, exist_ok=True)
    for stale in (work / "modelsim.ini", work / "transcript"):
        if stale.exists():
            stale.unlink()
    run(modelsim / "vlib.exe", ["work"], work)
    log = run(modelsim / "vlog.exe", [
        "-sv", "+incdir+" + str(ROOT / "rtl"),
        str(ROOT / "rtl/light_split_video.sv"),
        str(ROOT / "tests/light_split_video_tb.sv"),
    ], work)
    log += run(modelsim / "vsim.exe", [
        "-c", "-onfinish", "exit", "light_split_video_tb",
        "-do", "onerror {quit -code 1}; run -all; quit -code 0",
    ], work)
    (ROOT / "evidence").mkdir(exist_ok=True)
    (ROOT / "evidence/light_split_video_sim.log").write_text(log, encoding="utf-8")
    if "TEST_PASS light_split_video" not in log or "** Fatal:" in log:
        return 1
    print("TEST_PASS light_split_video")
    return 0


if __name__ == "__main__":
    sys.exit(main())
