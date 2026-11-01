"""Build a fresh camera+CPU+AI candidate without programming the board."""
import argparse
from datetime import datetime
from pathlib import Path
import re
import subprocess
import hashlib
import json
import shutil
import sys

from generate_camera_top import ROOT,VIDEO,generate

PDS=Path(r"E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe")


def accept_build(folder, synthesis_only):
    mapped=folder/"device_map/run.log"
    if not mapped.is_file():
        raise RuntimeError("Missing device-map resource report")
    text=mapped.read_text(encoding="utf-8",errors="replace")
    resources={}
    for name,used,available in re.findall(
            r"\|\s*(APM|FF|LUT|Distributed RAM|DRM|IO)\s*\|\s*"
        r"([0-9.]+)\s*\|\s*([0-9.]+)\s*\|",text):
        resources[name]=dict(used=float(used),available=float(available))
    if len(resources)!=6 or any(r["used"]>r["available"] for r in resources.values()):
        raise RuntimeError(f"Missing or over-budget resources: {resources}")
    result=dict(resources=resources,board_verified=False,
                routed=False,timing_pass=False,bitstream=None)
    if not synthesis_only:
        routed=(folder/"place_route/run.log").read_text(encoding="utf-8",errors="replace")
        summary=folder/"place_route/yolo_camera_top_timing_summary_after_hold_fix.txt"
        if "has been placed and routed successfully" not in routed or not summary.is_file():
            raise RuntimeError("Routing did not finish with a timing summary")
        timing=summary.read_text(encoding="utf-8",errors="replace")
        final=folder/"report_timing/yolo_camera_top.rtr"
        final_text=final.read_text(encoding="utf-8",errors="replace") if final.is_file() else ""
        if ("Design Summary : All Constraints Met." not in timing or not final_text or
                "VIOLATED" in final_text or "Some Constraints Violated" in final_text):
            raise RuntimeError(f"Setup/hold constraints failed: {summary}")
        bits=list(folder.glob("**/*.sbit"))
        if len(bits)!=1 or not bits[0].stat().st_size:
            raise RuntimeError("Expected one nonempty generated bitstream")
        result.update(routed=True,timing_pass=True,bitstream=str(bits[0]),
                      bitstream_sha256=hashlib.sha256(bits[0].read_bytes()).hexdigest())
    (folder/"acceptance.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--run",action="store_true")
    parser.add_argument("--synthesis-only",action="store_true")
    args=parser.parse_args()
    subprocess.run([sys.executable,str(ROOT/"scripts/pack_deployment.py")],check=True)
    subprocess.run([sys.executable,str(ROOT/"scripts/build_firmware.py"),
                    "--cpu-hz","27000000"],check=True)
    generate()
    folder=ROOT/"pds"/("camera_offline_"+datetime.now().strftime("%Y%m%d_%H%M%S"))
    folder.mkdir()
    cpu=Path(r"C:\Users\lenovo\WorkBuddy\2026-10-27-00-18-16\pangoriscv\firmware\code")
    paths=[]
    source=(ROOT/"pds/flow_soc.tcl").read_text()
    for line in source.splitlines():
        if line.startswith("add_design "):
            value=line[len("add_design "):].strip('"')
            value=value.replace("$root",ROOT.as_posix()).replace("$cpu",cpu.as_posix())
            value=value.replace("$vid",(VIDEO/"ipcore").as_posix())
            if value.endswith("/yolo_soc_top.v"):
                continue
            paths.append(Path(value))
    paths.extend(p for p in (VIDEO/"source/rtl").glob("*.v")
                 if p.name!="hdmi_ddr_ov5640_top.v")
    paths.extend(VIDEO/"ipcore"/n/(n+".idf") for n in ("rd_fram_buf","wr_fram_buf"))
    paths.extend(ROOT/"rtl"/p for p in ("camera_snapshot.v","video_ai_frontend.v",
                                       "ddr_native_arbiter.v"))
    paths.extend((ROOT/"gen/integration/camera").glob("*.v"))
    unique=list(dict.fromkeys(p.resolve() for p in paths))
    missing=[str(p) for p in unique if not p.is_file()]
    if missing:
        raise FileNotFoundError(missing)
    firmware=ROOT/"gen/integration/firmware"
    metadata=json.loads((firmware/"manifest.json").read_text())
    if metadata["cpu_hz"]!=27000000:
        raise ValueError("Camera build requires firmware compiled for 27 MHz")
    snapshot=folder/"sources"
    captured=[]
    design=[]
    for p in unique:
        if p.suffix.lower()==".idf":
            design.append(p)
            continue
        for category,parent in (("cpu",cpu),("video",VIDEO),("ai",ROOT)):
            if p.is_relative_to(parent):
                relative=Path(category)/p.relative_to(parent)
                break
        else:
            raise ValueError(f"Unowned source path {p}")
        target=snapshot/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,target)
        if p.name=="yolo_camera_top.v":
            target.write_text(target.read_text(encoding="utf-8").replace(
                (firmware/"program.hex").as_posix(),(snapshot/"program.hex").as_posix()),
                encoding="utf-8")
        captured.append(dict(original=str(p),snapshot=str(target),
                             sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
        design.append(target)
    shutil.copy2(firmware/"program.hex",snapshot/"program.hex")
    for p in list((cpu/"rtl/core").glob("*.vh"))+list((cpu/"rtl/core").glob("*.v")):
        if p.suffix==".v" and p.name!="defines.v":
            continue
        target=snapshot/"cpu/rtl/core"/p.name
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,target)
    (folder/"manifest.json").write_text(json.dumps(dict(
        firmware=metadata,sources=captured,board_verified=False),indent=2),encoding="utf-8")
    shutil.copy2(ROOT/"gen/integration/camera/camera.fdc",snapshot/"camera.fdc")
    lines=[f'add_design "{p.as_posix()}"' for p in design]
    lines.extend([
        f'add_constraint "{(snapshot/"camera.fdc").as_posix()}"',
        "set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676",
        f'compile -top_module yolo_camera_top -include_path "{(snapshot/"cpu/rtl/core").as_posix()}"',
        "synthesize -ads -selected_syn_tool_opt 2","dev_map"])
    if not args.synthesis_only:
        lines.extend(["pnr -plc_decongestion 1 -share_router_control_signal TRUE",
                      "report_timing","gen_bit_stream"])
    flow=folder/"flow.tcl"
    flow.write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(f"CAMERA_BUILD_PREPARED {folder}",flush=True)
    if args.run:
        with (folder/"shell.log").open("w",encoding="utf-8") as log:
            completed=subprocess.run([str(PDS),"-file",str(flow)],cwd=folder,
                                     stdout=log,stderr=subprocess.STDOUT)
        text=(folder/"shell.log").read_text(encoding="utf-8",errors="replace")
        errors=re.findall(r"^.*(?:\bERROR\b|\bError:|\[Error\]|^E:).*$",text,re.M)
        if completed.returncode or errors:
            raise RuntimeError(f"Build failed: {folder}\n"+"\n".join(errors[-20:]))
        result=accept_build(folder,args.synthesis_only)
        print(f"OFFLINE_BUILD_ACCEPTED {folder}; routed={result['routed']}; "
              "board_verified=False")


if __name__=="__main__":
    main()
