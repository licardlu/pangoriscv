"""Isolated, single-beat AXI engine regressions with fatal and hardware fault tests."""
import argparse
from pathlib import Path
import shutil
import sys
import tempfile

from runner_common import run, validate_test


FAULT_MESSAGES = {
    1: "ENGINE_CONFIG_LEN_SIZE", 2: "ENGINE_CONFIG_LEN_SIZE",
    3: "ENGINE_R_ID_LAST", 4: "ENGINE_R_ID_LAST",
    5: "ENGINE_B_ID", 6: "ENGINE_W_LAST",
    7: "ENGINE_CONFIG_LEN_SIZE", 8: "ENGINE_CONFIG_LEN_SIZE",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--case", choices=("read", "data", "all"), default="all")
    args = parser.parse_args()
    if args.seeds < 1:
        parser.error("--seeds must be positive")
    root = Path(__file__).resolve().parents[1]
    tools = {name: shutil.which(name) for name in ("vlib", "vlog", "vsim")}
    if not all(tools.values()):
        raise RuntimeError("ModelSim tools not in PATH: " + str(tools))
    sources = [root / p for p in (
        "rtl/core/axi_read_engine.v", "rtl/core/axi_data_engine.v",
        "tb/axi/tb_axi_read_engine.sv", "tb/axi/tb_axi_data_engine.sv")]
    missing = [str(p) for p in sources if not p.is_file()]
    if missing:
        raise RuntimeError("ENGINE_IMPLEMENTATION_MISSING: " + ", ".join(missing))
    parent = root / ".sim_runs"
    parent.mkdir(exist_ok=True)
    cases = ("read", "data") if args.case == "all" else (args.case,)
    count = 0
    for hardware in (False, True):
        work = Path(tempfile.mkdtemp(prefix="engines-hw-" if hardware else "engines-", dir=parent))
        print("RUN_DIR", work, flush=True)
        run([tools["vlib"], "work"], work, work / "vlib.log", 30)
        command = [tools["vlog"], "-sv", "+incdir+" + str(root / "rtl/core")]
        if hardware:
            command.append("+define+SYNTHESIS")
        run(command + [str(p) for p in sources], work, work / "compile.log", 120)
        (work / "run.do").write_text(
            "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n", encoding="ascii")
        for case in cases:
            runs = [] if hardware else [(seed, 0) for seed in range(1, args.seeds + 1)]
            runs += [(1, fault) for fault in range(1, 9 if case == "data" else 5)]
            for seed, fault in runs:
                log = work / f"{case}-seed{seed}-fault{fault}.log"
                command = [tools["vsim"], "-c", "-onfinish", "stop",
                           f"work.tb_axi_{case}_engine", f"+SEED={seed}", f"+FAULT={fault}",
                           "-do", "run.do"]
                try:
                    text = run(command, work, log, 120)
                except RuntimeError as error:
                    if hardware or not fault or not str(error).startswith("COMMAND_FAIL:"):
                        raise
                    text = log.read_text(encoding="utf-8", errors="replace")
                if fault and not hardware:
                    if ("Fatal: " + FAULT_MESSAGES[fault]) not in text or "TEST_PASS" in text:
                        raise RuntimeError("EXPECTED_PROTOCOL_FATAL_NOT_FOUND: " + str(log))
                else:
                    validate_test(text, log)
                    expected = "TEST_PASS ENGINE_FAULT_HARDWARE" if hardware else "TEST_PASS ENGINE data="
                    if expected not in text:
                        raise RuntimeError("ENGINE_PASS_MISSING: " + str(log))
                count += 1
                print(f"PASS {case} seed={seed} fault={fault} hardware={hardware}", flush=True)
    print(f"SUMMARY {count}/{count} PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RUN_FAILED:", error, file=sys.stderr)
        sys.exit(1)
