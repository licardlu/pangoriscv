"""Parse tx.log from tb_vexii_yolo and compare with the Python reference."""
from pathlib import Path
import json
import struct
import sys
import zlib

ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/"gen/integration/yolo_sim"
CLASSES=["biodegradable","cardboard","glass","metal","paper","plastic"]


def replies(path):
    data=bytes(int(x,16) for x in path.read_text().split())
    out=[];at=0
    while at+8<=len(data):
        if data[at:at+4]!=b"YAR1": raise ValueError(f"resync at {at}: {data[at:at+8]!r}")
        _,status,length,_=struct.unpack("<4sBHB",data[at:at+8])
        total=12+length
        if at+total>len(data): break
        crc=struct.unpack("<I",data[at+8+length:at+12+length])[0]
        if zlib.crc32(data[at:at+8+length])!=crc:
            raise ValueError(f"reply CRC mismatch at {at}")
        payload=data[at+8:at+8+length]
        out.append((status,payload))
        at+=total
    return out,data


def main():
    got,data=replies(RUN/"tx.log")
    print(f"bytes={len(data)} replies={len(got)}")
    for i,(status,payload) in enumerate(got):
        print(f"  reply{i}: status={status} len={len(payload)}")
    if len(got)<1:
        print("incomplete: inference reply not received yet")
        return 1
    status,payload=got[-1]
    if status:
        print("firmware reported error",status,
              struct.unpack("<II",payload) if len(payload)==8 else payload)
        return 1
    count=struct.unpack("<I",payload[:4])[0]
    if count>32 or len(payload)!=4+count*24:
        print("malformed detection payload",count,len(payload))
        return 1
    boxes=[]
    for i in range(count):
        x1,y1,x2,y2,score,cat=struct.unpack("<fffffI",payload[4+24*i:4+24*(i+1)])
        boxes.append([x1,y1,x2,y2,score,cat])
    ref=json.loads((RUN/"expected.json").read_text())["boxes"]
    print(f"board count={count} reference count={len(ref)}")
    for i,b in enumerate(boxes):
        print("  hw %-13s %.3f (%7.1f,%7.1f)-(%7.1f,%7.1f)" %
              (CLASSES[b[5]],b[4],b[0],b[1],b[2],b[3]))
    for i,b in enumerate(ref):
        print("  py %-13s %.3f (%7.1f,%7.1f)-(%7.1f,%7.1f)" %
              (CLASSES[b[5]],b[4],b[0],b[1],b[2],b[3]))
    ok=count==len(ref)
    for b,r in zip(boxes,ref):
        if b[5]!=r[5] or abs(b[4]-r[4])>0.02 or any(abs(b[i]-r[i])>6 for i in range(4)):
            ok=False
    print("MATCH" if ok else "MISMATCH")
    return 0 if ok else 1


if __name__=="__main__":
    sys.exit(main())
