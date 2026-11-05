"""Check the compiled C fixed-point heads on the existing validation images."""
import argparse
import ctypes as C
import json
from pathlib import Path
import subprocess
import time

import numpy as np
import torch
from board_loader import prepare_image
from board_perf import compare_detections
from deployment_bundle import Deployment
from eval_yolov5n_labeled import ap50
from gen_vexii_yolo_sim import CLASSES,decode
from run_native_checks import compiler
from test_deployment_cpu import Op,Tensor

ROOT=Path(__file__).resolve().parents[1]

class Box(C.Structure):
    _fields_=[(name,C.c_float) for name in ("x1","y1","x2","y2","score")]+[
        ("category",C.c_uint32)]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--limit",type=int,default=222)
    parser.add_argument("--out",type=Path,default=ROOT/"sim/perf_head_validation")
    parser.add_argument("--flags",type=int,default=1)
    args=parser.parse_args()
    args.out.mkdir(parents=True,exist_ok=True)
    tool,env,msvc=compiler()
    library=(args.out/("heads.dll" if msvc else "heads.so")).resolve()
    sources=[str(ROOT/p) for p in ("sw/yolo_runtime.c","sw/yolo_decode.c",
                                  "tb/deployment_native.c")]
    if msvc:
        command=[tool,"/nologo","/std:c11","/O2","/W4","/WX","/LD","/DNATIVE_DECODE",
                 "/I"+str(ROOT/"sw"),"/Fe:"+str(library),*sources,"/link",
                 "/EXPORT:native_put","/EXPORT:native_get","/EXPORT:native_op",
                 "/EXPORT:native_set_options","/EXPORT:native_set_head_floor",
                 "/EXPORT:native_decode","/EXPORT:native_decode_bulk_reads"]
    else:
        command=[tool,"-std=c11","-O2","-shared","-fPIC","-DNATIVE_DECODE",
                 "-I"+str(ROOT/"sw"),
                 *sources,"-lm","-o",str(library)]
    subprocess.run(command,cwd=args.out,env=env,check=True)
    lib=C.CDLL(str(library.resolve()))
    lib.native_set_options.argtypes=[C.c_uint32]
    lib.native_set_options(args.flags)
    lib.native_set_head_floor.argtypes=[C.c_float]
    floor=float(np.float32(np.log(np.float32(.25)/np.float32(.75))-.001))
    lib.native_set_head_floor(floor)
    lib.native_put.argtypes=[C.c_uint32,C.c_void_p,C.c_uint32]
    lib.native_get.argtypes=[C.c_uint32,C.c_void_p,C.c_uint32]
    lib.native_op.argtypes=[C.POINTER(Op),C.POINTER(Tensor)]
    lib.native_decode.argtypes=[C.POINTER(Tensor),C.c_float,C.c_float,C.c_float,
                               C.c_uint32,C.c_uint32,C.POINTER(Box),
                               C.POINTER(C.c_uint32)]
    lib.native_decode_bulk_reads.argtypes=[]
    lib.native_decode_bulk_reads.restype=C.c_uint32
    graph=json.loads((ROOT/"gen/integration/packed/memory_map.json").read_text())
    tensors=(Tensor*len(graph["tensors"]))(
        *[Tensor(**{k:v for k,v in t.items() if k!="fp32"}) for t in graph["tensors"]])
    blob=(ROOT/"gen/integration/packed/model.bin").read_bytes()
    if lib.native_put(graph["blob_base"],blob,len(blob)):
        raise RuntimeError("Cannot load model into native checker")
    head_ops=[o for o in graph["ops"] if o["kind"]=="YOLO_HEAD"]
    needed={o["inputs"][0]-1 for o in head_ops}
    records=json.loads((ROOT/"results/yolov5n_deployment_q15/predictions.json").read_text())
    paths=[ROOT/"data/garbage_datasets/datasets/images/val"/r["image"]
           for r in records[:args.limit]]
    deployment=Deployment(ROOT/"gen/integration/deployment")
    torch.set_num_threads(4)
    report=dict(images=0,max_logit_error=0.0,max_box_error_pixels=0.0,
                max_score_error=0.0,skipped_anchors=0,total_anchors=0,
                flags=args.flags,decode_bulk_reads=0,passed=False)
    started=time.monotonic()
    baseline_records=[]
    optimized_records=[]
    for index,path in enumerate(paths):
        packed,metadata=prepare_image(path)
        inp=np.frombuffer(packed,np.int8).reshape(320,320,8)[:,:,:3]
        image=torch.from_numpy(inp.transpose(2,0,1)[None].astype(np.float32)/127)
        features={}
        with torch.no_grad():
            expected=deployment.execute(image,lambda op,value:features.update(
                {op["idx"]:value}) if op["idx"] in needed else None)
        actual=[]
        for head,reference in zip(head_ops,expected):
            t=graph["tensors"][head["inputs"][0]]
            a=np.ascontiguousarray(features[head["inputs"][0]-1][0].transpose(1,2,0))
            data=a.tobytes()
            if lib.native_put(t["address"],data,len(data)):
                raise RuntimeError("Cannot load head features")
            op=Op(kind=5,count=1,inputs=(C.c_uint16*4)(*head["inputs"]),
                  output=head["output"],head_weight=head["head_weight"],
                  head_bias=head["head_bias"])
            if lib.native_op(C.byref(op),tensors):
                raise RuntimeError("Native head failed")
            out=graph["tensors"][head["output"]]
            buf=C.create_string_buffer(out["h"]*out["w"]*out["padded_c"]*4)
            if lib.native_get(out["address"],buf,len(buf)):
                raise RuntimeError("Cannot read head logits")
            value=np.frombuffer(buf,np.float32).reshape(out["h"],out["w"],40)
            value_float=value
            if np.any(value[:,:,33:]!=0):
                raise RuntimeError("Head padding is not zero")
            value_float=np.ascontiguousarray(value_float[:,:,:33].transpose(2,0,1)[None])
            error=np.abs(value_float-reference)
            if args.flags&32:
                mask=np.ones(error.shape,dtype=bool)
                for anchor in range(3):
                    obj=anchor*11+4
                    skipped=value_float[:,obj]<floor
                    report["skipped_anchors"]+=int(skipped.sum())
                    report["total_anchors"]+=int(skipped.size)
                    # Objectness itself must still match; all other logits of
                    # a rejected anchor are intentionally not computed.
                    for channel in range(anchor*11,anchor*11+11):
                        if channel!=obj:
                            mask[:,channel]=~skipped
                            if np.any(value_float[:,channel][skipped]!=0):
                                raise RuntimeError("Skipped anchor logits must be zero")
                error=np.where(mask,error,0)
            report["max_logit_error"]=max(report["max_logit_error"],float(error.max()))
            tolerance=(3e-4+2e-4*np.abs(reference)) if args.flags&16 else (
                3e-5+2e-5*np.abs(reference))
            if np.any(error>tolerance):
                raise RuntimeError(f"Head logit tolerance exceeded: {path}, max={error.max()}")
            actual.append(value_float)
        import struct
        ratio,padx,pady,w,h=struct.unpack("<fffHH",metadata)
        def boxes(raw):
            return [dict(category=CLASSES[int(b[5])],score=b[4],box=b[:4])
                    for b in decode(raw,w,h,ratio,padx,pady)]
        baseline_boxes=boxes(expected)
        decoded=(Box*32)()
        count=C.c_uint32()
        heads=(Tensor*3)(*[tensors[o["output"]] for o in head_ops])
        if lib.native_decode(heads,ratio,padx,pady,w,h,decoded,C.byref(count)):
            raise RuntimeError("Actual C decoder failed")
        report["decode_bulk_reads"]+=lib.native_decode_bulk_reads()
        optimized_boxes=[dict(category=CLASSES[b.category],score=b.score,
                              box=[b.x1,b.y1,b.x2,b.y2])
                         for b in decoded[:count.value]]
        comparison=compare_detections(baseline_boxes,optimized_boxes)
        for target,detections in ((baseline_records,baseline_boxes),
                                  (optimized_records,optimized_boxes)):
            target.append(dict(image=path.name,gt=records[index]["gt"],
                dets=[dict(**{"class":b["category"]},score=b["score"],box=b["box"])
                      for b in detections]))
        for key,value in comparison.items():
            report[key]=max(report[key],value)
        report["images"]+=1
        if (index+1)%10==0:
            print(f"FAST_HEAD_VALIDATED {index+1}/{len(paths)}",flush=True)
    report["accuracy"]={}
    for name,items in (("reference",baseline_records),("optimized",optimized_records)):
        per_class={}
        for category in CLASSES:
            ap,tp,fp,gt=ap50(items,category)
            per_class[category]=dict(ap50=ap,tp=tp,fp=fp,gt=gt)
        aps=[v["ap50"] for v in per_class.values() if v["ap50"] is not None]
        report["accuracy"][name]=dict(map50=sum(aps)/len(aps),per_class=per_class)
    if report["accuracy"]["optimized"]["map50"]+1e-4<report["accuracy"]["reference"]["map50"]:
        raise RuntimeError("Optimized head reduced AP50 on the matched validation set")
    if args.flags&8 and not report["decode_bulk_reads"]:
        raise RuntimeError("Fast decoder was selected but no bulk reads were tested")
    report.update(passed=True,wall_seconds=time.monotonic()-started)
    (args.out/"result.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("FAST_HEAD_VALIDATION_PASS "+json.dumps(report),flush=True)


if __name__=="__main__":
    main()
