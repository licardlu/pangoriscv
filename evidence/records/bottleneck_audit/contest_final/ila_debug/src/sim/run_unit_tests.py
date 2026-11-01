"""Run isolated plan 28 pipeline-slot and divider-adapter tests."""

import argparse
from pathlib import Path
import shutil
import sys
import tempfile

from runner_common import run, validate_test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=("pipe_slot", "div_adapter", "ifu_axi", "lsu_axi",
                                           "icache_axi", "w_contract", "all"),
                        default="all")
    parser.add_argument("--pipe-source", type=Path,
                        help="Isolated pipe_slot source for negative verification")
    parser.add_argument("--negative-stall-clear", action="store_true",
                        help="Inject a stall-clear bug and require the test to catch it")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    tools = {name: shutil.which(name) for name in ("vlib", "vlog", "vsim")}
    if not all(tools.values()):
        raise RuntimeError("ModelSim tools not in PATH: " + str(tools))
    cases = ("pipe_slot", "div_adapter", "ifu_axi", "lsu_axi",
             "icache_axi", "w_contract") if args.case == "all" else (args.case,)
    if args.negative_stall_clear and args.case != "pipe_slot":
        raise RuntimeError("--negative-stall-clear requires --case pipe_slot")
    if args.negative_stall_clear and args.pipe_source:
        raise RuntimeError("Negative injection cannot override --pipe-source")
    parent = root / ".sim_runs"
    parent.mkdir(exist_ok=True)
    negative_source = None
    if args.negative_stall_clear:
        source = root / "rtl/core/pipe_slot.v"
        negative_source = Path(tempfile.mkdtemp(prefix="negative-pipe-slot-", dir=parent)) / "pipe_slot_bug.v"
        original = source.read_text(encoding="ascii")
        anchor = "if (in_valid) data_q <= in_data;\n        end"
        if original.count(anchor) != 1:
            raise RuntimeError("STALL_INJECTION_ANCHOR_MISSING")
        negative_source.write_text(original.replace(
            anchor, anchor + " else begin\n            valid_q <= 1'b0;\n        end"
        ), encoding="ascii")
        print("NEGATIVE_SOURCE", negative_source, flush=True)
    for case in cases:
        work = Path(tempfile.mkdtemp(prefix="unit-" + case + "-", dir=parent))
        print("RUN_DIR", work, flush=True)
        if case == "pipe_slot":
            sources = [negative_source if negative_source else
                       (args.pipe_source.resolve() if args.pipe_source else
                        root / "rtl/core/pipe_slot.v")]
        elif case == "div_adapter":
            sources = [root / "rtl/core/div.v", root / "rtl/core/div_adapter.v"]
        elif case == "w_contract":
            sources = [root / "rtl/core/axi_read_engine.v",
                       root / "rtl/core/axi_data_engine.v"]
        else:
            sources = [root / ("rtl/core/" + case + ".v")]
        sources.append(root / ("tb/unit/tb_" + case + ".sv"))
        run([tools["vlib"], "work"], work, work / "vlib.log", 30)
        run([tools["vlog"], "-sv", "-work", "work",
             "+incdir+" + str(root / "rtl/core")] +
            [str(source) for source in sources], work, work / "compile.log", 120)
        (work / "run.do").write_text(
            "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n",
            encoding="ascii",
        )
        log = work / "simulation.log"
        try:
            text = run([tools["vsim"], "-c", "-onfinish", "stop",
                        "work.tb_" + case, "-do", "run.do"], work, log, 120)
        except RuntimeError as error:
            if not args.negative_stall_clear or not str(error).startswith("COMMAND_FAIL:"):
                raise
            text = log.read_text(encoding="utf-8", errors="replace")
        if args.negative_stall_clear:
            if "stall lost A" not in text or "TEST_PASS" in text:
                raise RuntimeError("NEGATIVE_INJECTION_NOT_DETECTED: " + str(log))
            print("PASS negative-stall-clear", flush=True)
            continue
        validate_test(text, log)
        expected = {"pipe_slot": "TEST_PASS N02", "div_adapter": "TEST_PASS N03_DIV",
                    "ifu_axi": "TEST_PASS IFU", "lsu_axi": "TEST_PASS LSU",
                    "icache_axi": "TEST_PASS ICACHE",
                    "w_contract": "TEST_PASS WCONTRACT"}[case]
        if expected not in text:
            raise RuntimeError("EXPECTED_CASE_PASS_MISSING: " + str(log))
        print("PASS", case, flush=True)
    print("SUMMARY", len(cases), "/", len(cases), "PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RUN_FAILED:", error, file=sys.stderr)
        sys.exit(1)
