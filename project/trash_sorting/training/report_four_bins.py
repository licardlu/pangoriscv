"""Archive final evidence and draw plots from completed held-out evaluations."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import random
import shutil

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
import numpy as np
from PIL import Image, ImageDraw, ImageFont

NAMES = ['kitchen','recyclable','hazardous','other']
ZH = ['厨余（绿）','可回收（蓝）','有害（红）','其他（灰）']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', type=Path, required=True)
    ap.add_argument('--evidence', type=Path, required=True)
    ap.add_argument('--assets', type=Path, required=True)
    a = ap.parse_args()
    old_dir, new_dir = a.root/'runs/test_baseline_001', a.root/'runs/test_candidate_001'
    old = json.loads((old_dir/'metrics.json').read_text())
    new = json.loads((new_dir/'metrics.json').read_text())
    audit = json.loads((a.root/'four_bins_001/audit.json').read_text())
    for d,m in [(old_dir,old),(new_dir,new)]:
        assert json.loads((d/'provenance.json').read_text())['status']=='completed'
        assert m['image_primary_bin_conf025']['images']==audit['splits']['test']['images']
        assert abs(np.mean([m['per_class'][n]['AP50'] for n in NAMES])-m['mAP50'])<1e-8
        for n in NAMES:
            assert m['fixed_conf025_iou050'][n]['GT']==audit['splits']['test']['boxes'][n]
    a.evidence.mkdir(parents=True,exist_ok=True)
    a.assets.mkdir(parents=True,exist_ok=True)
    for label,d in [('test_baseline',old_dir),('test_candidate',new_dir),('stage2',a.root/'runs/full_finetune_001')]:
        e = a.evidence/label
        e.mkdir(exist_ok=True)
        for fn in ['metrics.json','provenance.json','progress.json','results.csv','hyp.yaml','opt.yaml','confusion_matrix.png','results.png']:
            if (d/fn).exists():
                shutil.copyfile(d/fn,e/fn)
    for log,sub in [('train_stage2_001.log','stage2'),('test_baseline_001.log','test_baseline'),('test_candidate_001.log','test_candidate')]:
        shutil.copyfile(a.root/log,a.evidence/sub/'run.log')
    selection = json.loads((a.evidence/'selection.json').read_text())
    checkpoint = Path(selection['candidate'])
    assert hashlib.sha256(checkpoint.read_bytes()).hexdigest()==selection['selected']['checkpoint_sha256']
    comparison = {'test_images':audit['splits']['test']['images'], 'candidate':str(checkpoint),
                  'candidate_sha256':selection['selected']['checkpoint_sha256'],
                  'old_mAP50':old['mAP50'], 'new_mAP50':new['mAP50'],
                  'mAP50_change_percentage_points':(new['mAP50']-old['mAP50'])*100,
                  'old_mAP50_95':old['mAP50_95'],'new_mAP50_95':new['mAP50_95'],
                  'old_primary_image_accuracy':old['image_primary_bin_conf025']['primary_bin_accuracy_including_missed'],
                  'new_primary_image_accuracy':new['image_primary_bin_conf025']['primary_bin_accuracy_including_missed'],
                  'classes':{n:{'old_AP50':old['per_class'][n]['AP50'],'new_AP50':new['per_class'][n]['AP50'],
                                **new['fixed_conf025_iou050'][n]} for n in NAMES},
                  'scope':'public-image held-out floating-point evaluation, fixed square 320; no FPGA/camera accuracy or speed claim'}
    (a.evidence/'comparison.json').write_text(json.dumps(comparison,indent=2),encoding='utf-8')
    fontpath = 'C:/Windows/Fonts/msyh.ttc'
    font_manager.fontManager.addfont(fontpath)
    plt.rcParams['font.family'] = font_manager.FontProperties(fname=fontpath).get_name()
    plt.rcParams['axes.unicode_minus'] = False
    fig,ax = plt.subplots(figsize=(9,4.9),constrained_layout=True)
    x = np.arange(4)
    bars1 = ax.bar(x-.18,[old['per_class'][n]['AP50']*100 for n in NAMES],.36,label='旧模型按桶合并',color='#a9b0b8')
    bars2 = ax.bar(x+.18,[new['per_class'][n]['AP50']*100 for n in NAMES],.36,label='本次重训候选',color='#207f91')
    ax.bar_label(bars1,fmt='%.1f',padding=3,fontsize=9)
    ax.bar_label(bars2,fmt='%.1f',padding=3,fontsize=9)
    ax.set_xticks(x,ZH)
    ax.set_ylim(0,107)
    ax.set_ylabel('AP@IoU 0.5（%）')
    ax.set_title(f'四桶检测留出测试：{comparison["test_images"]} 张，固定 320×320')
    ax.legend(loc='upper left',bbox_to_anchor=(0,1.01))
    ax.grid(axis='y',alpha=.2)
    ax.set_axisbelow(True)
    ax.text(.5,-.18,'公开图片测试；实物/拍摄场次隔离无法保证，不代表板载摄像头准确率。',transform=ax.transAxes,ha='center',fontsize=9,color='#555555')
    fig.savefig(a.assets/'trash-retrain-test-ap50.png',dpi=170,bbox_inches='tight')
    plt.close(fig)
    fig,ax = plt.subplots(figsize=(9,4.5),constrained_layout=True)
    offset = 0
    for label,d in [('冻结主干',a.root/'runs/frozen_backbone_002'),('解冻微调',a.root/'runs/full_finetune_001')]:
        with (d/'results.csv').open() as f:
            rr = [{k.strip():float(v) for k,v in r.items()} for r in csv.DictReader(f)]
        epochs = np.array([r['epoch'] for r in rr])+1+offset
        ax.plot(epochs,[r['metrics/mAP_0.5']*100 for r in rr],marker='o',markersize=3,label=label+' AP50')
        ax.plot(epochs,[r['metrics/mAP_0.5:0.95']*100 for r in rr],linestyle='--',label=label+' AP50:95')
        offset += len(rr)
    ax.axvline(12.5,color='#888888',linewidth=1)
    ax.set(xlabel='累计训练轮次',ylabel='验证集指标（%）',title='训练过程：仅用验证集选择权重',ylim=(0,100))
    ax.grid(alpha=.2)
    ax.legend(fontsize=8)
    fig.savefig(a.assets/'trash-retrain-learning-curve.png',dpi=170)
    plt.close(fig)
    # Deterministic examples, without choosing only successes.
    rows = json.loads((a.root/'four_bins_001/manifest.json').read_text())
    rng = random.Random(20261112)
    chosen = [r for k in range(4) for r in rng.sample([r for r in rows if r['split']=='test' and r['primary_bin']==k],2)]
    canvas = Image.new('RGB',(900,4*275+45),'white')
    font = ImageFont.truetype(fontpath,16)
    small = ImageFont.truetype(fontpath,13)
    ImageDraw.Draw(canvas).text((8,6),'绿框=标注；紫框=预测（置信度≥0.25）；按固定随机种子取图，含漏检/错分。',font=font,fill='black')
    for i,r in enumerate(chosen):
        im = Image.open(r['prepared_image']).convert('RGB')
        w,h = im.size
        draw = ImageDraw.Draw(im)
        for cid,cx,cy,bw,bh in r['boxes']:
            draw.rectangle(((cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h),outline='#00a050',width=3)
        lp = new_dir/'labels'/(Path(r['prepared_image']).stem+'.txt')
        preds = [list(map(float,s.split())) for s in lp.read_text().splitlines()] if lp.exists() else []
        for cid,cx,cy,bw,bh,conf in sorted(preds,key=lambda x:-x[5])[:5]:
            if conf<.25:
                continue
            left,top,right,bottom = (cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h
            draw.rectangle((left,top,right,bottom),outline='#cb00cc',width=2)
            draw.text((left,max(0,top-18)),f'{int(cid)} {conf:.2f}',font=small,fill='#cb00cc')
        im.thumbnail((440,240))
        left,top = (i%2)*450,(i//2)*275+40
        canvas.paste(im,(left,top))
        ImageDraw.Draw(canvas).text((left+4,top+243),ZH[r['primary_bin']]+' / '+r['source'],font=font,fill='black')
    canvas.save(a.assets/'trash-retrain-test-examples.jpg',quality=92)
    (a.evidence/'test_example_sources.json').write_text(json.dumps(chosen,indent=2),encoding='utf-8')
    print(json.dumps(comparison,indent=2),flush=True)


if __name__=='__main__':
    main()
