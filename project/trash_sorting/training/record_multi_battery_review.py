"""Record complete visible-instance boxes manually inspected on four sheets.

Coordinates below refer to prepare_multi_battery_review.py review images.
Output is an annotation candidate, not an admission to an in-flight experiment.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BOXES = {
    'battery1': [(66,98,508,235), (72,221,530,355)],
    'battery101': [(700,74,910,224), (936,88,1080,217), (739,221,919,345)],
    'battery103': [(88,521,438,650), (114,575,517,785)],
    'battery105': [(819,481,891,613), (905,503,961,613), (974,503,1007,609), (1019,517,1042,609)],
    'battery106': [(191,983,267,1110), (301,1004,354,1108), (396,1007,426,1105),
                   (163,1122,290,1220), (294,1140,391,1215), (392,1150,442,1208)],
    'battery11': [(729,968,823,1247), (813,968,907,1247), (900,968,988,1247), (983,968,1073,1247)],
    'battery111': [(66,249,189,326), (138,150,240,317), (234,227,299,352),
                   (264,66,364,307), (376,182,475,301), (378,252,542,338)],
    'battery112': [(654,151,893,381), (740,121,982,337), (818,92,1073,295), (893,65,1149,252)],
    'battery12': [(214,564,271,761), (231,697,432,779)],
    'battery127': [(819,559,900,737), (846,646,1026,758)],
    'battery128': [(132,956,394,1133), (155,1057,485,1207)],
    'battery131': [(721,927,904,1272), (889,927,1079,1275)],
    'battery138': [(210,127,274,337), (327,184,375,341)],
    'battery148': [(717,118,826,332), (813,57,952,309), (943,113,1061,305),
                   (759,299,909,355), (893,279,1097,362)],
    'battery155': [(88,515,145,709), (167,533,263,714), (289,564,333,710),
                   (366,579,398,709), (415,605,467,705), (481,625,527,702)],
    'battery40': [(749,497,878,808), (869,497,994,810), (974,497,1111,821)],
    'battery74': [(38,952,124,1250), (181,950,270,1250), (338,952,425,1251), (488,955,569,1249)],
    'battery75': [(848,952,992,1003), (942,1018,1084,1098), (752,1024,897,1104),
                  (890,1094,1038,1148), (716,1103,858,1207), (832,1189,983,1250)],
    'battery76': [(170,40,516,249), (77,73,428,306)],
    'battery89': [(720,157,907,279), (779,164,969,286), (842,170,1035,291), (909,174,1108,295)],
    'battery98': [(124,525,208,810), (195,724,478,820)],
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    root = Path('build/extras_battery_candidates_20261118_001')
    review = root/'multi_review_001'
    layout = json.loads((review/'layout.json').read_text())
    inventory = {r['id']: r for r in json.loads((root/'inventory.json').read_text())}
    assert set(layout) == set(BOXES)
    out = review/'annotated_001'
    out.mkdir(exist_ok=False)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)
    ledger = {}
    for key, rectangles in BOXES.items():
        row = inventory[key]
        assert sha(row['path']) == row['image_sha256']
        assert row['admission'] == 'REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW'
        x, y, dw, dh = layout[key]['xywh']
        w, h = row['width'], row['height']
        boxes = []
        image = Image.open(row['path']).convert('RGB')
        image = image.resize((w*3, h*3))
        draw = ImageDraw.Draw(image)
        for n, (x1, y1, x2, y2) in enumerate(rectangles):
            # A boundary touched by a cropped object stays at the image edge.
            assert x-1 <= x1 < x2 <= x+dw+1 and y-1 <= y1 < y2 <= y+dh+1, key
            native = [max(0, (x1-x)*w/dw), max(0, (y1-y)*h/dh),
                      min(w, (x2-x)*w/dw), min(h, (y2-y)*h/dh)]
            a,b,c,d = native
            boxes.append([2, (a+c)/2/w, (b+d)/2/h, (c-a)/w, (d-b)/h])
            draw.rectangle(tuple(v*3 for v in native), outline='red', width=2)
            draw.text((a*3, b*3), f'battery {n+1}', font=font, fill='red')
        image.save(out/(key+'.jpg'), quality=96)
        ledger[key] = dict(status='COMPLETE_BOXES_REVIEWED_PENDING_OVERLAY_CHECK',
            reviewer='assistant_visual', source_sha256=row['image_sha256'],
            source_file=row['source_file'], source_url='https://www.kaggle.com/datasets/shettysharanyaa/extras',
            boxes=boxes, review_sheet=layout[key]['sheet'], display_xyxy=rectangles,
            complete_visible_batteries=len(boxes), visible_hands=0,
            note='Visible-instance boxes; shadows and duplicate reflected objects excluded. All images from this source stay train only. Product pictures/renderings are not new camera captures.')
    (out/'ledger.json').write_text(json.dumps(ledger, indent=2))
    print('Images:', len(ledger), 'boxes:', sum(len(r['boxes']) for r in ledger.values()), flush=True)


if __name__ == '__main__':
    main()
