"""Prepare the full-system simulation inputs for tb_vexii_yolo.

Produces, in gen/integration/yolo_sim/:
  ddr_model.hex  packed model blob as 64-bit little-endian words (DDR image)
  frame.hex      320x180 RGB565 sensor frame, 4x decimation of a fixed image
  cmd.hex        YAI1 requests: model CRC (5) then camera inference (6)
  expected.json  Python reference: the same preprocessing + the int8 graph +
                 the same bounded-NMS decode the firmware implements
  input.npy      the int8 tensor the firmware is expected to build
"""
from pathlib import Path
import json
import sys
import struct

import numpy as np

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from deployment_bundle import Deployment
from board_loader import request

OUT=ROOT/"gen/integration/yolo_sim"
IMAGE=ROOT/"data/images/testset/plastic__plastic1.jpg"
SNAP_W,SNAP_H=320,180
PAD_Y=70
CONF,IOU=0.25,0.45
ANCHORS=[[[10,13],[16,30],[33,23]],[[30,61],[62,45],[59,119]],
         [[116,90],[156,198],[373,326]]]
STRIDES=[8,16,32]
CLASSES=["biodegradable","cardboard","glass","metal","paper","plastic"]


def rgb565(path):
    import cv2
    img=cv2.imread(str(path))
    if img is None: raise SystemExit("cannot read "+str(path))
    img=cv2.resize(img,(SNAP_W,SNAP_H),interpolation=cv2.INTER_AREA)
    img=img[:,:,::-1].astype(np.uint32)          # BGR -> RGB
    r5=img[:,:,0]>>3; g6=img[:,:,1]>>2; b5=img[:,:,2]>>3
    return (r5<<11)|(g6<<5)|b5                    # python int, 16 bit


def quantise(word):
    """Exactly what capture_input() does with one RGB565 pixel."""
    r=(word>>11)&31; g=(word>>5)&63; b=word&31
    r=(r<<3)|(r>>2); g=(g<<2)|(g>>4); b=(b<<3)|(b>>2)
    r=(r*127+127)//255; g=(g*127+127)//255; b=(b*127+127)//255
    return int(r),int(g),int(b)


def sigmoid(x):
    return np.where(x>=16,1.0,np.where(x<=-16,0.0,1.0/(1.0+np.exp(-x))))


def requant(acc,mult,shift=15):
    scaled=acc.astype(np.float64)*mult
    rounded=np.where(scaled>=0,np.floor(scaled+0.5),np.ceil(scaled-0.5))
    return np.clip(rounded,-2**31,2**31-1).astype(np.int64)


def decode(raw,orig_w,orig_h,ratio,pad_x,pad_y):
    """Mirror of sw/yolo_decode.c: per-class Top-32, greedy NMS, then rescale."""
    per=[[] for _ in range(len(CLASSES))]
    for h,out in enumerate(raw):
        _,c,hh,ww=out.shape
        v=out.reshape(1,3,11,hh,ww).astype(np.float64)
        obj=sigmoid(v[0,:,4])
        cls=sigmoid(v[0,:,5:])
        xy=sigmoid(v[0,:,0:4])
        for y in range(hh):
            for x in range(ww):
                for a in range(3):
                    o=obj[a,y,x]
                    if o<CONF: continue
                    scores=o*cls[a,:,y,x]
                    best=float(scores.max())
                    if best<CONF: continue
                    cx=(xy[a,0,y,x]*2-0.5+x)*STRIDES[h]
                    cy=(xy[a,1,y,x]*2-0.5+y)*STRIDES[h]
                    bw=xy[a,2,y,x]**2*4*ANCHORS[h][a][0]
                    bh=xy[a,3,y,x]**2*4*ANCHORS[h][a][1]
                    if (cx+bw/2<=pad_x or cy+bh/2<=pad_y or
                            cx-bw/2>=pad_x+orig_w*ratio or
                            cy-bh/2>=pad_y+orig_h*ratio):
                        continue
                    for ci in range(6):
                        s=float(scores[ci])
                        if s>=CONF:
                            per[ci].append([cx-bw/2,cy-bh/2,cx+bw/2,cy+bh/2,s,ci])
    out=[]
    for ci in range(6):
        cand=sorted(per[ci],key=lambda b:-b[4])[:32]
        kept=[]
        for i,b in enumerate(cand):
            if b[4]<0: continue
            for j in range(i+1,len(cand)):
                if cand[j][4]<0: continue
                x1=max(b[0],cand[j][0]);y1=max(b[1],cand[j][1])
                x2=min(b[2],cand[j][2]);y2=min(b[3],cand[j][3])
                area=max(0.0,x2-x1)*max(0.0,y2-y1)
                total=(b[2]-b[0])*(b[3]-b[1])+(cand[j][2]-cand[j][0])*(cand[j][3]-cand[j][1])-area
                if total>0 and area/total>IOU: cand[j][4]=-1
            kept.append(b)
        for b in kept:
            box=[min(orig_w,max(0.0,(b[0]-pad_x)/ratio)),
                 min(orig_h,max(0.0,(b[1]-pad_y)/ratio)),
                 min(orig_w,max(0.0,(b[2]-pad_x)/ratio)),
                 min(orig_h,max(0.0,(b[3]-pad_y)/ratio)),b[4],b[5]]
            if box[2]>box[0] and box[3]>box[1]:
                out.append(box)
    out.sort(key=lambda b:-b[4])
    return out[:32]


def main():
    OUT.mkdir(parents=True,exist_ok=True)

    blob=(ROOT/"gen/integration/packed/model.bin").read_bytes()
    words=[struct.unpack_from("<Q",blob,i)[0] for i in range(0,len(blob),8)]
    if len(blob)%8:
        words.append(struct.unpack_from("<Q",blob+b"\0"*(8-len(blob)%8),len(blob)//8*8)[0])
    (OUT/"ddr_model.hex").write_text("".join(f"{w:016x}\n" for w in words))
    print(f"model words={len(words)} bytes={len(blob)}")

    word=rgb565(IMAGE)
    (OUT/"frame.hex").write_text(
        "".join(f"{int(word[y,x]):04x}\n" for y in range(SNAP_H) for x in range(SNAP_W)))

    tensor=np.full((320,320,3),57,dtype=np.int8)
    for sy in range(SNAP_H):
        for sx in range(SNAP_W):
            tensor[PAD_Y+sy,sx]=quantise(int(word[sy,sx]))
    np.save(OUT/"input.npy",tensor)
    padded=np.zeros((320,320,8),dtype=np.int8)
    padded[:,:,:3]=tensor
    input_bytes=padded.view(np.uint8).reshape(-1).tobytes()
    (OUT/"ddr_input.hex").write_text(
        "".join(f"{int.from_bytes(input_bytes[i:i+8],'little'):016x}\n"
                for i in range(0,len(input_bytes),8)))

    image=np.transpose(tensor.astype(np.float32)/127.0,(2,0,1))[None]
    dep=Deployment(ROOT/"gen/integration/deployment")
    raw=dep.execute(__import__("torch").from_numpy(image))
    boxes=decode(raw,1280,720,0.25,0,70)
    result={"image":str(IMAGE.relative_to(ROOT)),"boxes":boxes,
            "preprocess":"decimate 1280x720 -> 320x180 RGB565, letterbox pad_y=70,"
                         " int8=(v*127+127)//255"}
    (OUT/"expected.json").write_text(json.dumps(result,indent=1))
    print("expected boxes:",len(boxes))
    for b in boxes[:5]:
        print("  %-13s %.3f (%6.1f,%6.1f)-(%6.1f,%6.1f)" %
              (CLASSES[b[5]],b[4],b[0],b[1],b[2],b[3]))

    cmd=request(5)+request(6)
    cmd_text="".join(f"{b:02x}\n" for b in cmd)
    (OUT/"cmd.hex").write_text(cmd_text)
    (OUT/"cmd_full.hex").write_text(cmd_text)
    (OUT/"cmd_preloaded.hex").write_text(
        "".join(f"{b:02x}\n" for b in request(3)))
    print("cmd bytes",len(cmd))


if __name__=="__main__":
    main()
