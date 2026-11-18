"""Differentiable exact-Q15 tail, with frozen calibration scales and frozen BN.

All forward convolutions use float64 integer products/sums, checked within the
binary64 exact-integer bound. Rounding gradients use STE; SiLU LUT gradients
use analytic SiLU. This prototype changes training only, never RTL or runtime.
"""
import copy
import numpy as np
import torch
import torch.nn.functional as F
from adapt_quant_heads import q16_weight

CUT=[48,57,64]

def away(x):return torch.sign(x)*torch.floor(torch.abs(x)+.5)
def ste_round(x):return x+(away(x)-x).detach()

def integer_conv(x,w,stride,padding):
    return F.conv2d(x.double(),w,stride=stride,padding=padding)

def fused(wrapper):
    conv=wrapper.conv
    weight=conv.weight.double()
    bias=torch.zeros(weight.shape[0],dtype=torch.float64) if conv.bias is None else conv.bias.double()
    if hasattr(wrapper,'bn'):
        bn=wrapper.bn
        assert not bn.training
        # Match torch fuse_conv_bn_eval FP32 coefficient computation exactly,
        # then convert to FP64 for exact integer emulation.
        factor=bn.weight*torch.rsqrt(bn.running_var+bn.eps)
        weight=(conv.weight*factor[:,None,None,None]).double()
        cb=conv.bias if conv.bias is not None else torch.zeros_like(bn.running_mean)
        bias=((cb-bn.running_mean)*torch.rsqrt(bn.running_var+bn.eps)*bn.weight+bn.bias).double()
    return weight,bias

class QuantTail:
    def __init__(self,model,bundle,arrays,start=65):
        from test_graph_torch import submodule
        self.model=model;self.graph=copy.deepcopy(bundle);self.arrays=arrays
        self.submodule=submodule;self.start=start
        self.luts={}
        for op in bundle['ops'][start:]:
            if op.get('execution')=='rtl_q15_conv':
                self.luts[op['idx']]=torch.tensor(arrays[f"op{op['idx']}_lut"].astype(np.float64))

    def coefficients(self,op):
        wrapper=self.submodule(self.model,op['module'][:-5])
        weight,bias=fused(wrapper)
        sx=op['input_scales'][0];spre=op['pre_scale']
        sw=weight.detach().abs().flatten(1).max(1).values.clamp(min=1e-9)/127
        wq=ste_round(weight/sw[:,None,None,None]).clamp(-127,127)
        bq=ste_round(bias/(sx*sw))
        mul=away(sx*sw/spre*32768).detach()
        return wq,bq,mul,wrapper

    def __call__(self,features,quant=True,callback=None):
        values=dict(features);heads=[]
        for op in self.graph['ops'][self.start:]:
            i=op['idx'];args=[values[j] for j in op['inputs']]
            if op['name']=='CONV':
                if op['execution']=='cpu_fp32_head':
                    layer=self.submodule(self.model,op['module'])
                    x=args[0].float()*op['input_scales'][0] if quant else args[0].float()
                    weight=q16_weight(layer.weight) if quant else layer.weight
                    value=F.conv2d(x,weight,layer.bias)
                    b,_,h,w=value.shape
                    head=self.model.model[-1]
                    heads.append(value.view(b,head.na,head.no,h,w).permute(0,1,3,4,2).contiguous())
                elif quant:
                    wq,bq,mul,wrapper=self.coefficients(op)
                    acc=integer_conv(args[0],wq,op['stride'],op['pad'])+bq[None,:,None,None]
                    assert float(acc.detach().abs().max())<2**31
                    product=acc*mul[None,:,None,None]
                    assert float(product.detach().abs().max())<2**53
                    pre=ste_round(product/32768).clamp(-128,127)
                    z=pre*op['pre_scale']
                    proxy=(F.silu(z) if type(wrapper.act).__name__=='SiLU' else z)/op['scale']
                    exact=self.luts[i][pre.detach().long()+128]
                    value=proxy+(exact-proxy).detach()
                else:
                    wrapper=self.submodule(self.model,op['module'][:-5])
                    value=wrapper(args[0].float())
            elif op['name']=='CONCAT':
                if quant:
                    ratios=[int(np.copysign(np.floor(abs(s/op['scale']*2**24)+.5),s)) for s in op['input_scales']]
                    scaled=torch.cat([x.double()*r for x,r in zip(args,ratios)],1)
                    assert float(scaled.detach().abs().max())<2**53
                    value=ste_round(scaled/2**24).clamp(-128,127)
                else:value=torch.cat(args,1)
            else:raise ValueError('Unsupported tail op '+op['name'])
            values[i]=value
            if callback:callback(op,value)
        return heads

    def export_arrays(self):
        arrays={k:np.array(self.arrays[k],copy=True) for k in self.arrays.files}
        with torch.no_grad():
            for op in self.graph['ops'][self.start:]:
                if op['name']!='CONV':continue
                prefix=f"op{op['idx']}_"
                if op['execution']=='cpu_fp32_head':
                    module=self.submodule(self.model,op['module'])
                    arrays[prefix+'weight']=module.weight.detach().numpy().copy()
                    arrays[prefix+'bias']=module.bias.detach().numpy().copy()
                else:
                    w,b,m,_=self.coefficients(op)
                    assert b.abs().max()<2**31 and m.abs().max()<2**31
                    arrays[prefix+'weight']=w.numpy().astype(np.int8)
                    arrays[prefix+'bias']=b.numpy().astype(np.int32)
                    arrays[prefix+'multiplier']=m.numpy().astype(np.int32)
        return arrays
