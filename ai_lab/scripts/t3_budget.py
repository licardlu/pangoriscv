import struct, os, json, csv, math
import numpy as np
root=r"E:\file\pango\project\ai_lab"; models=os.path.join(root,"data","models")
blocks=[]; cur=None
for ln in open(os.path.join(models,"yolo-fastest-1.1.cfg"),encoding="utf-8",errors="ignore").read().splitlines():
    s=ln.split("#")[0].strip()
    if not s: continue
    if s.startswith("["):
        if cur: blocks.append(cur)
        cur={"type":s.strip("[]").strip(),"kv":[]}
    elif cur is not None:
        k,_,v=s.partition("="); cur["kv"].append((k.strip(),v.strip()))
if cur: blocks.append(cur)
net=dict(blocks[0]["kv"]); H0=int(net.get("height",320)); W0=int(net.get("width",320))
def build(W,H):
    layers=[{"type":"input","shape":(H,W,3),"params":0,"macs":0,"bytes":H*W*3}]
    for b in blocks[1:]:
        t=b["type"]; kv=dict(b["kv"])
        if t=="convolutional":
            oc=int(kv.get("filters",1)); k=int(kv.get("size",1)); s=int(kv.get("stride",1)); pf=int(kv.get("pad",0)); p=k//2 if pf else 0; g=int(kv.get("groups",1))
            ih,iw,ic=layers[-1]["shape"]; oh=(ih+2*p-k)//s+1; ow=(iw+2*p-k)//s+1
            layers.append({"type":"conv","shape":(oh,ow,oc),"params":oc*(ic//g)*k*k,"macs":oh*ow*oc*(ic//g)*k*k,"bytes":oh*ow*oc,"k":k,"s":s,"g":g,"bn":int(kv.get("batch_normalize",0)),"act":kv.get("activation","linear")})
        elif t=="maxpool":
            k=int(kv.get("size",2)); s=int(kv.get("stride",2)); p=(k-1)//2
            ih,iw,ic=layers[-1]["shape"]; oh=(ih+2*p-k)//s+1; ow=(iw+2*p-k)//s+1
            layers.append({"type":"maxpool","shape":(oh,ow,ic),"params":0,"macs":0,"bytes":oh*ow*ic})
        elif t=="upsample":
            st=int(kv.get("stride",2)); ih,iw,ic=layers[-1]["shape"]; layers.append({"type":"upsample","shape":(ih*st,iw*st,ic),"params":0,"macs":0,"bytes":ih*st*iw*st*ic})
        elif t=="route":
            idxs=[int(x) for x in kv.get("layers","").replace(" ","").split(",")]; js=[len(layers)+x if x<0 else x+1 for x in idxs]; shs=[layers[j]["shape"] for j in js]
            sh=shs[0] if len(shs)==1 else (shs[0][0],shs[0][1],sum(s[2] for s in shs))
            layers.append({"type":"route","shape":sh,"params":0,"macs":0,"bytes":sh[0]*sh[1]*sh[2]})
        elif t=="shortcut":
            src=int(kv.get("from",-1)); j=len(layers)+src; sh=layers[j]["shape"]; layers.append({"type":"shortcut","shape":sh,"params":0,"macs":0,"bytes":sh[0]*sh[1]*sh[2]})
        elif t=="dropout": layers.append({"type":"dropout","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"]})
        elif t=="yolo": layers.append({"type":"yolo","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"]})
        else: layers.append({"type":"other","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"]})
    return layers
def liveness(layers, exclude_input=True):
    n=len(layers); consumers={i:[] for i in range(n)}
    for i,l in enumerate(layers):
        if i==0: continue
        consumers[i-1].append(i)
        if l["type"]=="shortcut":
            src=None
        # route/shortcut sources recorded separately below
    # rebuild with explicit src tracking
    consumers={i:[] for i in range(n)}
    for i,l in enumerate(layers):
        if i>0 and l["type"]!="route": consumers[i-1].append(i)
        if l["type"]=="route":
            idxs=[int(x) for x in []]
    # We re-derive consumes from build: route srcs, shortcut srcs not stored; store globally
    return None
# rebuild storing sources
def build2(W,H):
    layers=[{"type":"input","shape":(H,W,3),"params":0,"macs":0,"bytes":H*W*3,"src":[]}]
    for b in blocks[1:]:
        t=b["type"]; kv=dict(b["kv"])
        if t=="convolutional":
            oc=int(kv.get("filters",1)); k=int(kv.get("size",1)); s=int(kv.get("stride",1)); pf=int(kv.get("pad",0)); p=k//2 if pf else 0; g=int(kv.get("groups",1))
            ih,iw,ic=layers[-1]["shape"]; oh=(ih+2*p-k)//s+1; ow=(iw+2*p-k)//s+1
            layers.append({"type":"conv","shape":(oh,ow,oc),"params":oc*(ic//g)*k*k,"macs":oh*ow*oc*(ic//g)*k*k,"bytes":oh*ow*oc,"bn":int(kv.get("batch_normalize",0)),"src":[len(layers)-1]})
        elif t=="maxpool":
            k=int(kv.get("size",2)); s=int(kv.get("stride",2)); p=(k-1)//2
            ih,iw,ic=layers[-1]["shape"]; oh=(ih+2*p-k)//s+1; ow=(iw+2*p-k)//s+1
            layers.append({"type":"maxpool","shape":(oh,ow,ic),"params":0,"macs":0,"bytes":oh*ow*ic,"src":[len(layers)-1]})
        elif t=="upsample":
            st=int(kv.get("stride",2)); ih,iw,ic=layers[-1]["shape"]; layers.append({"type":"upsample","shape":(ih*st,iw*st,ic),"params":0,"macs":0,"bytes":ih*st*iw*st*ic,"src":[len(layers)-1]})
        elif t=="route":
            idxs=[int(x) for x in kv.get("layers","").replace(" ","").split(",")]; js=[len(layers)+x if x<0 else x+1 for x in idxs]; shs=[layers[j]["shape"] for j in js]
            sh=shs[0] if len(shs)==1 else (shs[0][0],shs[0][1],sum(s[2] for s in shs))
            layers.append({"type":"route","shape":sh,"params":0,"macs":0,"bytes":sh[0]*sh[1]*sh[2],"src":js})
        elif t=="shortcut":
            src=int(kv.get("from",-1)); j=len(layers)+src; sh=layers[j]["shape"]; layers.append({"type":"shortcut","shape":sh,"params":0,"macs":0,"bytes":sh[0]*sh[1]*sh[2],"src":[j]})
        elif t=="dropout": layers.append({"type":"dropout","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"],"src":[len(layers)-1]})
        elif t=="yolo": layers.append({"type":"yolo","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"],"src":[len(layers)-1]})
        else: layers.append({"type":"other","shape":layers[-1]["shape"],"params":0,"macs":0,"bytes":layers[-1]["bytes"],"src":[len(layers)-1]})
    return layers
def peak_mem(layers):
    n=len(layers); last={i:i for i in range(n)}
    for i,l in enumerate(layers):
        for j in l.get("src",[]): last[j]=max(last[j],i)
    ev={}
    for i,l in enumerate(layers):
        if i==0: continue
        b=l["bytes"]; ev[i]=ev.get(i,0)+b; k=last[i]+1; ev[k]=ev.get(k,0)-b
    cur=0; peak=0
    for i in range(n+1): cur+=ev.get(i,0); peak=max(peak,cur)
    return peak
# ==== budget table ====
rows=[]; W,H=160,128
for (W,H) in [(160,128),(160,160),(192,160),(224,160),(256,192),(320,320)]:
    ls=build2(W,H); params=sum(l["params"] for l in ls); macs=sum(l["macs"] for l in ls); peak=peak_mem(ls); inp=W*H*3
    rows.append([W,H,params,macs,params+4*0+0,peak,inp])
    print(f"RES {W}x{H}: layers={len(ls)} params={params} MACs={macs/1e6:.2f}M act_peak_excl_input={peak/1024:.1f}KiB input={inp/1024:.1f}KiB")
# ==== per-layer CSV at 160x128 ====
W,H=160,128; ls=build2(W,H)
with open(os.path.join(root,"results","yolo_fastest_layers.csv"),"w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["idx","type","out_h","out_w","out_c","k","stride","groups","bn","activation","params","macs","out_bytes"])
    for i,l in enumerate(ls):
        sh=l["shape"]; w.writerow([i,l["type"],sh[0],sh[1],sh[2],l.get("k",""),l.get("s",""),l.get("g",""),l.get("bn",""),l.get("act",""),l["params"],l["macs"],l["bytes"]])
tot_params=sum(l["params"] for l in ls); tot_macs=sum(l["macs"] for l in ls); peak=peak_mem(ls); inp=W*H*3
print("TOTAL:",tot_params,"params,",tot_macs/1e6,"MMAC,", "peak",peak/1024,"KiB, input",inp/1024,"KiB")
print("blocks: weights",math.ceil(tot_params/4608),"act",math.ceil(peak/4608),"input",math.ceil(inp/4608))
# ==== weight file verify + first conv extraction ====
wpath=os.path.join(models,"yolo-fastest-1.1.weights"); data=open(wpath,"rb").read(); nfloat=(len(data)-16)//4
print("weights bytes",len(data),"floats",nfloat,"header ints:",struct.unpack("<4i",data[:16]))
conv_layers=[l for l in ls if l["type"]=="conv"]
bn_out=sum(l["shape"][2] for l in conv_layers if l["bn"]); nonbn=sum(l["shape"][2] for l in conv_layers if not l["bn"])
print("conv_layers",len(conv_layers),"sum_out_bn",bn_out,"nonbn",nonbn,"weights",tot_params)
print("expected 4*bn+nonbn+weights =",4*bn_out+nonbn+tot_params, "diff vs file:",nfloat-(4*bn_out+nonbn+tot_params))
# parse first conv with BN layout: biases,scales,mean,var,weights
o=16; n=8; ksz=3; nc=3; nw=n*nc*ksz*ksz
arr=np.frombuffer(data[o:o+4*(5*n+nw)],dtype="<f4").copy(); o2=o+4*(5*n+nw)
bias=arr[0:n]; gamma=arr[n:2*n]; mean=arr[2*n:3*n]; var=arr[3*n:4*n]; wgt=arr[4*n:4*n+nw].reshape(n,nc,ksz,ksz)
print("first conv parse: n floats",5*n+nw,"var min",float(var.min()),"gamma mean",float(gamma.mean()))
np.savez(os.path.join(root,"data","models","yolo_fastest_l1.npz"),bias=bias,gamma=gamma,mean=mean,var=var,weights=wgt)
print("SAVED data/models/yolo_fastest_l1.npz")

