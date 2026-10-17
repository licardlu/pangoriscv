"""Compile the operation-interface CPU; never mix unrelated core sources."""
from pathlib import Path
import shutil
import tempfile
from runner_common import run, validate_test

root = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix="pipeline-", dir=root / ".sim_runs"))
print("RUN_DIR", work, flush=True)
sources = ["pipe_slot", "if_id", "id_ex", "pc_reg", "ctrl", "regs", "id",
           "ex", "div", "div_adapter", "retire_ctrl", "csr_native", "pangoriscv"]
run([shutil.which("vlib"), "work"], work, work / "vlib.log", 30)
run([shutil.which("vlog"), "-sv", "+incdir+" + str(root / "rtl/core")] +
    [str(root / ("rtl/core/" + name + ".v")) for name in sources] +
    [str(root / "tb/unit/tb_pipeline.sv")], work, work / "compile.log", 120)
(work / "run.do").write_text(
    "onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n", encoding="ascii")
log = work / "simulation.log"
text = run([shutil.which("vsim"), "-c", "-onfinish", "stop",
            "work.tb_pipeline", "-do", "run.do"], work, log, 120)
validate_test(text, log)
assert "TEST_PASS N03_PIPELINE" in text
print("PASS N03_PIPELINE", flush=True)
