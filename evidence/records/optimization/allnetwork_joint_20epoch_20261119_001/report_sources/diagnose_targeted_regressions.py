"""Diagnose existing development predictions at fixed policy, without tuning or test access."""
import argparse
from collections import Counter
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from adapt_quant_heads import ROOT,read,save,sha


def iou(a,b):
    intersection=max(0,min(a[2],b[2])-max(a[0],b[0]))*max(0,min(a[3],b[3])-max(a[1],b[1]))
    union=max(0,a[2]-a[0])*max(0,a[3]-a[1])+max(0,b[2]-b[0])*max(0,b[3]-b[1])-intersection
    return intersection/union if union else 0.


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();out=exp/'evaluation/targeted_regressions';assert not out.exists()
    plan=read(exp/'plan.json');manifest=read(plan['manifest'])
    truth={Path(r['prepared_image']).stem:r for r in manifest if r['split']=='val'}
    baseline=ROOT/'build/quant_head_adapt_20261118_001/baseline_q15_current_policy/decisions.json'
    before=read(baseline);after=read(exp/'evaluation/score_oldval/decisions.json')
    inventory=read(ROOT/'build/overnight_20261116/numeric_allval_001/inventory.json')
    photos={r['id']:r for r in inventory}
    sizes={Path(r['path']).stem:r['display_size'] for r in inventory}
    raw={Path(photos[r['id']]['path']).stem:r['detections'] for r in read(exp/'evaluation/numeric_oldval/predictions.json')}
    floatdecisions=read(exp/'evaluation/replay_float/decisions.json')['float_oldval']
    assert set(before)==set(after)==set(truth)
    groups={k:[] for k in ['personal_battery','public_glass','empty_hand']};records={};counts={}
    for stem,r in truth.items():
        source=r['source'];image=str(r.get('image','')).replace('\\','/').lower()
        cohort='personal_battery' if source=='personal_电池' else 'public_glass' if '/glass/' in image else 'empty_hand' if not any(int(b[0])<4 for b in r['boxes']) else None
        if cohort:groups[cohort].append(stem)
    for cohort,stems in groups.items():
        stat=Counter();details=[]
        for stem in sorted(stems):
            r=truth[stem];old,new=before[stem],after[stem];selected=new['selected']
            waste=[b for b in r['boxes'] if int(b[0])<4]
            if waste:
                wrong=not new['correct_class_and_iou050'];oldwrong=not old['correct_class_and_iou050']
                kind='no_selection' if not selected else 'wrong_class' if not any(int(b[0])==int(selected[5]) for b in waste) else 'localization' if wrong else 'correct'
                stat['positive']+=1;stat['baseline_correct']+=not oldwrong;stat['candidate_correct']+=not wrong
                stat['gains']+=oldwrong and not wrong;stat['regressions']+=not oldwrong and wrong
                w,h=sizes[stem]
                matching=[d for d in raw[stem] if any(int(d['category'])==int(c) and
                    iou(d['box'],[(cx-bw/2)*w,(cy-bh/2)*h,(cx+bw/2)*w,(cy+bh/2)*h])>=.5
                    for c,cx,cy,bw,bh in waste)]
                failure_stage=('correct' if not wrong else 'selector_rejected_existing_correct_detection' if matching and not selected
                    else 'selector_chose_other_despite_correct_detection' if matching
                    else 'no_correct_decoded_detection_at_fixed025')
                if wrong:stat[failure_stage]+=1
            else:
                wrong=bool(selected);oldwrong=bool(old['selected']);kind='false_selection' if wrong else 'correct_rejection'
                stat['background']+=1;stat['baseline_false']+=oldwrong;stat['candidate_false']+=wrong
                stat['new_false']+=not oldwrong and wrong;stat['removed_false']+=oldwrong and not wrong
            stat[kind]+=1
            floated=floatdecisions[stem]
            stat['float_correct_q15_wrong']+=bool(waste and floated['correct_class_and_iou050'] and wrong)
            if wrong:
                details.append(dict(stem=stem,kind=kind,regression=not oldwrong,selected=selected,
                    failure_stage=failure_stage if waste else 'false_selection_on_gt_no_waste',
                    correct_raw_detections=matching if waste else [],raw_detections=raw[stem],
                    original_selected=old['selected'],hand_seen=new['hand_seen'],original_hand_seen=old['hand_seen'],
                    float_correct=bool(floated['correct_class_and_iou050']),float_selected=floated['selected']))
        counts[cohort]=dict(stat);records[cohort]=details
    out.mkdir();save(out/'result.json',dict(status='COMPLETED_FIXED_POLICY_DEVELOPMENT_DIAGNOSTIC',
        cohorts=counts,errors=records,thresholds_changed=False,weights_changed=False,final_test_read=False,
        limitations=['Existing repeatedly used development data, not independent test.',
                    'Empty-hand cases do not establish cluttered empty-background rejection.',
                    'Decoded detections use the unchanged conf.25/NMS/max32 policy; absence here does not prove raw-logit absence. Correct decoded boxes rejected by the selector are separated without changing thresholds.'],
        evidence_sha256={str(p):sha(p) for p in [baseline,exp/'evaluation/score_oldval/decisions.json',exp/'evaluation/replay_float/decisions.json',exp/'evaluation/numeric_oldval/predictions.json']}))
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    selections=[]
    for cohort,details in records.items():
        regressions=[d for d in details if d['regression']];persistent=[d for d in details if not d['regression']]
        selections.extend((cohort,d) for d in (regressions+persistent)[:8])
    for page in range((len(selections)+3)//4):
        items=selections[page*4:page*4+4];canvas=Image.new('RGB',(960,len(items)*285),'white');draw=ImageDraw.Draw(canvas)
        for row,(cohort,detail) in enumerate(items):
            stem=detail['stem'];r=truth[stem];assert r['split']=='val'
            with Image.open(r['prepared_image']) as image:
                image=image.convert('RGB');w,h=image.size
                for col,(label,decision) in enumerate([('GT',None),('Original Q15',before[stem]),('Candidate Q15',after[stem])]):
                    view=image.resize((320,240));d=ImageDraw.Draw(view)
                    if decision is None:
                        for c,cx,cy,bw,bh in r['boxes']:
                            rect=[(cx-bw/2)*320,(cy-bh/2)*240,(cx+bw/2)*320,(cy+bh/2)*240]
                            d.rectangle(rect,outline='lime' if int(c)==4 else 'orange',width=2)
                    elif decision['selected']:
                        b=decision['selected'];rect=[b[0]/w*320,b[1]/h*240,b[2]/w*320,b[3]/h*240]
                        d.rectangle(rect,outline='red',width=2);d.text((3,3),f'class {int(b[5])} score {b[4]:.3f}',fill='red',font=font)
                    else:d.text((3,3),'No selection',fill='red',font=font)
                    canvas.paste(view,(col*320,row*285+21));draw.text((col*320+3,row*285+2),label,fill='black',font=font)
            draw.text((3,row*285+263),f'{cohort} {stem} {detail["kind"]} regression={detail["regression"]}',fill='black',font=font)
        canvas.save(out/('errors_%02d.jpg'%(page+1)),quality=92)
    save(out/'gallery_selection.json',selections)
    print(counts,flush=True)


if __name__=='__main__':main()
