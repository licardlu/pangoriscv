"""Record an explicit visual review of glass objects and visible hands.

The four glass contact sheets and nine enlarged details were inspected. Only
listed photographs are admitted to the overlay-review stage. Source labels are
not predictions. Existing held-out files and all active datasets stay unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from collect_public_expansion import sheets


ACCEPT = [1,3,7,8,11,14,15,16,18,19,20,22,24,26,27,28,30,31,32,33,34,35,36,38,
          41,43,44,45,48,51,52,53,54,55,56,57,58,59,60,61,62,64,70,71,72,
          76,77,78,79,80,82,84,85,86,87,89,90,91]
# Complete replacement object boxes in the 1440 x 1920 contact sheet geometry.
SHEET = {
    7: [(1,810,369,996,548)],
    8: [(1,1164,347,1236,535),(1,1243,367,1297,535),(1,1301,461,1365,540)],
    46: [(1,429,1651,496,1813),(1,510,1603,572,1825),(1,584,1644,627,1784)],
    48: [(1,1168,1633,1206,1769),(1,1202,1640,1241,1770),(1,1244,1640,1280,1769),
         (1,1282,1638,1318,1769),(1,1318,1629,1357,1769)],
    57: [(1,151,646,294,908)],
    60: [(1,1219,727,1288,812)],
    72: [(1,1179,1632,1313,1815)],
    76: [(1,1213,0,1396,173)],
    78: [(1,459,354,523,547),(1,515,352,597,573)],
    80: [(1,1174,385,1340,520)],
    86: [(1,465,960,675,1228)],
    87: [(1,809,960,876,1202),(1,874,961,935,1177),(1,929,960,994,1204)],
    91: [(1,797,1400,862,1498),(1,855,1407,935,1525),(1,946,1408,1014,1498)],
}
# Complete boxes on separately enlarged full frames; foreground hands include
# their visible palm/fingers to the wrist. Feet and forearms aren't hand labels.
DETAIL = {
    11: [(1,282,171,858,720),(4,303,436,587,720)],
    16: [(1,71,0,383,595),(4,9,18,403,427)],
    18: [(1,234,29,894,684),(4,542,289,817,626)],
    24: [(1,429,320,644,521),(4,438,260,960,720)],
    36: [(1,237,311,797,553),(4,97,0,365,167)],
    77: [(1,258,289,788,492),(4,480,233,960,720)],
    79: [(1,142,286,761,515)],
    82: [(1,242,289,870,574),(4,228,91,607,319)],
    85: [(1,202,185,317,570),(4,128,272,325,549)],
}
OBJECT_DETAIL = {
    3: [(1,49,209,437,595)],
    15: [(1,54,184,446,575)],
    20: [(1,31,252,510,633),(1,0,0,105,145)],
    27: [(1,48,158,482,599)],
    38: [(1,61,264,451,609)],
    48: [(1,147,145,285,623),(1,283,151,431,628),(1,430,155,558,628),
         (1,552,145,710,625),(1,709,124,836,624)],
    91: [(1,76,327,262,554),(1,217,377,443,639),(1,463,339,656,572)],
}


def read(path):
    return json.loads(Path(path).read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def normalized(items, origin, display):
    ox,oy = origin; dw,dh = display
    result = []
    for c,x1,y1,x2,y2 in items:
        assert c in [1,4] and ox-2 <= x1 < x2 <= ox+dw+2 and oy-2 <= y1 < y2 <= oy+dh+2, (items,origin,display)
        a,b = max(0,(x1-ox)/dw),max(0,(y1-oy)/dh)
        d,e = min(1,(x2-ox)/dw),min(1,(y2-oy)/dh)
        result.append([c,(a+d)/2,(b+e)/2,d-a,e-b])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path)
    args = parser.parse_args()
    root = Path('build/wastesense_review_20261118_001')
    inventory = {r['id']:r for r in read(root/'inventory.json')}
    order = read(root/'glass_review/order.json')
    details = read(root/'glass_hand_details/layout.json')
    object_details = read(root/'glass_object_details/layout.json')
    out = args.out or root/'glass_annotations_001'; out.mkdir(exist_ok=False)
    accepted,ledger = [],{}
    for n,key in enumerate(order,1):
        row = inventory[key]
        assert row['admission'] == 'REQUIRES_VISUAL_COMPLETE_INSTANCE_AND_POLICY_REVIEW'
        if n not in ACCEPT:
            ledger[key] = dict(status='EXCLUDED_NOT_ADMITTED', source_sha256=row['image_sha256'],
                review_index=n,reason='Uncertain material/shape, broken panes, watermark/product graphic, crowded scene or incomplete-instance/hand review. Not an empty image.')
            continue
        assert sha(row['path']) == row['image_sha256']
        assert all(b['category_id'] == 0 for b in row['annotations']), key
        w,h = row['width'],row['height']
        if n in DETAIL:
            boxes = normalized(DETAIL[n],(0,0),details[str(n)]['display_size'])
            method = 'Complete manual object/hand replacement from enlarged full frame'
        elif n in OBJECT_DETAIL:
            boxes = normalized(OBJECT_DETAIL[n],(0,0),object_details[str(n)]['display_size'])
            method = 'Complete manual glass replacement after enlarged rim/handle/cap and additional-instance check'
        elif n in SHEET:
            probe = Image.new('1',(w,h)); probe.thumbnail((350,270))
            dw,dh = probe.size; local = (n-1)%24
            origin = ((local%4)*360+(360-dw)//2,(local//4)*320)
            boxes = normalized(SHEET[n],origin,(dw,dh))
            method = 'Complete manual object replacement; caps, handles and every additional visible glass instance included'
        else:
            boxes = [[1,(b['bbox'][0]+b['bbox'][2]/2)/w,(b['bbox'][1]+b['bbox'][3]/2)/h,
                      b['bbox'][2]/w,b['bbox'][3]/h] for b in row['annotations']]
            method = 'Every visible source polygon extent visually checked; glass maps to recyclable'
        ledger[key] = dict(status='REVIEWED_PENDING_FINAL_OVERLAY',reviewer='assistant_visual',
            source_sha256=row['image_sha256'],review_index=n,method=method,boxes=boxes,
            source_polygon_label_sha256=row['label_sha256'],
            policy='Intended glass containers/utensils are recyclable; visible hands are internal class4. Stationary laptop/notebook/furniture are background, feet are not hands.')
        item=dict(row,mapped_boxes=boxes,review_index=n)
        item['category_names']={'1':'recyclable','4':'hand'}
        item['annotations']=[dict(category_id=c,bbox=[(cx-bw/2)*w,(cy-bh/2)*h,bw*w,bh*h]) for c,cx,cy,bw,bh in boxes]
        accepted.append(item)
    (out/'ledger.json').write_text(json.dumps(ledger,indent=2),encoding='utf8')
    (out/'candidates.json').write_text(json.dumps(accepted,indent=2),encoding='utf8')
    sheets(accepted,out,'overlay')
    print(dict(images=len(accepted),glass_boxes=sum(int(b[0])==1 for r in accepted for b in r['mapped_boxes']),
               hand_boxes=sum(int(b[0])==4 for r in accepted for b in r['mapped_boxes']),
               new_training_admission=0,active_experiments_modified=False),flush=True)


if __name__ == '__main__':
    main()
