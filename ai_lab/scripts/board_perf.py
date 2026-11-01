"""Measure board inference using a fixed image or consecutive camera frames."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import struct
import time

from board_loader import (
    load_deployment,parse_detections,prepare_image,transact,write_image,
)

ROOT=Path(__file__).resolve().parents[1]


def parse_profile(raw,graph):
    if len(raw)<32 or len(raw)%4:
        raise ValueError("Truncated timing profile")
    words=struct.unpack("<"+"I"*(len(raw)//4),raw)
    version,hz,flags,count=words[:4]
    if version!=1 or hz<=0 or count!=len(graph["ops"]) or len(words)!=8+count:
        raise ValueError("Timing profile does not match the deployed graph")
    by_kind=defaultdict(float)
    operators=[]
    for index,(op,cycles) in enumerate(zip(graph["ops"],words[8:])):
        seconds=cycles/hz
        by_kind[op["kind"]]+=seconds
        operators.append(dict(index=index,kind=op["kind"],seconds=seconds,cycles=cycles))
    return dict(cpu_hz=hz,flags=flags,
                stages=dict(zip(("capture","forward","decode","display"),
                                (v/hz for v in words[4:8]))),
                seconds_by_kind=dict(by_kind),operators=operators)


def compare_detections(expected,actual):
    remaining=list(actual)
    if len(expected)!=len(actual):
        raise ValueError("Optimization changed the detection count")
    largest_box=largest_score=0.0
    for box in expected:
        options=[(i,b) for i,b in enumerate(remaining) if b["category"]==box["category"]]
        if not options:
            raise ValueError("Optimization changed a detection category")
        index,matched=min(options,key=lambda p:sum(
            abs(a-b) for a,b in zip(p[1]["box"],box["box"])))
        remaining.pop(index)
        largest_box=max(largest_box,max(abs(a-b) for a,b in zip(matched["box"],box["box"])))
        largest_score=max(largest_score,abs(matched["score"]-box["score"]))
    if largest_box>1.0 or largest_score>0.003:
        raise ValueError(f"Optimization changed detections: {largest_box=}, {largest_score=}")
    return dict(max_box_error_pixels=largest_box,max_score_error=largest_score)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--port",default="COM13")
    source=parser.add_mutually_exclusive_group()
    source.add_argument("--image",type=Path)
    source.add_argument("--camera",action="store_true")
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--modes",type=int,nargs="+",default=[0,31,63])
    parser.add_argument("--skip-upload",action="store_true")
    parser.add_argument("--final-mode",type=int,default=63)
    args=parser.parse_args()
    if not args.camera and args.image is None:
        args.image=ROOT/"data/images/testset/plastic__plastic1.jpg"
    args.out.mkdir(parents=True,exist_ok=False)
    manifest,_=load_deployment(ROOT/"gen/integration/packed")
    report=dict(board_test=True,image=str(args.image) if args.image else None,
                camera=args.camera,runs=[],passed=False)
    try:
        import serial
        with serial.Serial(args.port,115200,timeout=240,write_timeout=10) as port:
            port.reset_input_buffer()
            transact(port,5)
            if not args.camera and not args.skip_upload:
                packed,metadata=prepare_image(args.image)
                write_image(port,manifest["tensors"][0]["address"],packed)
                transact(port,4,payload=metadata)
            for index,mode in enumerate(args.modes):
                if transact(port,9,mode)!=struct.pack("<I",mode):
                    raise ValueError("Firmware did not accept the requested optimization mode")
                print(f"INFERENCE mode={mode} START",flush=True)
                started=time.monotonic()
                raw=transact(port,6 if args.camera else 3)
                elapsed=time.monotonic()-started
                (args.out/f"reply_run{index}_mode{mode}.bin").write_bytes(raw)
                detections=parse_detections(raw)
                profile=parse_profile(transact(port,8),manifest)
                if profile["flags"]!=mode:
                    raise ValueError("Profile was collected for a different optimization mode")
                measured=sum(profile["stages"].values())
                if measured<=0 or abs(measured-elapsed)>max(.2,.05*elapsed):
                    raise ValueError(f"Device cycle timing disagrees with wall clock: {measured}, {elapsed}")
                run=dict(mode=mode,wall_seconds=elapsed,detections=detections,profile=profile)
                if report["runs"] and not args.camera:
                    run["comparison"]=compare_detections(report["runs"][0]["detections"],detections)
                report["runs"].append(run)
                (args.out/"result.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
                print(json.dumps(dict(mode=mode,seconds=elapsed,
                    seconds_by_kind=profile["seconds_by_kind"],detections=detections)),flush=True)
            transact(port,9,args.final_mode)
        report["passed"]=True
    except Exception as exc:
        report["error"]=f"{type(exc).__name__}: {exc}"
        raise
    finally:
        (args.out/"result.json").write_text(json.dumps(report,indent=2),encoding="utf-8")


if __name__=="__main__":
    main()
