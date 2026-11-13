"""Replay the actual C target selector on saved detections, without retraining.

Personal-photo truth is image-level only; dataset hand labels permit hand-only
false-acceptance counts, not held-object association accuracy.
"""
import argparse
from collections import Counter
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]
PROJECT=ROOT/'project/trash_sorting'


class Box(C.Structure):
    _fields_=[(k,C.c_float) for k in ('x1','y1','x2','y2','score')]+[('category',C.c_uint32)]


class Target(C.Structure):
    _fields_=[('object_index',C.c_int),('hand_index',C.c_int),('hand_seen',C.c_uint),
              *[(k,C.c_float) for k in ('roi_x1','roi_y1','roi_x2','roi_y2')]]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--predictions',type=Path,required=True)
    p.add_argument('--personal-inventory',type=Path)
    p.add_argument('--truth',type=Path)
    p.add_argument('--classes',type=int,choices=(4,5),required=True)
    p.add_argument('--target-policy',choices=('roi','contact'),default='roi')
    p.add_argument('--cc',type=Path,required=True)
    p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=False)
    cc=a.cc.resolve();env=os.environ.copy();env['PATH']=str(cc.parent)+os.pathsep+env.get('PATH','')
    (a.out/'temp').mkdir();env['TMP']=env['TEMP']=str(a.out/'temp')
    sw=PROJECT/'source/yolo/software';dll=a.out/'policy.dll'
    contact=a.target_policy=='contact'
    policy_source='test_contact_policy.c' if contact else 'test_target_policy.c'
    policy_header='yolo_contact_policy.h' if contact else 'yolo_target_policy.h'
    command=[str(cc),'-std=c11','-O2','-Wall','-Wextra','-Werror','-shared','-I'+str(sw),
        str(PROJECT/'tools'/policy_source),'-lm','-o',str(dll)]
    r=subprocess.run(command,capture_output=True,text=True,env=env)
    (a.out/'build.log').write_text(r.stdout+r.stderr,encoding='utf8');r.check_returncode()
    lib=C.CDLL(str(dll))
    lib.policy_select.argtypes=[C.POINTER(Box),C.c_uint32,C.c_uint32,C.c_uint32,C.c_float,C.c_float]
    lib.policy_select.restype=Target
    raw=json.loads(a.predictions.read_text(encoding='utf8'))
    truth={r['id']:r for r in json.loads(a.truth.read_text(encoding='utf8'))['images']} if a.truth else {}
    rows=[]
    if isinstance(raw,list):
        if not a.personal_inventory:raise ValueError('Personal predictions require inventory sizes')
        inventory={r['id']:r for r in json.loads(a.personal_inventory.read_text(encoding='utf8'))}
        for r in raw:
            w,h=inventory[r['id']]['display_size']
            rows.append(dict(r,key=r['id'],width=w,height=h,source='personal',
                boxes=[[*d['box'],d['score'],d['category']] for d in r['detections']]))
    else:
        for key,r in raw.items():rows.append(dict(r,key=key,boxes=r['detections']))
    decisions=[];sources={};groups={}
    for r in rows:
        ds=sorted((d for d in r['boxes'] if d[4]>=.25),key=lambda d:-d[4])[:32]
        boxes=(Box*len(ds))(*[Box(*d[:5],int(d[5])) for d in ds])
        selected=lib.policy_select(boxes,len(ds),4,4 if a.classes==5 else 0xffffffff,r['width'],r['height'])
        index=selected.object_index
        category=int(ds[index][5]) if index>=0 else None
        top=int(ds[0][5]) if ds else None
        d=dict(key=r['key'],source=r['source'],top=top,selected=category,
            selected_index=index,hand_seen=bool(selected.hand_seen),hand_index=selected.hand_index,
            roi=[selected.roi_x1,selected.roi_y1,selected.roi_x2,selected.roi_y2],detections=ds)
        s=sources.setdefault(r['source'],Counter())
        s['images']+=1;s['hand_seen']+=selected.hand_seen;s['selected']+=index>=0
        s['changed_from_highest_score']+=category!=top
        if r['source']=='hagrid_hand_localisation':s['hand_only_false_acceptance']+=index>=0
        if r['key'] in truth:
            gt=truth[r['key']];accepted=gt.get('accepted_bins',[gt['bin']])
            d.update(truth_bin=gt['bin'],strict_correct=category==gt['bin'],
                relaxed_correct=category in accepted,top_relaxed_correct=top in accepted)
            g=groups.setdefault(gt['group'],Counter())
            for dest in (s,g):
                dest['evaluated']+=1;dest['strict_correct']+=d['strict_correct']
                dest['relaxed_correct']+=d['relaxed_correct'];dest['top_relaxed_correct']+=d['top_relaxed_correct']
        decisions.append(d)
    report=dict(status='COMPLETED',scope=__doc__,source_sha256=hashlib.sha256(a.predictions.read_bytes()).hexdigest(),
        target_policy=a.target_policy,
        policy_sha256=hashlib.sha256((sw/policy_header).read_bytes()).hexdigest(),
        common_geometry_sha256=hashlib.sha256((sw/'yolo_target_policy.h').read_bytes()).hexdigest(),
        classes=a.classes,sources=sources,personal_groups=groups,decisions=decisions)
    (a.out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k!='decisions'}),flush=True)


if __name__=='__main__':main()
