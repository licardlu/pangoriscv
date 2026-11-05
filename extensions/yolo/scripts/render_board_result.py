"""Render actual UART detections; optionally read a sampled camera input DDR tensor."""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np

from board_loader import transact


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--result",type=Path,required=True)
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--camera-ddr",action="store_true")
    parser.add_argument("--port",default="COM13")
    args=parser.parse_args()
    result=json.loads(args.result.read_text())
    if not result.get("passed") or not result.get("board_test"):
        raise ValueError("Require a successful real-board inference result")
    args.out.mkdir(parents=True,exist_ok=False)
    if args.camera_ddr:
        import serial
        sampled=np.zeros((45,80,3),np.uint8)
        with serial.Serial(args.port,115200,timeout=5,write_timeout=3) as port:
            port.reset_input_buffer()
            for y in range(45):
                for x in range(80):
                    address=0x02000000+((70+y*4)*320+x*4)*8
                    raw=transact(port,2,address)
                    if len(raw)!=8 or any(raw[3:]):
                        raise ValueError("Camera input word has invalid channel padding")
                    values=np.frombuffer(raw[:3],np.int8).astype(np.int32)
                    if np.any(values<0):
                        raise ValueError("Camera input RGB values must be nonnegative")
                    sampled[y,x]=np.rint(values*255/127).astype(np.uint8)
                if y%9==0:
                    print(f"CAMERA_DDR_READ {y+1}/45 rows",flush=True)
        np.save(args.out/"sampled_rgb.npy",sampled)
        image=cv2.cvtColor(cv2.resize(sampled,(640,360),interpolation=cv2.INTER_NEAREST),
                           cv2.COLOR_RGB2BGR)
        sx=sy=0.5
        metrics=dict(sampled=True,source="real board DDR after camera preprocessing",
                     min=int(sampled.min()),max=int(sampled.max()),
                     unique_rgb=int(len(np.unique(sampled.reshape(-1,3),axis=0))))
    else:
        path=Path(result["image"])
        image=cv2.imdecode(np.fromfile(path,dtype=np.uint8),cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError("Cannot decode original test image")
        sx=sy=1
        metrics=dict(sampled=False,source="original test image with real FPGA detections")
    for item in result["detections"]:
        x1,y1,x2,y2=item["box"]
        a=(int(x1*sx),int(y1*sy))
        b=(int(x2*sx),int(y2*sy))
        cv2.rectangle(image,a,b,(30,230,60),2)
        label=f'{item["category"]} {item["score"]:.3f}'
        xy=(a[0],max(a[1]-7,16))
        cv2.putText(image,label,xy,cv2.FONT_HERSHEY_SIMPLEX,0.5,(0,0,0),3,cv2.LINE_AA)
        cv2.putText(image,label,xy,cv2.FONT_HERSHEY_SIMPLEX,0.5,(30,230,60),1,cv2.LINE_AA)
    cv2.imencode(".png",image)[1].tofile(args.out/"board_detection.png")
    (args.out/"source.json").write_text(json.dumps(metrics,indent=2),encoding="utf-8")
    print("BOARD_RENDERED",json.dumps(metrics),flush=True)


if __name__=="__main__":
    main()
