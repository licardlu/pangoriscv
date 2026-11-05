"""Compile and run tb_vexii_yolo: the real firmware executes the whole graph.

The DDR contents are preloaded from the packed model image, exactly the bytes
board_loader.py would stream over the UART; the firmware still verifies the blob
CRC before it runs anything.  The sensor is a file-driven frame.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys

from generate_vexii_soc import ROOT,CPU,OUT,generate
import tool_paths

RUN=ROOT/"gen/integration/yolo_sim"
EXTRA=("tlul_to_axil.v","conv_engine_axil.v","conv_band_rt.v","requant_q15.v","mac_array.v",
       "video_ai_frontend.v","camera_snapshot.v")


def lanes(run,firmware):
    data=(firmware/"firmware.bin").read_bytes()
    if len(data)>65536: raise ValueError("firmware exceeds 64 KiB")
    length=len(data)
    data=data.ljust(65536,b"\0")
    for lane in range(8):
        (run/f"MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin").write_text(
            "".join(f"{value:08b}\n" for value in data[lane::8]),encoding="ascii")
    return length


def compile_and_run(timeout,preloaded=False,modelsim=None):
    TOOLS=tool_paths.modelsim_bin(modelsim)
    generate()
    sources=[CPU/line for line in (CPU/"sources.f").read_text().splitlines()
             if line and "MicroSoc.v" not in line and "rtl/board/" not in line]
    sources=[OUT/"TilelinkUartCtrl.v" if p.name=="TilelinkUartCtrl.v" else p
             for p in sources]
    vlog=[TOOLS/"vlog.exe","-sv",f"+incdir+{CPU/'rtl/core'}",
          *(["+define+PRELOADED_INFERENCE"] if preloaded else []),
          OUT/"vexii_ai_soc.v",*[ROOT/"rtl"/n for n in EXTRA],
          ROOT/"tb/tb_vexii_yolo.v",*sources]
    for cmd in ([TOOLS/"vlib.exe","work"],vlog):
        r=subprocess.run([str(x) for x in cmd],cwd=RUN,capture_output=True,text=True,
                         errors="replace",timeout=600)
        (RUN/"compile.log").write_text(r.stdout+r.stderr,encoding="utf-8")
        if r.returncode or "** Error" in r.stdout+r.stderr:
            print((r.stdout+r.stderr)[-4000:]);sys.exit(1)
    vsim=[TOOLS/"vsim.exe","-c","-quiet","tb_vexii_yolo","-do",
          "onerror {quit -code 1}; run -all; quit -code 0"]
    try:
        r=subprocess.run([str(x) for x in vsim],cwd=RUN,capture_output=True,text=True,
                         errors="replace",timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        stdout=exc.stdout or ""
        stderr=exc.stderr or ""
        if isinstance(stdout,bytes): stdout=stdout.decode("utf-8","replace")
        if isinstance(stderr,bytes): stderr=stderr.decode("utf-8","replace")
        partial=stdout+stderr
        (RUN/"vsim.log").write_text(partial,encoding="utf-8")
        print(f"YOLO_SIM_TIMEOUT after {timeout}s; partial simulator output saved")
        for line in partial.splitlines():
            if any(k in line for k in ("SIM_","ACC_START","ACC_DONE","DDR_BAD")):
                print(line)
        raise
    (RUN/"vsim.log").write_text(r.stdout+r.stderr,encoding="utf-8")
    return r.stdout+r.stderr


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--skip-build",action="store_true")
    parser.add_argument("--timeout",type=int,default=3600)
    parser.add_argument("--preloaded",action="store_true")
    parser.add_argument("--modelsim",type=Path,
                        help="ModelSim win64 目录；默认读 MODELSIM_BIN")
    parser.add_argument("--gcc",type=Path,
                        help="RISC-V GCC bin 目录；默认读 RISCV_GCC_BIN")
    args=parser.parse_args()
    RUN.mkdir(parents=True,exist_ok=True)
    firmware=RUN/"firmware"
    manifest=firmware/"manifest.json"
    if not args.skip_build:
        build=[sys.executable,str(ROOT/"scripts/build_firmware.py"),
               "--platform","vexii","--cpu-hz","100000000",
               "--out",str(firmware)]
        if args.gcc: build.extend(["--gcc",str(args.gcc)])
        if args.preloaded: build.append("--sim-preload")
        subprocess.run(build,check=True)
    else:
        metadata=json.loads(manifest.read_text()) if manifest.is_file() else {}
        if (metadata.get("platform")!="vexii" or
            metadata.get("cpu_hz")!=100000000 or
            metadata.get("sim_preload") is not args.preloaded or
            not (firmware/"firmware.bin").is_file()):
            raise SystemExit(
                "--skip-build requires a matching private firmware image; "
                "run again without --skip-build")
    command_file=RUN/("cmd_preloaded.hex" if args.preloaded else "cmd_full.hex")
    if not command_file.is_file():
        raise SystemExit(f"missing {command_file}; run gen_vexii_yolo_sim.py first")
    shutil.copyfile(command_file,RUN/"cmd.hex")
    print("firmware bytes",lanes(RUN,firmware))
    text=compile_and_run(args.timeout,args.preloaded,args.modelsim)
    for line in text.splitlines():
        if any(k in line for k in ("SIM_","DDR_BAD","MODEL_PRELOAD")):
            print(line)
    tx=(RUN/"tx.log").read_text().split()
    print("tx bytes",len(tx))
    if "SIM_DONE" not in text or "SIM_TIMEOUT" in text:
        raise SystemExit("YOLO simulation did not complete; inspect vsim.log")
    result=subprocess.run([sys.executable,str(ROOT/"scripts/check_vexii_yolo.py")],
                          cwd=ROOT,capture_output=True,text=True)
    print(result.stdout,end="")
    if result.returncode:
        print(result.stderr,end="")
        raise SystemExit(result.returncode)


if __name__=="__main__":
    main()
