import os, json, csv, time
import numpy as np, cv2, onnxruntime as ort
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); res=os.path.join(root,"results")
CLASSES={0:'garbage_pile',1:'plastic',2:'paper',3:'metal',4:'biodegradable'}
sess=ort.InferenceSession(os.path.join(root,"data","models","garbage-detector.onnx"),providers=["CPUExecutionProvider"]); iname=sess.get_inputs()[0].name
def letterbox(im,new=640):
    h,w=im.shape[:2]; r=min(new/h,new/w); nh,nw=int(round(h*r)),int(round(w*r))
    c=np.full((new,new,3),114,np.uint8); top=(new-nh)//2; left=(new-nw)//2; c[top:top+nh,left:left+nw]=cv2.resize(im,(nw,nh)); return c,r,(left,top)
def nms(b,s,t):
    idx=s.argsort()[::-1]; keep=[]
    while len(idx):
        i=idx[0]; keep.append(i)
        if len(idx)==1: break
        q=idx[1:]; xx1=np.maximum(b[i,0],b[q,0]); yy1=np.maximum(b[i,1],b[q,1]); xx2=np.minimum(b[i,2],b[q,2]); yy2=np.minimum(b[i,3],b[q,3])
        w=np.maximum(0,xx2-xx1); h=np.maximum(0,yy2-yy1); inter=w*h; a=(b[i,2]-b[i,0])*(b[i,3]-b[i,1]); bb=(b[q,2]-b[q,0])*(b[q,3]-b[q,1])
        iou=inter/(a+bb-inter+1e-9); idx=q[iou<=t]
    return keep
def detect(im,conf=0.25):
    inp,r,pad=letterbox(im); x=inp[:,:,::-1].transpose(2,0,1)[None].astype(np.float32)/255.0
    out=sess.run(None,{iname:x})[0][0].T; sc=out[:,4:].max(1); cid=out[:,4:].argmax(1); m=sc>conf
    if not m.any(): return []
    xywh=out[m,:4]; s=sc[m]; c=cid[m]
    b=np.stack([xywh[:,0]-xywh[:,2]/2,xywh[:,1]-xywh[:,3]/2,xywh[:,0]+xywh[:,2]/2,xywh[:,1]+xywh[:,3]/2],1)
    b[:,[0,2]]=(b[:,[0,2]]-pad[0])/r; b[:,[1,3]]=(b[:,[1,3]]-pad[1])/r
    dets=[]
    for cc in np.unique(c):
        mc=c==cc; keep=nms(b[mc],s[mc],0.45)
        for k in keep: dets.append((CLASSES[int(cc)],round(float(s[mc][k]),3),[round(float(v),1) for v in b[mc][k]]))
    dets.sort(key=lambda d:-d[1]); return dets
rows=[]; t0=time.time(); n=0
for sub,conf in [("testset",0.25),("testset",0.05),("indomain_test",0.25),("indomain_test",0.05)]:
    d=os.path.join(root,"data","images",sub)
    for fn in sorted(os.listdir(d)):
        if not fn.lower().endswith(('.jpg','.jpeg','.png')): continue
        im=cv2.imread(os.path.join(d,fn)); n+=1
        dets=detect(im,conf)
        rows.append([sub,fn,conf,len(dets),";".join(f"{c}:{s}" for c,s,_ in dets[:4])])
print("TOTAL images:",n,"avg_cpu_ms_infer:",round((time.time()-t0)*1000/n,1))
from collections import Counter
for sub in ["testset","indomain_test"]:
    for conf in [0.25,0.05]:
        rr=[r for r in rows if r[0]==sub and r[2]==conf]
        print(sub,"conf",conf,"images_w_det=",sum(1 for r in rr if r[3]>0),"/",len(rr),"total_dets=",sum(r[3] for r in rr))
with open(os.path.join(res,"t2_pc_results.csv"),"w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["set","image","conf","num_det","dets"]); w.writerows(rows)
json.dump(rows,open(os.path.join(res,"t2_pc_results.json"),"w",encoding="utf-8"),ensure_ascii=False,indent=1)
print("SAVED results/t2_pc_results.csv/json")
