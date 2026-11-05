import os, zipfile, numpy as np, cv2, onnxruntime as ort, glob
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sess = ort.InferenceSession(os.path.join(root,"data","models","garbage-detector.onnx"), providers=["CPUExecutionProvider"])
iname = sess.get_inputs()[0].name
CLASSES = {0:'garbage_pile',1:'plastic',2:'paper',3:'metal',4:'biodegradable'}
def prep(im, new=640):
    h,w = im.shape[:2]; r=min(new/h,new/w); nh,nw=int(round(h*r)),int(round(w*r))
    im2=cv2.resize(im,(nw,nh)); canvas=np.full((new,new,3),114,np.uint8)
    top=(new-nh)//2; left=(new-nw)//2; canvas[top:top+nh,left:left+nw]=im2
    x=canvas[:,:,::-1].transpose(2,0,1)[None].astype(np.float32)/255.0
    return x
def scores(im):
    out=sess.run(None,{iname:prep(im)})[0][0].T
    return out[:,4:].max(axis=1), out
# TrashNet max scores
print("--- TrashNet (domain shift) ---")
for fn in sorted(glob.glob(os.path.join(root,"data","images","testset","*")))[:4]:
    im=cv2.imread(fn); sc,out=scores(im)
    print(os.path.basename(fn), "max_cls_score=%.4f"%sc.max(), "top_idx=", int(sc.argmax()))
# extract in-domain test images
z=zipfile.ZipFile(os.path.join(root,"data","raw","garbage-test.zip"))
names=[n for n in z.namelist() if n.lower().endswith(('.jpg','.jpeg','.png'))]
print("in-domain images:", len(names), names[:3])
outdir=os.path.join(root,"data","images","indomain_test"); os.makedirs(outdir,exist_ok=True)
sel=names[::max(1,len(names)//8)][:8]
picked=[]
for n in sel:
    out=os.path.join(outdir, os.path.basename(n)); open(out,'wb').write(z.read(n)); picked.append(out)
print("--- in-domain sample max scores ---")
for fn in picked:
    im=cv2.imread(fn); sc,out=scores(im)
    print(os.path.basename(fn), "max_cls_score=%.4f"%sc.max(), "top_idx=", int(sc.argmax()))
