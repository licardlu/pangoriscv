"""Stage and optionally build a Vexii/video/AI candidate; never programs hardware."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from build_camera import PDS, accept_build
from generate_camera_top import VIDEO
from generate_vexii_camera import generate
from generate_vexii_soc import CPU, OUT, ROOT


def prepare():
    subprocess.run([sys.executable, str(ROOT / "scripts/build_firmware.py"),
                    "--platform", "vexii", "--cpu-hz", "27000000"], check=True)
    camera = generate()
    folder = ROOT / "pds" / ("vexii_camera_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
    folder.mkdir()
    snapshot = folder / "sources"
    snapshot.mkdir()
    cpu_sources = [CPU / line for line in (CPU / "sources.f").read_text().splitlines()
                   if line and "MicroSoc.v" not in line and "rtl/board/" not in line]
    cpu_sources = [OUT / "TilelinkUartCtrl.v" if p.name == "TilelinkUartCtrl.v" else p
                   for p in cpu_sources]
    sources = cpu_sources + [OUT / "vexii_ai_soc.v"]
    sources += [ROOT / "rtl" / name for name in (
        "tlul_to_axil.v", "conv_band_rt.v", "mac_array.v", "conv_engine_axil.v",
        "ddr_axi_bridge.v", "bridge_to_cdc.v", "axi_cdc.v",
        "camera_snapshot.v", "video_ai_frontend.v", "ddr_native_arbiter.v")]
    sources += list(camera.glob("*.v"))
    sources += [p for p in (VIDEO / "source/rtl").glob("*.v")
                if p.name != "hdmi_ddr_ov5640_top.v"]
    sources += [VIDEO / "ipcore" / name / (name + ".idf")
                for name in ("ddr3_test", "pll", "rd_fram_buf", "wr_fram_buf")]
    firmware = ROOT / "gen/integration/vexii_firmware"
    metadata = json.loads((firmware / "manifest.json").read_text())
    if metadata["sim_preload"] or metadata["cpu_hz"] != 27000000:
        raise ValueError("Board candidate requires normal 27 MHz firmware")
    data = (firmware / "firmware.bin").read_bytes().ljust(65536, b"\0")
    lane_paths = []
    for lane in range(8):
        target = snapshot / f"firmware_lane{lane}.bin"
        target.write_text("".join(f"{b:08b}\n" for b in data[lane::8]), encoding="ascii")
        lane_paths.append(target)
    captured = []
    design = []
    for index, path in enumerate(dict.fromkeys(p.resolve() for p in sources)):
        if not path.is_file():
            raise FileNotFoundError(path)
        if path.suffix == ".idf":
            design.append(path)
            continue
        target = snapshot / f"{index:03}_{path.name}"
        if path.name == "Ram.v":
            text = path.read_text(encoding="utf-8")
            for lane, lane_path in enumerate(lane_paths):
                old = f'MicroSoc.v_toplevel_system_ram_thread_logic_mem_symbol{lane}.bin'
                if text.count(old) != 1:
                    raise ValueError(f"RAM initialization template changed: {old}")
                text = text.replace(old, lane_path.as_posix(), 1)
            target.write_text(text, encoding="utf-8")
        else:
            # Several vendor video files contain GBK comments. Copy their
            # original bytes rather than transcoding untouched RTL.
            shutil.copy2(path, target)
        captured.append(dict(original=str(path), snapshot=str(target),
                             sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
        design.append(target)
    include = snapshot / "include"
    include.mkdir()
    for path in (CPU / "rtl/core").rglob("*.vh"):
        target = include / path.relative_to(CPU / "rtl/core")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    shutil.copy2(camera / "camera.fdc", snapshot / "camera.fdc")
    for name in ("firmware.bin", "firmware.elf", "manifest.json"):
        shutil.copy2(firmware / name, snapshot / name)
    (folder / "manifest.json").write_text(json.dumps(dict(
        firmware=metadata, sources=captured, board_verified=False,
        cpu_clock_hz=27000000, top="yolo_camera_top"), indent=2), encoding="utf-8")
    lines = [f'add_design "{p.as_posix()}"' for p in design]
    lines += [
        f'add_constraint "{(snapshot / "camera.fdc").as_posix()}"',
        "set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676",
        f'compile -top_module yolo_camera_top -include_path "{include.as_posix()}"',
        "synthesize -ads -selected_syn_tool_opt 2", "dev_map",
    ]
    return folder, lines


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--synthesis-only", action="store_true")
    args = parser.parse_args()
    folder, lines = prepare()
    if not args.synthesis_only:
        lines += ["pnr -plc_decongestion 1 -share_router_control_signal TRUE",
                  "report_timing", "gen_bit_stream"]
    flow = folder / "flow.tcl"
    flow.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("VEXII_CAMERA_BUILD_PREPARED", folder, flush=True)
    if args.run:
        with (folder / "shell.log").open("w", encoding="utf-8") as log:
            result = subprocess.run([str(PDS), "-file", str(flow)], cwd=folder,
                                    stdout=log, stderr=subprocess.STDOUT)
        text = (folder / "shell.log").read_text(encoding="utf-8", errors="replace")
        errors = re.findall(r"^.*(?:\bERROR\b|\bError:|\[Error\]|^E:).*$", text, re.M)
        if result.returncode or errors:
            raise RuntimeError(f"Build failed: {folder}\n" + "\n".join(errors[-20:]))
        accepted = accept_build(folder, args.synthesis_only)
        print(f"VEXII_CAMERA_BUILD_ACCEPTED {folder}; routed={accepted['routed']}; "
              "board_verified=False")


if __name__ == "__main__":
    main()
