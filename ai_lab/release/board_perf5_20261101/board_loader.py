"""Stop-and-wait serial loader for the RV32IM firmware. No FPGA programming.

All board access is opt-in via --port. --check performs offline validation only.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
NAMES=("biodegradable","cardboard","glass","metal","paper","plastic")


def request(command,address=0,payload=b""):
    if len(payload)>256:
        raise ValueError("Request payload exceeds firmware buffer")
    prefix=struct.pack("<4sBBHI",b"YAI1",command,0,len(payload),address)
    return prefix+struct.pack("<I",zlib.crc32(prefix+payload))+payload


def parse_reply(packet):
    if len(packet)<12 or packet[:4]!=b"YAR1" or packet[7]!=0:
        raise ValueError("Invalid reply header")
    _,status,length,_=struct.unpack("<4sBHB",packet[:8])
    if len(packet)!=12+length:
        raise ValueError("Invalid reply length")
    if zlib.crc32(packet[:-4])!=struct.unpack("<I",packet[-4:])[0]:
        raise ValueError("Reply CRC mismatch")
    if status:
        raise RuntimeError(f"Firmware error {status}: {packet[8:-4].hex()}")
    return packet[8:-4]


def read_exact(port,count):
    data=bytearray()
    while len(data)<count:
        part=port.read(count-len(data))
        if not part:
            raise TimeoutError(
                f"Incomplete firmware reply ({len(data)}/{count} bytes); "
                "reset/reconnect before retrying, do not replay writes blindly")
        data.extend(part)
    return bytes(data)


def transact(port,command,address=0,payload=b""):
    frame=request(command,address,payload)
    if port.write(frame)!=len(frame):
        raise IOError("Incomplete UART write; reset/reconnect before retrying")
    header=read_exact(port,8)
    if header[:4]!=b"YAR1" or header[7]!=0:
        raise ValueError("Invalid reply header; reset/reconnect before retry")
    length=struct.unpack("<H",header[5:7])[0]
    if length>1024:
        raise ValueError("Oversized reply; reset/reconnect before retry")
    body=read_exact(port,length+4)
    return parse_reply(header+body)


def parse_detections(raw):
    if len(raw)<4:
        raise ValueError("Malformed detection payload")
    count=struct.unpack_from("<I",raw)[0]
    if count>32 or len(raw)!=4+count*24:
        raise ValueError("Malformed detection payload")
    results=[]
    for i in range(count):
        x1,y1,x2,y2,score,category=struct.unpack_from("<5fI",raw,4+i*24)
        if category>=len(NAMES):
            raise ValueError(f"Invalid detection category {category}")
        if (not all(math.isfinite(v) for v in (x1,y1,x2,y2,score)) or
            not 0<=score<=1 or x2<x1 or y2<y1):
            raise ValueError("Invalid detection coordinates or score")
        results.append(dict(category=NAMES[category],score=score,box=[x1,y1,x2,y2]))
    return results


def prepare_image(path):
    # Keep OpenCV interpolation/rounding identical to deployment calibration.
    import cv2
    import numpy as np
    image=cv2.imdecode(np.fromfile(path,dtype=np.uint8),cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError(f"Cannot decode image: {path}")
    h,w=image.shape[:2]
    if w>65535 or h>65535:
        raise ValueError("Image dimensions exceed the firmware uint16 metadata")
    ratio=min(320/h,320/w)
    nh,nw=int(round(h*ratio)),int(round(w*ratio))
    if not nh or not nw:
        raise ValueError("Image aspect ratio is too extreme for 320x320 input")
    top,left=(320-nh)//2,(320-nw)//2
    canvas=np.full((320,320,3),114,np.uint8)
    canvas[top:top+nh,left:left+nw]=cv2.resize(image,(nw,nh))
    rgb=canvas[:,:,::-1].astype(np.float32)/255.0
    packed=np.zeros((320,320,8),np.int8)
    packed[:,:,:3]=np.floor(rgb*127+0.5).astype(np.int8)
    return packed.tobytes(),struct.pack("<fffHH",ratio,left,top,w,h)


def write_image(port,address,payload):
    if len(payload)%8:
        raise ValueError("DDR transfers must be 64-bit aligned")
    for index in range(0,len(payload),256):
        transact(port,1,address+index,payload[index:index+256])
        if index%65536==0:
            print(f"load {index}/{len(payload)}",flush=True)


def load_deployment(folder):
    manifest=json.loads((folder/"memory_map.json").read_text(encoding="utf-8"))
    blob=(folder/"model.bin").read_bytes()
    if (len(blob)!=manifest["blob_length"] or
        zlib.crc32(blob)!=manifest["blob_crc32"] or
        hashlib.sha256(blob).hexdigest()!=manifest["blob_sha256"]):
        raise ValueError("Model blob/manifest mismatch")
    return manifest,blob


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--port")
    parser.add_argument("--baud",type=int,default=115200)
    parser.add_argument("--check",action="store_true")
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument("--image",type=Path)
    parser.add_argument("--skip-model",action="store_true")
    mode.add_argument("--camera",action="store_true")
    parser.add_argument("--frames",type=int,default=1)
    mode.add_argument("--autonomous",action="store_true")
    parser.add_argument(
        "--package-dir",type=Path,
        help="load model.bin and memory_map.json from a release package",
    )
    args=parser.parse_args()
    if args.frames<1:
        parser.error("--frames must be positive")
    folder=(args.package_dir.resolve() if args.package_dir
            else ROOT/"gen/integration/packed")
    manifest,blob=load_deployment(folder)
    if args.check:
        print("LOADER_OFFLINE_PASS model length and CRC; no serial access")
        return
    if not args.port:
        parser.error("--port is required for hardware access; use --check offline")
    prepared=prepare_image(args.image) if args.image else None
    import serial
    with serial.Serial(args.port,args.baud,timeout=600,write_timeout=10) as port:
        if not args.skip_model:
            write_image(port,manifest["blob_base"],blob)
        transact(port,5)  # Device independently reads back and checks model CRC.
        if args.autonomous:
            transact(port,7)
            print("Autonomous camera recognition started. Reset the board to stop.")
            return
        if args.camera:
            for frame in range(args.frames):
                raw=transact(port,6)
                print(json.dumps(dict(frame=frame+1,detections=parse_detections(raw))),
                      flush=True)
            return
        if args.image:
            packed,metadata=prepared
            write_image(port,manifest["tensors"][0]["address"],packed)
            transact(port,4,payload=metadata)
            raw=transact(port,3)
            print(json.dumps(parse_detections(raw)))


if __name__=="__main__":
    main()
