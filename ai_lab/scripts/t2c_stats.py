import os, numpy as np, cv2, onnxruntime as ort
root=r"E:\file\pango\project\ai_lab"
sess=ort.InferenceSession(os.path.join(root,"data","models","garbage-detector.onnx"),providers=["CPUExecutionProvider"])
iname=sess.get_inputs()[0].name
def prep(im,new=640):
    h,w=im.shape[:2]; r=min(new/h,new/w); nh,nw=int(round(h*r)),int(round(w*r))
    c=np.full((new,new,3),114,np.uint8); c[(new-nh)//2:(new-nh)//2+nh,(new-nw)//2:(new-nw)//2+nw]=cv2.resize(im,(nw,nh))
    return c[:,:,::-1].transpose(2,0,1)[None].astype(np.float32)/255.0
im=cv2.imread(os.path.join(root,"data","images","indomain_test","metal280_jpg.rf.cb748931e748b5d52c8862e34c09ad39.jpg"))
out=sess.run(None,{iname:prep(im)})[0][0].T
print("shape",out.shape)
for name,sl in [("boxes",slice(0,4)),("cls",slice(4,9))]:
    a=out[:,sl]; print(name,"min=%.3f max=%.3f mean=%.3f"%(a.min(),a.max(),a.mean()))
print("cls top10:", np.sort(out[:,4:].max(axis=1))[-10:])
print("box sample:", out[:3])
