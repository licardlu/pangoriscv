"""Extend three detection heads from four bins to four bins + hand.

Copy each anchor's existing nine rows exactly; only the hand class row is new.
No FPGA files or active model are modified.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--weights',type=Path,required=True)
    p.add_argument('--expected-sha256',required=True)
    p.add_argument('--yolo',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args()
    cp_sha=hashlib.sha256(a.weights.read_bytes()).hexdigest()
    if cp_sha!=a.expected_sha256:
        raise ValueError('Checkpoint identity mismatch')
    a.out.mkdir(parents=True,exist_ok=False)
    os.environ['YOLOV5_CONFIG_DIR']=str(a.out/'config')
    os.environ['YOLOv5_AUTOINSTALL']='false'
    sys.path.insert(0,str(a.yolo.resolve()))
    import torch
    from torch import nn
    torch.set_num_threads(2);torch.manual_seed(20261112)
    cp=torch.load(a.weights,map_location='cpu')
    model=(cp.get('ema') or cp['model']).float().eval()
    detect=model.model[-1]
    if detect.nc!=4 or detect.na!=3:
        raise ValueError('Expected original four-bin three-anchor heads')
    checks=[]
    for i,old in enumerate(detect.m):
        new=nn.Conv2d(old.in_channels,30,1)
        with torch.no_grad():
            # Zero new weights and low initial class score avoid inventing
            # confident hands before learning. Existing logits are preserved.
            new.weight.zero_();new.bias.fill_(-4.59511985)
            for anchor in range(3):
                new.weight[anchor*10:anchor*10+9].copy_(old.weight[anchor*9:anchor*9+9])
                new.bias[anchor*10:anchor*10+9].copy_(old.bias[anchor*9:anchor*9+9])
                assert torch.equal(new.weight[anchor*10:anchor*10+9],old.weight[anchor*9:anchor*9+9])
                assert torch.equal(new.bias[anchor*10:anchor*10+9],old.bias[anchor*9:anchor*9+9])
            x=torch.randn(1,old.in_channels,5,7)
            old_logits=old(x).reshape(1,3,9,5,7)
            new_logits=new(x).reshape(1,3,10,5,7)
            # Changing GEMM output width can change FP32 accumulation order;
            # weight/bias rows above, rather than GEMM outputs, must be exact.
            torch.testing.assert_close(new_logits[:,:,:9],old_logits,rtol=1e-5,atol=2e-6)
            error=float((new_logits[:,:,:9]-old_logits).abs().max())
        detect.m[i]=new
        checks.append(dict(head=i,inherited_rows_per_anchor=9,new_rows_per_anchor=1,
                           inherited_parameters_bit_exact=True,max_fp32_output_error=error))
    detect.nc=5;detect.no=10
    model.yaml['nc']=5
    model.names=['kitchen','recyclable','hazardous','other','hand']
    model.eval()
    with torch.inference_mode():
        prediction=model(torch.zeros(1,3,320,320))[0]
    if prediction.shape!=(1,6300,10):
        raise ValueError('Unexpected five-class geometry')
    target=a.out/'initial_hand_game.pt'
    torch.save(dict(model=model,ema=None,epoch=-1,optimizer=None,best_fitness=0),target)
    report=dict(source_sha256=cp_sha,checkpoint_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        internal_classes=model.names,head_checks=checks,prediction_shape=list(prediction.shape),
        active_fpga_model_modified=False,board_programmed=False)
    (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report),flush=True)


if __name__=='__main__':
    main()
