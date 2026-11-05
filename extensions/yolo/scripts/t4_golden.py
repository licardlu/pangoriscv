import numpy as np, cv2, os, json, math
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); t4=os.path.join(root,"data","t4"); os.makedirs(t4,exist_ok=True)
z=np.load(os.path.join(root,"data","models","yolo_fastest_l1.npz"))
bias,gamma,mean,var,w=z["bias"],z["gamma"],z["mean"],z["var"],z["weights"]  # w: 8,3,3,3
w2 = w * (gamma/math.sqrt(1e-5))[:,None,None,None] if False else w * (gamma/np.sqrt(var+1e-5))[:,None,None,None]
b2 = bias - mean*(gamma/np.sqrt(var+1e-5))
img=cv2.imread(os.path.join(root,"data","images","testset","plastic__plastic1.jpg"))
img=cv2.resize(img,(320,320),interpolation=cv2.INTER_LINEAR)
region=(img[0:4,0:4,:][:,:,::-1].astype(np.float32))/255.0   # RGB 0..1
patch=np.zeros((5,5,3),np.float32); patch[1:5,1:5,:]=region
scale_in=float(np.abs(patch).max())/127.0
qin=np.clip(np.round(patch/scale_in),-127,127).astype(np.int32)
# float reference for 4 output pixels (2x2, stride 2, pad 1)
out_f=np.zeros((2,2,8),np.float32)
for orow in range(2):
    for ocol in range(2):
        for ch in range(8):
            s=b2[ch]
            for c in range(3):
                for ky in range(3):
                    for kx in range(3):
                        s += patch[orow*2+ky, ocol*2+kx, c]*w2[ch,c,ky,kx]
            out_f[orow,ocol,ch]=s
out_scale=float(np.abs(out_f).max())/127.0
if out_scale < 1e-6: out_scale=1e-3
w_scale=np.abs(w2.reshape(8,-1)).max(axis=1)/127.0
wq=np.clip(np.round(w2/w_scale[:,None,None,None]),-127,127).astype(np.int32)
bq=np.round(b2/(scale_in*w_scale)).astype(np.int64)
M=np.clip(np.round((w_scale*scale_in/out_scale)*(1<<15)),1,2**17-1).astype(np.int64)
S=15
acc=np.zeros((2,2,8),np.int64)
for orow in range(2):
    for ocol in range(2):
        for ch in range(8):
            s=bq[ch]
            for c in range(3):
                for ky in range(3):
                    for kx in range(3):
                        s += int(qin[orow*2+ky,ocol*2+kx,c])*int(wq[ch,c,ky,kx])
            acc[orow,ocol,ch]=s
y=np.zeros((2,2,8),np.int64)
for i in range(2):
    for j in range(2):
        for ch in range(8):
            p=acc[i,j,ch]*M[ch]
            v=int((p + (1<<(S-1))) >> S)
            if v<0: v=int((v*3277)>>15)
            y[i,j,ch]=max(-128,min(127,v))
err=np.abs(y*out_scale-out_f).max()
print("scale_in=%.6f out_scale=%.6f M=%s"%(scale_in,out_scale,M.tolist()))
print("float vs int-dequant max_abs_err=%.6f (out_scale=%.6f)"%(err,out_scale))
# write hex (little-order bytes for int8 two's complement; int32 as 8 hex digits two's complement)
def h8(v): return "%02x"%((int(v))&0xff)
def h32(v): return "%08x"%((int(v))&0xffffffff)
with open(os.path.join(t4,"w.hex"),"w") as f:
    for ch in range(8):
        for c in range(3):
            for ky in range(3):
                for kx in range(3): f.write(h8(wq[ch,c,ky,kx])+"\n")
with open(os.path.join(t4,"b.hex"),"w") as f:
    for v in bq: f.write(h32(v)+"\n")
with open(os.path.join(t4,"m.hex"),"w") as f:
    for v in M: f.write(h32(v)+"\n")
with open(os.path.join(t4,"in.hex"),"w") as f:
    for iy in range(5):
        for ix in range(5):
            for c in range(3): f.write(h8(qin[iy,ix,c])+"\n")
with open(os.path.join(t4,"expected.hex"),"w") as f:
    for i in range(2):
        for j in range(2):
            for ch in range(8): f.write(h8(y[i,j,ch])+"\n")
meta=dict(scale_in=scale_in,out_scale=out_scale,S=S,M=M.tolist(),bq=bq.tolist(),
          float_out=out_f.reshape(-1).tolist(),int_out=y.reshape(-1).tolist(),
          input_patch=qin.reshape(-1).tolist(),wq=wq.reshape(-1).tolist(),
          note="first conv of YOLO-Fastest 1.1, 8 out ch, 3x3x3, stride2, pad1, LeakyReLU; 2x2 output tile, image plastic__plastic1 resized 320x320 top-left 4x4")
json.dump(meta,open(os.path.join(t4,"meta.json"),"w"),indent=1)
print("expected int8:", y.reshape(-1).tolist())
print("SAVED data/t4/{w,b,m,in,expected}.hex + meta.json")
