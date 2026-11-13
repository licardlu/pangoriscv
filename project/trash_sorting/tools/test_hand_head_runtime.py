"""Exercise real C scalar, Q24, Q16 and sparse heads with 4/5/6 classes.

Dyadic synthetic weights provide an exact, independent dot-product oracle.
This is a host arithmetic test, not an FPGA timing or accuracy measurement.
"""
import argparse
import ctypes as C
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    sys.path.insert(0,str(ROOT/'extensions/yolo/scripts'))
    import numpy as np
    from test_deployment_cpu import Tensor,Op
    sw=ROOT/'project/trash_sorting/source/yolo/software'
    cc=a.cc.resolve();env=os.environ.copy()
    env['PATH']=str(cc.parent)+os.pathsep+env.get('PATH','')
    (a.out/'temp').mkdir();env['TMP']=env['TEMP']=str(a.out/'temp')
    dll=a.out/'head.dll'
    command=[str(cc),'-std=c11','-O2','-Wall','-Wextra','-Werror','-Wno-unused-function',
        '-shared','-DYOLO_CACHED_RUNTIME','-I'+str(sw),str(sw/'yolo_runtime.c'),
        str(ROOT/'extensions/yolo/tb/deployment_native.c'),'-lm','-o',str(dll)]
    r=subprocess.run(command,env=env,capture_output=True,text=True)
    (a.out/'build.log').write_text(r.stdout+r.stderr,encoding='utf8')
    r.check_returncode()
    lib=C.CDLL(str(dll))
    lib.native_put.argtypes=[C.c_uint32,C.c_void_p,C.c_uint32]
    lib.native_get.argtypes=lib.native_put.argtypes
    lib.native_op.argtypes=[C.POINTER(Op),C.POINTER(Tensor)]
    lib.native_set_options.argtypes=[C.c_uint32]
    lib.native_set_head_floor.argtypes=[C.c_float]
    lib.yolo_frame_workspace_get.restype=C.c_void_p
    rng=np.random.default_rng(20261112)
    checked=[]
    for nc in (4,5,6):
        channels=3*(5+nc);padded=(channels+7)//8*8
        for cin in (8,64,256):
            x=rng.integers(-128,128,(6,cin),dtype=np.int16).astype(np.int8)
            w=(rng.integers(-128,128,(channels,cin))/2048).astype(np.float32)
            b=(rng.integers(-20,20,channels)/8).astype(np.float32)
            # Include one definitely rejected and one definitely accepted anchor.
            w[4]=0;b[4]=-4;w[5+nc+4]=0;b[5+nc+4]=4
            tensors=(Tensor*2)(Tensor(0x1000,cin,cin,2,3,1/128),Tensor(0x2000,channels,padded,2,3,1))
            op=Op(kind=5,count=1,inputs=(C.c_uint16*4)(0),output=1,head_weight=0x4000,head_bias=0x20000)
            for address,value in ((0x1000,x),(0x4000,w),(0x20000,b)):
                assert lib.native_put(address,value.ctypes.data,value.nbytes)==0
            expected=np.zeros((6,padded),np.float32)
            expected[:,:channels]=(x.astype(np.float64)/128@w.astype(np.float64).T+b).astype(np.float32)
            for mode in (0,1,17,49):
                # Previous acquisition/decoder bytes must never be assumed
                # to survive or initialize the next operator's scratch.
                C.memset(lib.yolo_frame_workspace_get(),0xa5,2560)
                lib.native_set_options(mode);lib.native_set_head_floor(-1.1)
                assert lib.native_op(C.byref(op),tensors)==0,(nc,cin,mode)
                actual=np.empty_like(expected)
                assert lib.native_get(0x2000,actual.ctypes.data,actual.nbytes)==0
                reference=expected.copy()
                if mode==49:
                    for anchor in range(3):
                        base=anchor*(5+nc);reject=reference[:,base+4]<-1.1
                        for col in range(5+nc):
                            if col!=4:reference[reject,base+col]=0
                np.testing.assert_array_equal(actual,reference,err_msg=str((nc,cin,mode)))
                checked.append(dict(classes=nc,input_channels=cin,options=mode))
            tensors[1].c=29
            assert lib.native_op(C.byref(op),tensors)==3
    result=dict(status='PASS',scope=__doc__,cases=checked,compiler_command=command)
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print('TEST_PASS head_runtime scalar/Q24/Q16/sparse 4/5/6 classes 36 cases',flush=True)


if __name__=='__main__':main()
