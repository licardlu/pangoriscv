"""Render unadmitted, identity-eligible battery photos for complete manual boxes.

This creates review media only. It never changes a frozen training dataset.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


IDS = ['battery1', 'battery101', 'battery103', 'battery105', 'battery106',
       'battery11', 'battery111', 'battery112', 'battery12', 'battery127',
       'battery128', 'battery131', 'battery138', 'battery148', 'battery155',
       'battery40', 'battery74', 'battery75', 'battery76', 'battery89', 'battery98']


def main():
    root = Path('build/extras_battery_candidates_20261118_001')
    inventory = {r['id']: r for r in json.loads((root/'inventory.json').read_text())}
    prior = json.loads((root/'single_battery_review_ledger.json').read_text())
    out = root/'multi_review_001'
    out.mkdir(exist_ok=False)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)
    layout = {}
    for start in range(0, len(IDS), 6):
        sheet = Image.new('RGB', (1200, 1320), '#dddddd')
        for j, key in enumerate(IDS[start:start+6]):
            row = inventory[key]
            assert key not in prior
            assert row['admission'] == 'REQUIRES_VISUAL_AND_COMPLETE_BOX_REVIEW'
            image = Image.open(row['path']).convert('RGB')
            assert image.size == (row['width'], row['height'])
            scale = min(560/image.width, 360/image.height)
            image = image.resize((round(image.width*scale), round(image.height*scale)))
            x = (j % 2)*600 + (600-image.width)//2
            y = (j // 2)*440 + 40
            sheet.paste(image, (x, y))
            draw = ImageDraw.Draw(sheet)
            draw.text(((j % 2)*600+8, (j // 2)*440+8),
                      f'{key} / original {row["width"]} x {row["height"]}', font=font, fill='black')
            draw.rectangle((x, y, x+image.width-1, y+image.height-1), outline='#999999')
            layout[key] = dict(sheet=start//6+1, xywh=[x, y, image.width, image.height],
                               native_size=[row['width'], row['height']])
        sheet.save(out/f'review_{start//6+1:02}.jpg', quality=96)
    (out/'layout.json').write_text(json.dumps(layout, indent=2))
    print('Review-only images:', len(layout), flush=True)


if __name__ == '__main__':
    main()
