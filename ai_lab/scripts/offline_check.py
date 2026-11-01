"""Necessary offline checks, one command, no serial/JTAG access."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]


def call(*args):
    command=[str(x) for x in args]
    print("+ "+" ".join(command),flush=True)
    subprocess.run(command,cwd=ROOT,check=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--skip-rtl",action="store_true")
    args=parser.parse_args()
    build=ROOT/"sim/offline_checks"
    build.mkdir(parents=True,exist_ok=True)
    summary=build/"offline_summary.json"
    summary.write_text(json.dumps(dict(
        offline_checks_pass=False,board_tested=False,status="running")),encoding="utf-8")
    try:
        for name in ("test_graph_contract.py","test_deployment_math.py",
                     "test_pack_deployment.py","test_board_protocol.py",
                     "test_board_loader.py","test_vexii_smoke.py"):
            call(sys.executable,ROOT/"scripts"/name)
        call(sys.executable,ROOT/"scripts/pack_deployment.py")
        call(sys.executable,ROOT/"scripts/build_firmware.py",
             "--platform","vexii","--cpu-hz","27000000")
        call(sys.executable,ROOT/"scripts/board_loader.py","--check")
        call(sys.executable,ROOT/"scripts/test_deployment_cpu.py","--export",
             ROOT/"gen/integration/cpu_oracle.npz")
        call(sys.executable,ROOT/"scripts/gen_deployment_vectors.py")
        call(sys.executable,ROOT/"scripts/run_native_checks.py")
        if not args.skip_rtl:
            call(sys.executable,ROOT/"scripts/run_rtl_checks.py",
                 "mmio","bulk","tlul","bridge","cdc","adapter","snapshot","video","arbiter","boot",
                 "deploy0","deploy1","deploy22","deploy81")
            call(sys.executable,ROOT/"scripts/run_vexii_smoke.py","--accelerator")
            call(sys.executable,ROOT/"scripts/run_vexii_smoke.py","--firmware")
            call(sys.executable,ROOT/"scripts/run_vexii_client.py")
        call(sys.executable,ROOT/"scripts/test_release_package.py")
    except Exception as exc:
        summary.write_text(json.dumps(dict(
            offline_checks_pass=False,board_tested=False,status="failed",
            error=f"{type(exc).__name__}: {exc}"),indent=2),encoding="utf-8")
        raise
    summary.write_text(json.dumps(dict(
        offline_checks_pass=True,status="passed",rtl_checked=not args.skip_rtl,
        native_full_graph_checked=True,board_tested=False,
        full_network_rtl=False,mechanical_sorting=False,
        limits=["CPU operator unit checks use oracle conv; full graph uses scalar C conv",
                "Native full graph does not simulate the complete RTL system",
                "No complete camera-to-result system simulation or board measurement",
                "PDS resource and timing acceptance must be checked separately"]),indent=2),
        encoding="utf-8")
    print("OFFLINE_CHECK_PASS; this is not a board acceptance certificate")


if __name__=="__main__":
    main()
