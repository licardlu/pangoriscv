import os, json, time, csv
import numpy as np, cv2, onnxruntime as ort
root = r"E:\file\pango\project\ai_lab"
model = os.path.join(root,"data","models","garbage-detector.onnx")
imgdir = os.path.join(root,"data","images","testset")
resdir = os.path.join(root,"results"); os.makedirs(resdir, exist_ok=True)
CLASSES = {0:'garbage_pile',1:'plastic',2:'paper',3:'metal',4:'biodegradable'}
CONF, IOU = 0.25, 0.45
sess = ort.InferenceSession(model, providers=["CPUExecutionProvider"])
iname = sess.get_inputs()[0].name
def letterbox(im, new=640, color=(114,114,114)):
    h,w = im.shape[:2]; r = min(new/h, new/w); nh,nw = int(round(h*r)), int(round(w*r))
    im2 = cv2.resize(im,(nw,nh),interpolation=cv2.INTER_LINEAR)
    top=(new-nh)//2; bottom=new-nh-top; left=(new-nw)//2; right=new-nw-left
    return cv2.copyMakeBorder(im2,top,bottom,left,right,cv2.BORDER_CONSTANT,value=color), r, (left,top)
def nms(boxes, scores, iou_thr):
    idx = scores.argsort()[::-1]; keep=[]
    while len(idx):
        i=idx[0]; keep.append(i); 
        if len(idx)==1: break
        rest=idx[1:]
        xx1=np.maximum(boxes[i,0],boxes[rest,0]); yy1=np.maximum(boxes[i,1],boxes[rest,1])
        xx2=np.minimum(boxes[i,2],boxes[rest,2]); yy2=np.minimum(boxes[i,3],boxes[rest,3])
        w=np.maximum(0,xx2-xx1); h=np.maximum(0,yy2-yy1); inter=w*h
        a=(boxes[i,2]-boxes[i,0])*(boxes[i,3]-boxes[i,1]); b=(boxes[rest,2]-boxes[rest,0])*(boxes[rest,3]-boxes[rest,1])
        iou=inter/(a+b-inter+1e-9); idx=rest[iou<=iou_thr]
    return keep
def postprocess(out, r, pad, orig_shape):
    # out: [1,9,8400]
    p = out[0].T  # 8400 x 9
    boxes_xywh = p[:,:4]; cls = p[:,4:]
    conf = cls.max(axis=1); cid = cls.argmax(axis=1)
    m = conf>CONF
    if not m.any(): return []
    xywh=boxes_xywh[m]; sc=conf[m]; cid=cid[m]
    x1=xywh[:,0]-xywh[:,2]/2; y1=xywh[:,1]-xywh[:,3]/2; x2=xywh[:,0]+xywh[:,2]/2; y2=xywh[:,1]+xywh[:,3]/2
    lx,ty = pad; h,w = orig_shape
    x1=(x1-lx)/r; x2=(x2-lx)/r; y1=(y1-ty)/r; y2=(y2-ty)/r
    boxes=np.stack([x1,y1,x2,y2],1)
    dets=[]
    for c in np.unique(cid):
        mc=cid==c; keep=nms(boxes[mc],sc[mc],IOU)
        for k in keep:
            dets.append((int(c), float(sc[mc][k]), [round(float(v),1) for v in boxes[mc][k]]))
    dets.sort(key=lambda d:-d[1]); return dets
rows=[]; allout={}
imgs=sorted(os.listdir(imgdir))
t0=time.time()
for fn in imgs:
    im=cv2.imread(os.path.join(imgdir,fn))
    if im is None: continue
    inp,r,pad = letterbox(im)
    x = inp[:,:,::-1].transpose(2,0,1)[None].astype(np.float32)/255.0
    out = sess.run(None,{iname:x})[0]
    dets = postprocess(out,r,pad,im.shape[:2])
    allout[fn]=[{"class":CLASSES[c],"score":s,"box_xyxy":b} for c,s,b in dets[:10]]
    rows.append([fn, len(dets), ";".join(f"{CLASSES[c]}:{s:.2f}" for c,s,_ in dets[:5])])
dt=(time.time()-t0)*1000/max(1,len(imgs))
print("IMAGES:",len(imgs),"avg_cpu_ms_per_image:",round(dt,1))
for fn,n,s in rows: print(f"{fn:55s} dets={n:2d} {s}")
json.dump({"model_sha256":"DEECB3F48CE9265AEF58883A6A2A55A8EB2275AE6189D425B7707DBB4BC0CB5C",
           "classes":CLASSES,"conf":CONF,"iou":IOU,"per_image":allout}, open(os.path.join(resdir,"t2_pc_detections.json"),"w",encoding="utf-8"), ensure_ascii=False, indent=1)
with open(os.path.join(resdir,"t2_pc_results.csv"),"w",newline="",encoding="utf-8") as f:
    wr=csv.writer(f); wr.writerow(["image","num_detections","top_detections"]); wr.writerows(rows)
print("SAVED results/t2_pc_detections.json, results/t2_pc_results.csv")
