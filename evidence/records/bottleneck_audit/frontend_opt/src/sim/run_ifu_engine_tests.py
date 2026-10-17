"""Run real IFU/read-engine redirect and disabled-drain regressions."""
import argparse
from pathlib import Path
import shutil
import sys
import tempfile

from runner_common import run, validate_test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--negative-zero-inst", action="store_true",
                        help="Compile an isolated zero-instruction mutant; require rejection")
    args = parser.parse_args()
    if args.seeds < 1:
        parser.error("--seeds must be positive")
    root = Path(__file__).resolve().parents[1]
    tools = {name: shutil.which(name) for name in ("vlib", "vlog", "vsim")}
    if not all(tools.values()):
        raise RuntimeError("ModelSim tools not in PATH: " + str(tools))
    parent = root / ".sim_runs"
    parent.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="ifu-real-engine-", dir=parent))
    print("RUN_DIR", work, flush=True)
    sources = [root / p for p in (
        "rtl/core/axi_read_engine.v", "rtl/core/ifu_axi.v", "tb/axi/tb_ifu_axi_engine.sv")]
    if args.negative_zero_inst:
        original = sources[1].read_text(encoding="ascii")
        anchor = "inst_q<=eng_rsp_data;"
        if original.count(anchor) != 1:
            raise RuntimeError("IFU_ZERO_INST_MUTATION_ANCHOR_MISSING")
        mutant = work / "ifu_zero_inst.v"
        mutant.write_text(original.replace(anchor, "inst_q<=0;"), encoding="ascii")
        sources[1] = mutant
    run([tools["vlib"], "work"], work, work / "vlib.log", 30)
    run([tools["vlog"], "-sv", "+incdir+" + str(root / "rtl/core")] +
        [str(p) for p in sources], work, work / "compile.log", 120)
    (work / "run.do").write_text(
        "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n", encoding="ascii")
    for seed in range(1, args.seeds + 1):
        log = work / f"seed-{seed}.log"
        try:
            text = run([tools["vsim"], "-c", "-onfinish", "stop",
                        "work.tb_ifu_axi_engine", f"+SEED={seed}", "-do", "run.do"],
                       work, log, 120)
        except RuntimeError as error:
            if not args.negative_zero_inst or not str(error).startswith("COMMAND_FAIL:"):
                raise
            text = log.read_text(encoding="utf-8", errors="replace")
        if args.negative_zero_inst:
            if "Fatal: IFU_HELD_IDENTITY" not in text or "TEST_PASS" in text:
                raise RuntimeError("IFU_ZERO_INST_MUTANT_NOT_REJECTED: " + str(log))
            print(f"PASS NEGATIVE_ZERO_INST seed={seed}", flush=True)
            continue
        validate_test(text, log)
        if "TEST_PASS IFU_REAL_ENGINE" not in text:
            raise RuntimeError("IFU_ENGINE_PASS_MISSING: " + str(log))
        print(f"PASS IFU_REAL_ENGINE seed={seed}", flush=True)
    print(f"SUMMARY {args.seeds}/{args.seeds} PASS", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("RUN_FAILED:", error, file=sys.stderr)
        sys.exit(1)
