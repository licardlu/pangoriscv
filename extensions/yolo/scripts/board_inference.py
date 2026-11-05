"""Measure a real-board image or camera request; retain replies and timings."""
import argparse
import json
from pathlib import Path
import time

from board_loader import (
    load_deployment,parse_detections,prepare_image,transact,write_image,
)

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--port",default="COM13")
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--image",type=Path)
    mode.add_argument("--camera",action="store_true")
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--reference",action="store_true")
    parser.add_argument("--timeout",type=float,default=180)
    args=parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=False)
    result=dict(board_test=True,full_acceptance=False,port=args.port,
                image=str(args.image) if args.image else None,stages={})
    started=time.monotonic()

    def stage(name,action):
        print(name+" START",flush=True)
        begin=time.monotonic()
        value=action()
        result["stages"][name]=dict(seconds=time.monotonic()-begin,passed=True)
        print(name+" PASS seconds="+str(round(time.monotonic()-begin,3)),flush=True)
        return value

    try:
        import serial
        manifest,_=load_deployment(ROOT/"gen/integration/packed")
        prepared=prepare_image(args.image) if args.image else None
        with serial.Serial(args.port,115200,timeout=args.timeout,write_timeout=10) as port:
            port.reset_input_buffer()
            stage("model_crc",lambda:transact(port,5))
            if prepared:
                packed,metadata=prepared
                stage("input_upload",lambda:write_image(
                    port,manifest["tensors"][0]["address"],packed))
                stage("image_geometry",lambda:transact(port,4,payload=metadata))
            raw=stage("inference",lambda:transact(port,6 if args.camera else 3))
        (args.out/"reply.bin").write_bytes(raw)
        result["detections"]=parse_detections(raw)
        print(json.dumps(result["detections"]),flush=True)
        if args.reference and prepared:
            import struct
            import numpy as np
            import torch
            from deployment_bundle import Deployment
            from gen_vexii_yolo_sim import CLASSES,decode
            torch.set_num_threads(4)
            tensor=np.frombuffer(packed,np.int8).reshape(320,320,8)[:,:,:3]
            image=torch.from_numpy(
                tensor.transpose(2,0,1)[None].astype(np.float32)/127.0)
            ratio,pad_x,pad_y,w,h=struct.unpack("<fffHH",metadata)
            with torch.no_grad():
                outputs=stage("software_reference",lambda:Deployment(
                    ROOT/"gen/integration/deployment").execute(image))
            expected=decode(outputs,w,h,ratio,pad_x,pad_y)
            result["expected"]=[dict(category=CLASSES[int(b[5])],score=b[4],box=b[:4])
                                for b in expected]
            remaining=list(result["detections"])
            matches=len(remaining)==len(expected)
            for exp in result["expected"]:
                options=[(i,b) for i,b in enumerate(remaining)
                         if b["category"]==exp["category"]]
                if not options:
                    matches=False
                    continue
                i,box=min(options,key=lambda item:sum(abs(a-b) for a,b in
                          zip(item[1]["box"],exp["box"])))
                remaining.pop(i)
                matches &= (max(abs(a-b) for a,b in zip(box["box"],exp["box"]))<1.0
                            and abs(box["score"]-exp["score"])<0.003)
            result["reference_match"]=bool(matches)
            if not matches:
                raise RuntimeError("Board detections differ from integer software reference")
            print("BOARD_REFERENCE_MATCH",flush=True)
        result["passed"]=True
    except Exception as exc:
        result.update(passed=False,error=f"{type(exc).__name__}: {exc}")
        raise
    finally:
        result["wall_seconds"]=time.monotonic()-started
        (args.out/"result.json").write_text(json.dumps(result,indent=2),encoding="utf-8")


if __name__=="__main__":
    main()
