"""Run ModelSim in private directories without shell aliases or shared work."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(r"E:\donwload\win64")


def run_case(case):
    out = ROOT / "sim/offline_checks" / case
    out.mkdir(parents=True, exist_ok=True)
    if case.startswith("rt") or case.startswith("deploy"):
        params=(ROOT/f"gen/integration/rtl_vectors/{case}/tb_params.vh"
                if case.startswith("deploy") else ROOT/f"gen/tb_params_{case}.vh")
        shutil.copyfile(params, out / "tb_params.vh")
        sources = ["tb/tb_engine_axil.v", "rtl/conv_engine_axil.v",
                   "rtl/conv_band_rt.v", "rtl/mac_array.v"]
        top, marker = "tb_engine_axil", "AXI-AXIL-PASS"
    elif case == "bulk":
        sources = ["tb/tb_acc_bulk.v", "rtl/conv_engine_axil.v",
                   "rtl/conv_band_rt.v", "rtl/mac_array.v"]
        top, marker = "tb_acc_bulk", "BULK_EQUIV_PASS"
    elif case == "tlul":
        sources = ["tb/tb_tlul_axil.v", "rtl/tlul_to_axil.v"]
        top, marker = "tb_tlul_axil", "TLUL_AXIL_PASS"
    elif case == "bridge":
        sources = ["tb/tb_ddr_bridge.v", "rtl/ddr_axi_bridge.v"]
        top, marker = "tb_ddr_bridge", "BRIDGE-PASS"
    elif case == "mmio":
        sources = ["tb/tb_acc_mmio.v", "rtl/conv_engine_axil.v",
                   "rtl/conv_band_rt.v", "rtl/mac_array.v"]
        top, marker = "tb_acc_mmio", "MMIO_PASS"
    elif case == "cdc":
        sources = ["tb/tb_cdc_path.v", "rtl/bridge_to_cdc.v", "rtl/axi_cdc.v"]
        top, marker = "tb_cdc_path", "CDC_PATH_PASS"
    elif case == "adapter":
        sources = ["tb/tb_axil_adapter.v", "rtl/axi4_to_axil.v"]
        top, marker = "tb_axil_adapter", "AXIL_ADAPTER_PASS"
    elif case == "snapshot":
        sources = ["tb/tb_camera_snapshot.v", "rtl/camera_snapshot.v"]
        top, marker = "tb_camera_snapshot", "SNAPSHOT_PASS"
    elif case == "video":
        sources = ["tb/tb_video_frontend.v", "rtl/video_ai_frontend.v",
                   "rtl/camera_snapshot.v"]
        top, marker = "tb_video_frontend", "VIDEO_FRONTEND_PASS"
    elif case == "arbiter":
        sources = ["tb/tb_native_arbiter.v", "rtl/ddr_native_arbiter.v"]
        top, marker = "tb_native_arbiter", "NATIVE_ARBITER_PASS"
    elif case == "boot":
        import struct
        import zlib
        from board_loader import request
        cpu=Path(r"C:\Users\lenovo\WorkBuddy\2026-10-27-00-18-16\pangoriscv\firmware\code")
        sources=["tb/tb_cpu_ai_boot.v"]
        for line in (ROOT/"pds/flow_soc.tcl").read_text().splitlines():
            if line.startswith("add_design ") and ".v\"" in line:
                value=line[len("add_design "):].strip('"')
                value=value.replace("$root",str(ROOT)).replace("$cpu",str(cpu))
                if value.endswith("yolo_soc_top.v"):
                    continue
                sources.append(value)
        value=0xfedcba9876543210
        req=request(1,0x01000000,struct.pack("<Q",value))+request(2,0x01000000)
        ack=struct.pack("<4sBHB",b"YAR1",0,0,0)
        ack+=struct.pack("<I",zlib.crc32(ack))
        response=struct.pack("<4sBHBQ",b"YAR1",0,8,0,value)
        response=ack+response+struct.pack("<I",zlib.crc32(response))
        for filename,payload in (("request.hex",req),("reply.hex",response)):
            (out/filename).write_text("".join(f"{b:02x}\n" for b in payload))
        (out/"cpu_boot_params.vh").write_text(
            f'`define BOOT_HEX "{(ROOT/"gen/integration/firmware/program.hex").as_posix()}"\n'
            f'`define REQUEST_HEX "{(out/"request.hex").as_posix()}"\n'
            f'`define REPLY_HEX "{(out/"reply.hex").as_posix()}"\n'
            f'`define BOOT_REQUEST_COUNT {len(req)}\n'
            f'`define BOOT_REPLY_COUNT {len(response)}\n')
        top,marker="tb_cpu_ai_boot","CPU_AI_BOOT_PASS"
    else:
        raise ValueError(case)
    commands = [
        [TOOLS / "vlib.exe", "work"],
        [TOOLS / "vlog.exe", "-sv", "+incdir+.",
         "+incdir+C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/pangoriscv/firmware/code/rtl/core",
         *[ROOT / p for p in sources]],
        [TOOLS / "vsim.exe", "-c", "-quiet", top, "-do",
         "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"],
    ]
    text = ""
    for index, command in enumerate(commands):
        completed = subprocess.run([str(p) for p in command], cwd=out,
                                   capture_output=True, text=True, errors="replace",
                                   timeout=300)
        log = completed.stdout + completed.stderr
        (out / f"{index}.log").write_text(log, encoding="utf-8")
        if completed.returncode:
            raise RuntimeError(log[-5000:])
        text = log
    if marker not in text or "FAIL" in text or "** Error" in text or "** Fatal" in text:
        raise RuntimeError(text[-7000:])
    print(case, next(line for line in text.splitlines() if marker in line))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("cases", nargs="*", default=["rt1", "rt2", "rt3"])
    for case in parser.parse_args().cases:
        run_case(case)
