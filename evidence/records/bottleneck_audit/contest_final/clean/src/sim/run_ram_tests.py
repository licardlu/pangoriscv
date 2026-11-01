"""Fresh ModelSim RAM endpoint and real LSU/data-engine acceptance runs."""
import argparse
from pathlib import Path
import shutil
import sys
import tempfile

from runner_common import run, validate_test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--case", choices=("ram", "lsu", "all"), default="all")
    args = parser.parse_args()
    if args.seeds < 1:
        parser.error("--seeds must be positive")
    root = Path(__file__).resolve().parents[1]
    sources = [root / p for p in (
        "rtl/perips/axi_ram.v", "rtl/core/lsu_axi.v",
        "rtl/core/axi_read_engine.v", "rtl/core/axi_data_engine.v",
        "tb/axi/tb_axi_ram.sv", "tb/axi/tb_lsu_axi_ram.sv")]
    missing = [str(p) for p in sources if not p.is_file()]
    if missing:
        raise RuntimeError("RAM_IMPLEMENTATION_MISSING: " + ", ".join(missing))
    tools = {name: shutil.which(name) for name in ("vlib", "vlog", "vsim")}
    if not all(tools.values()):
        raise RuntimeError("ModelSim tools not in PATH: " + str(tools))
    parent = root / ".sim_runs"
    parent.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="ram-", dir=parent))
    print("RUN_DIR", work, flush=True)
    shutil.copyfile(root / "tb/axi/ram_init.hex", work / "ram_init.hex")
    run([tools["vlib"], "work"], work, work / "vlib.log", 30)
    run([tools["vlog"], "-sv", "+incdir+" + str(root / "rtl/core")] +
        [str(p) for p in sources], work, work / "compile.log", 120)
    (work / "run.do").write_text(
        "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n", encoding="ascii")
    cases = ("ram", "lsu") if args.case == "all" else (args.case,)
    count = 0
    for case in cases:
        for seed in range(1, args.seeds + 1):
            top = "tb_axi_ram" if case == "ram" else "tb_lsu_axi_ram"
            log = work / f"{case}-seed{seed}.log"
            text = run([tools["vsim"], "-c", "-onfinish", "stop",
                        "work." + top, f"+SEED={seed}", "-do", "run.do"],
                       work, log, 120)
            validate_test(text, log)
            if ("TEST_PASS " + ("RAM" if case == "ram" else "LSU_RAM")) not in text:
                raise RuntimeError("RAM_PASS_MISSING: " + str(log))
            count += 1
            print(f"PASS {case} seed={seed}", flush=True)
    print(f"SUMMARY {count}/{count} PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RUN_FAILED:", error, file=sys.stderr)
        sys.exit(1)
