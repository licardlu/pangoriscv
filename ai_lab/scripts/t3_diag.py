import struct
root=r"E:\file\pango\project\ai_lab"
# reuse cfg parsing from earlier script logic (compact)
lines=open(root+r"\data\models\yolo-fastest-1.1.cfg",encoding="utf-8",errors="ignore").read().splitlines()
blocks=[]; cur=None
for ln in lines:
    s=ln.split("#")[0].strip()
    if not s: continue
    if s.startswith("["):
        if cur: blocks.append(cur)
        cur={"type":s.strip("[]").strip(),"kv":[]}
    elif cur is not None:
        k,_,v=s.partition("="); cur["kv"].append((k.strip(),v.strip()))
if cur: blocks.append(cur)
net=dict(blocks[0]["kv"]); W=int(net.get("width",320)); H=int(net.get("height",320)); C=3
layers=[{"shape":(H,W,C)}]; weights=0; bn_out=0; nonbn_out=0; nconv=0
for b in blocks[1:]:
    if b["type"]!="convolutional": continue
    kv=dict(b["kv"]); oc=int(kv.get("filters",1)); k=int(kv.get("size",1)); st=int(kv.get("stride",1)); pf=int(kv.get("pad",0)); p=k//2 if pf else 0; g=int(kv.get("groups",1)); bn=int(kv.get("batch_normalize",0))
    ih,iw,ic=layers[-1]["shape"]; oh=(ih+2*p-k)//st+1; ow=(iw+2*p-k)//st+1
    layers.append({"shape":(oh,ow,oc)}); weights+=oc*(ic//g)*k*k; nconv+=1
    if bn: bn_out+=oc
    else: nonbn_out+=oc
print("conv_layers",nconv,"conv_weights",weights,"sum_out_bn",bn_out,"sum_out_nonbn",nonbn_out)
print("variants: A(4bn+nonbn)=%d  B(3bn)%d  C(2bn)%d  D(1bn)%d"%(weights+4*bn_out+nonbn_out, weights+3*bn_out, weights+2*bn_out, weights+bn_out))
import os
fsize=os.path.getsize(root+r"\data\models\yolo-fastest-1.1.weights")
print("weights file bytes",fsize,"floats",(fsize-16)//4)
