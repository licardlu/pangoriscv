"""Compare deployed C operators and evaluate Q15 + C Q16 heads on all personal photos.

Convolution uses an exact-arithmetic software oracle; this is not FPGA testing.
"""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[4]
PROJECT=ROOT/'project/trash_sorting'


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--deployment',type=Path,required=True)
    ap.add_argument('--yolo',type=Path,required=True)
    ap.add_argument('--cc',type=Path,required=True)
    ap.add_argument('--clang-host',action='store_true',
                    help='Host compiler is Clang; ignore unsupported GCC optimize attributes only')
    ap.add_argument('--exact-q16-head',action='store_true',
                    help='Check C head bit-for-bit against independent integer-dot Q16 oracle, plus coefficient-derived FP error bound')
    ap.add_argument('--source-dir',type=Path,default=PROJECT/'source')
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--checkpoint',type=Path,
                    default=PROJECT/'training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt')
    ap.add_argument('--expected-checkpoint-sha256')
    ap.add_argument('--photos',type=Path,default=ROOT/'evidence/records/trash-personal-photos-20261112-001',
                    help='Fixed inventory.json and truth.json; source images stay in place')
    ap.add_argument('--skip-fixtures',action='store_true',help='Only perform offline arithmetic checks')
    ap.add_argument('--linear-o2', action='store_true',
                    help='Compile runtime with production Os plus opt-in linear O2')
    ap.add_argument('--packed-add', action='store_true',
                    help='Compile exact bounded Q24 ADD product-table candidate')
    a=ap.parse_args()
    a.out=a.out.resolve()
    a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    (a.out/'config').mkdir()
    os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(a.yolo.resolve()))
    sys.path.insert(0,str(ROOT/'extensions/yolo/scripts'))
    import cv2
    import numpy as np
    import torch
    from PIL import Image,ImageOps
    from utils.augmentations import letterbox
    from deployment_bundle import Deployment
    from test_deployment_cpu import Tensor,Op,Layer
    torch.set_num_threads(4)
    torch.set_num_interop_threads(1)
    cc=a.cc.resolve()
    env=os.environ.copy()
    env['PATH']=str(cc.parent)+os.pathsep+env.get('PATH','')
    (a.out/'temp').mkdir()
    env['TMP']=env['TEMP']=str(a.out/'temp')
    sw=a.source_dir.resolve()/'yolo/software'
    packed=json.loads((a.deployment/'packed/memory_map.json').read_text(encoding='utf8'))
    nc=packed.get('raw_model_classes',4)
    if nc not in (4,5) or any(packed['tensors'][i]['c']!=3*(5+nc) for i in packed['outputs']):
        raise ValueError('Unsupported packed model class schema')
    anchor_values=5+nc
    dll=a.out/'runtime.dll'
    command=[str(cc),'-std=c11','-O2','-Wall','-Wextra','-Werror','-Wno-unused-function',
             '-shared','-DNATIVE_DECODE','-DNATIVE_SHARED_FRAME_WORKSPACE',f'-DYOLO_CLASSES={nc}','-DYOLO_SINGLE_LABEL=1',
             '-I'+str(sw),str(sw/'yolo_runtime.c'),str(sw/'yolo_decode.c'),
             str(ROOT/'extensions/yolo/tb/deployment_native.c'),'-lm','-o',str(dll)]
    if a.linear_o2:
        command[command.index('-O2')] = '-Os'
        command.insert(1, '-DYOLO_LINEAR_O2')
    if a.clang_host:
        command.insert(1, '-Wno-unknown-attributes')
    if a.exact_q16_head:
        command.insert(1, '-ffp-contract=off')
    if a.packed_add:
        command.insert(1, '-DYOLO_PACKED_ADD')
    result=subprocess.run(command,env=env,capture_output=True,text=True)
    (a.out/'build.log').write_text(result.stdout+result.stderr,encoding='utf8')
    if result.returncode:
        raise RuntimeError(result.stdout+result.stderr)
    lib=C.CDLL(str(dll))
    lib.native_put.argtypes=[C.c_uint32,C.c_void_p,C.c_uint32]
    lib.native_get.argtypes=[C.c_uint32,C.c_void_p,C.c_uint32]
    lib.native_op.argtypes=[C.POINTER(Op),C.POINTER(Tensor)]
    lib.native_set_options.argtypes=[C.c_uint32]
    lib.native_set_head_floor.argtypes=[C.c_float]
    class Box(C.Structure):
        _fields_=[(k,C.c_float) for k in ['x1','y1','x2','y2','score']]+[('category',C.c_uint32)]
    lib.native_decode.argtypes=[C.POINTER(Tensor),C.c_float,C.c_float,C.c_float,
                               C.c_uint32,C.c_uint32,C.POINTER(Box),C.POINTER(C.c_uint32)]
    lib.native_set_options(63)
    head_floor=-1.0996123  # firmware logit(.25) minus .001 margin
    lib.native_set_head_floor(head_floor)
    blob=(a.deployment/'packed/model.bin').read_bytes()
    assert hashlib.sha256(blob).hexdigest()==packed['blob_sha256']
    assert not lib.native_put(packed['blob_base'],blob,len(blob))
    tensors=(Tensor*len(packed['tensors']))(*[Tensor(**{k:v for k,v in t.items() if k!='fp32'}) for t in packed['tensors']])
    ops=[]
    for item in packed['ops']:
        keys={k:v for k,v in item.items() if k not in ('kind','inputs','ratios','conv')}
        ops.append(Op(kind=['YOLO_CONV','YOLO_POOL','YOLO_UPSAMPLE','YOLO_CONCAT','YOLO_ADD','YOLO_HEAD'].index(item['kind']),
                      inputs=(C.c_uint16*4)(*item['inputs']),ratios=(C.c_uint32*4)(*item['ratios']),
                      conv=Layer(**item.get('conv',{})),**keys))
    cp=a.checkpoint.resolve()
    cp_sha=hashlib.sha256(cp.read_bytes()).hexdigest()
    if a.expected_checkpoint_sha256 and cp_sha != a.expected_checkpoint_sha256:
        raise ValueError('Checkpoint identity changed')
    graph=json.loads((a.deployment/'graph.json').read_text(encoding='utf8'))
    if cp_sha != packed.get('checkpoint_sha256',graph.get('checkpoint_sha256')):
        raise ValueError('Checkpoint and calibrated model identity differ')
    deployment=Deployment(a.deployment/'bundle',checkpoint=cp)
    photos=a.photos.resolve()
    inventory=json.loads((photos/'inventory.json').read_text(encoding='utf8'))
    truth=json.loads((photos/'truth.json').read_text(encoding='utf8'))
    decisions=[]
    fixtures=[]
    (a.out/'fixtures').mkdir()
    checked=0
    max_head_error=0.0
    max_q16_bound=0.0
    for row in inventory:
        path=Path(row['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
        with Image.open(path) as im:
            rgb=np.array(ImageOps.exif_transpose(im).convert('RGB'))
        h,w=rgb.shape[:2]
        ratio=min(320/h,320/w)
        nw,nh=round(w*ratio),round(h*ratio)
        left,top=(320-nw)//2,(320-nh)//2
        canvas=np.full((320,320,3),114,np.uint8)
        canvas[top:top+nh,left:left+nw]=cv2.resize(rgb,(nw,nh))
        image=torch.from_numpy(canvas.transpose(2,0,1).copy()[None]).float()/255
        input_hwc=np.zeros((320,320,8),np.int8)
        input_hwc[:,:,:3]=np.floor(canvas.astype(np.float64)/255*127+.5).astype(np.int8)
        assert not lib.native_put(tensors[0].address,input_hwc.ctypes.data,input_hwc.nbytes)
        def observe(original,value):
            nonlocal checked,max_head_error,max_q16_bound
            idx=original['idx']
            item=packed['ops'][idx]
            t=packed['tensors'][item['output']]
            expected=np.zeros((t['h'],t['w'],t['padded_c']),value.dtype)
            expected[:,:,:t['c']]=value[0].transpose(1,2,0)
            if item['kind']=='YOLO_HEAD' or (row['id']==1 and item['kind']!='YOLO_CONV'):
                rc=lib.native_op(C.byref(ops[idx]),tensors)
                if rc:
                    raise RuntimeError(f'C operator {idx}: {rc}')
                actual=np.empty_like(expected)
                assert not lib.native_get(t['address'],actual.ctypes.data,actual.nbytes)
                if item['kind']=='YOLO_HEAD':
                    # Sparse path intentionally leaves non-object logits zero
                    # for anchors whose object score cannot pass the decoder.
                    reference=expected.copy()
                    for anchor in range(3):
                        reject=actual[:,:,anchor*anchor_values+4]<head_floor
                        for ch in range(anchor_values):
                            if ch!=4:
                                reference[:,:,anchor*anchor_values+ch][reject]=0
                    error=float(np.abs(actual-reference).max())
                    max_head_error=max(max_head_error,error)
                    if a.exact_q16_head:
                        it=packed['tensors'][item['inputs'][0]]
                        inp=np.empty((it['h'],it['w'],it['padded_c']),dtype=np.int8)
                        assert not lib.native_get(it['address'],inp.ctypes.data,inp.nbytes)
                        weights=np.frombuffer(blob,dtype='<f4',count=t['c']*it['c'],
                            offset=item['head_weight']-packed['blob_base']).reshape(t['c'],it['c']).copy()
                        biases=np.frombuffer(blob,dtype='<f4',count=t['c'],
                            offset=item['head_bias']-packed['blob_base']).copy()
                        scales=np.full(t['c'],65536,dtype=np.float32)
                        while True:
                            invalid=(weights*scales[:,None]).min(1)<-32768
                            invalid|=(weights*scales[:,None]).max(1)>32767
                            if not invalid.any():break
                            scales[invalid]*=np.float32(.5)
                        scaled=weights*scales[:,None]
                        q=np.trunc(scaled+np.where(scaled>=0,np.float32(.5),np.float32(-.5))).astype(np.int64)
                        assert q.min()>=-32768 and q.max()<=32767
                        dots=inp[:,:,:it['c']].astype(np.int64)@q.T
                        assert np.abs(dots).max()<=2147483647
                        factors=(np.float32(1)/scales)*np.float32(it['scale'])
                        exact=np.zeros_like(actual)
                        exact[:,:,:t['c']]=dots.astype(np.float32)*factors[None,None,:]+biases[None,None,:]
                        for anchor in range(3):
                            reject=exact[:,:,anchor*anchor_values+4]<head_floor
                            for ch in range(anchor_values):
                                if ch!=4:exact[:,:,anchor*anchor_values+ch][reject]=0
                        np.testing.assert_array_equal(actual,exact,err_msg=f'exact Q16 head {idx}')
                        # Absolute coefficient error times actual |input| bounds quantization.
                        # gamma covers both float32 reductions and separate final operations.
                        delta=np.abs(q.astype(np.float64)/scales[:,None]-weights.astype(np.float64))
                        xabs=np.abs(inp[:,:,:it['c']].astype(np.float64))
                        coeff=(xabs@delta.T)*float(np.float32(it['scale']))
                        magnitude=(xabs@np.abs(weights.astype(np.float64)).T)*float(np.float32(it['scale']))+np.abs(biases)
                        eps=np.finfo(np.float32).eps
                        gamma=(it['c']+8)*eps/(1-(it['c']+8)*eps)
                        bound=coeff+gamma*magnitude+np.finfo(np.float32).tiny
                        active=np.ones_like(bound,dtype=bool)
                        for anchor in range(3):
                            reject=exact[:,:,anchor*anchor_values+4]<head_floor
                            for ch in range(anchor_values):
                                if ch!=4:active[:,:,anchor*anchor_values+ch][reject]=False
                        max_q16_bound=max(max_q16_bound,float(bound[active].max()))
                        assert np.all(np.abs(actual[:,:,:t['c']]-reference[:,:,:t['c']])[active]<=bound[active]),f'coefficient bound head {idx}'
                    else:
                        np.testing.assert_allclose(actual,reference,atol=3e-4,rtol=2e-4,err_msg=f'head {idx}')
                else:
                    np.testing.assert_array_equal(actual,expected,err_msg=f'op {idx}')
                    checked+=1
            else:
                assert not lib.native_put(t['address'],expected.ctypes.data,expected.nbytes)
        with torch.no_grad():
            deployment.execute(image,observe)
        heads=(Tensor*3)(*[tensors[i] for i in packed['outputs']])
        boxes=(Box*32)()
        count=C.c_uint32()
        rc=lib.native_decode(heads,ratio,left,top,w,h,boxes,C.byref(count))
        assert not rc
        detections=[dict(category=b.category,score=b.score,box=[b.x1,b.y1,b.x2,b.y2]) for b in boxes[:count.value]]
        decisions.append(dict(id=row['id'],file=row['file'],detections=detections,
                              top_category=detections[0]['category'] if detections else None))
        if not a.skip_fixtures and row['id'] in (1,23,38,76):
            payload=input_hwc.tobytes()
            filename=f"input_{row['id']:02d}.bin"
            (a.out/'fixtures'/filename).write_bytes(payload)
            fixtures.append(dict(id=row['id'],file=filename,sha256=hashlib.sha256(payload).hexdigest(),
                                 ratio=ratio,pad_x=left,pad_y=top,width=w,height=h,
                                 expected=detections))
        if row['id']%10==0:
            print('Q15_C_HEAD_PHOTOS '+str(row['id'])+'/'+str(len(inventory)),flush=True)
        (a.out/'predictions.json').write_text(json.dumps(decisions,indent=2),encoding='utf8')
    result=dict(status='PASS',scope='software Q15 convolution oracle + actual C Q16 head/decoder; not FPGA accuracy',
                model_sha256=packed['blob_sha256'],cpu_non_head_ops_checked=checked,
                head_checks=len(decisions)*3,max_head_absolute_error=max_head_error,
                head_verification='bit-exact independent Q16 integer dot + coefficient/float32 bound' if a.exact_q16_head else 'fixed FP head tolerance',
                max_coefficient_float32_error_bound=max_q16_bound if a.exact_q16_head else None,
                images=len(decisions),compiler_command=command,
                truth_sha256=hashlib.sha256((photos/'truth.json').read_bytes()).hexdigest())
    (a.out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    (a.out/'fixtures/manifest.json').write_text(json.dumps(dict(model_sha256=packed['blob_sha256'],
        scope='four numerical compatibility fixtures, selected for bucket coverage; not an accuracy benchmark',
        cases=fixtures),indent=2),encoding='utf8')
    print('FOUR_BIN_Q15_C_CHECK_PASS '+json.dumps(result),flush=True)


if __name__=='__main__':
    main()
