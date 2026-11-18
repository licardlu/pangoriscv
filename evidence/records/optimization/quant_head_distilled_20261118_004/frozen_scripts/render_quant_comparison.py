"""Render deterministic gains/losses, never final-test images."""
import argparse,json
from pathlib import Path
from adapt_quant_heads import ROOT,PARENT,read,save
from PIL import Image,ImageDraw,ImageFont

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path,required=True)
    a=p.parse_args();exp=a.experiment.resolve();root=exp.parent
    before=read(root/'baseline_q15_current_policy/decisions.json')
    after=read(exp/'evaluation/score_oldval/decisions.json')
    truth={Path(r['prepared_image']).stem:r for r in read(PARENT/'dataset_004/manifest.json') if r['split']=='val'}
    selections=[]
    for c in range(4):
        pool=sorted(k for k,r in truth.items() if any(int(b[0])==c for b in r['boxes']))
        for kind in ['gain','loss','still_wrong']:
            matching=[k for k in pool if (not before[k]['correct_class_and_iou050'] and after[k]['correct_class_and_iou050'])] if kind=='gain' else \
                [k for k in pool if (before[k]['correct_class_and_iou050'] and not after[k]['correct_class_and_iou050'])] if kind=='loss' else \
                [k for k in pool if not before[k]['correct_class_and_iou050'] and not after[k]['correct_class_and_iou050']]
            if matching:selections.append(dict(stem=matching[0],class_id=c,kind=kind))
    out=exp/'evaluation/error_gallery';out.mkdir(exist_ok=False)
    save(out/'selection.json',dict(rule='Lexicographic first gain, loss and persistent error per GT waste class; deliberately includes failures.',examples=selections))
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    for page in range((len(selections)+3)//4):
        items=selections[page*4:page*4+4]
        canvas=Image.new('RGB',(960,len(items)*300),(245,245,245));d=ImageDraw.Draw(canvas)
        for row,item in enumerate(items):
            stem=item['stem'];gt=truth[stem];assert gt['split']=='val'
            image=Image.open(gt['prepared_image']).convert('RGB');w,h=image.size
            for col,(name,prediction) in enumerate([('GT',None),('Deployed Q15',before[stem]),('Adapted Q15',after[stem])]):
                view=image.resize((320,240));v=ImageDraw.Draw(view)
                if prediction is None:
                    for c,cx,cy,bw,bh in gt['boxes']:
                        box=[(cx-bw/2)*320,(cy-bh/2)*240,(cx+bw/2)*320,(cy+bh/2)*240]
                        v.rectangle(box,outline='lime' if int(c)==4 else 'orange',width=2)
                        v.text((max(0,box[0]),max(0,box[1]-16)),str(int(c)),font=small,fill='orange')
                elif prediction['selected']:
                    b=prediction['selected'];box=[b[0]/w*320,b[1]/h*240,b[2]/w*320,b[3]/h*240]
                    color='lime' if prediction['correct_class_and_iou050'] else 'red'
                    v.rectangle(box,outline=color,width=2)
                    v.text((max(0,box[0]),max(0,box[1]-16)),f'class {int(b[5])} {b[4]:.2f}',font=small,fill=color)
                else:v.text((8,8),'No selection',font=font,fill='red')
                x=col*320;y=row*300
                canvas.paste(view,(x,y+25));d.text((x+5,y+3),name,font=font,fill='black')
            d.text((5,row*300+268),f'{stem} | GT class {item["class_id"]} | {item["kind"]}',font=small,fill='black')
        canvas.save(out/f'comparison_{page+1}.jpg',quality=92)
    print(out,flush=True)

if __name__=='__main__':main()
