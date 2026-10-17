"""N08 locked-owner native AXI tests; each seed must emit exactly one pass."""
from pathlib import Path
import argparse
import shutil
import sys
import tempfile
from runner_common import run, validate_test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=20)
    args = parser.parse_args()
    if args.seeds < 1:
        raise RuntimeError("At least one seed required")
    root = Path(__file__).resolve().parents[1]
    tools = {name: shutil.which(name) for name in ("vlib", "vlog", "vsim")}
    if not all(tools.values()):
        raise RuntimeError("ModelSim tools not in PATH: " + str(tools))
    parent = root / ".sim_runs"
    parent.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="interconnect-", dir=parent))
    print("RUN_DIR", work, flush=True)
    run([tools["vlib"], "work"], work, work / "vlib.log", 30)
    sources = [
        root / "rtl/bus/axi_error_slave.v",
        root / "rtl/bus/axi_interconnect.v",
        root / "tb/axi/tb_axi_interconnect.sv",
    ]
    run([tools["vlog"], "-sv", "-work", "work"] + list(map(str, sources)),
        work, work / "compile.log", 120)
    (work / "run.do").write_text(
        "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n", encoding="ascii")
    for seed in range(1, args.seeds + 1):
        log = work / f"seed-{seed}.log"
        text = run([tools["vsim"], "-c", "-onfinish", "stop",
                    "work.tb_axi_interconnect", f"+SEED={seed}", "-do", "run.do"],
                   work, log, 120)
        validate_test(text, log)
        print("PASS", seed, flush=True)
    print("SUMMARY", args.seeds, "/", args.seeds, "PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RUN_FAILED:", error, file=sys.stderr)
        sys.exit(1)
