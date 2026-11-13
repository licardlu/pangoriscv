"""Render manually placed hand/subject boxes for visual review, never pseudo-label."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inventory', type=Path, required=True)
    p.add_argument('--selected', type=Path, required=True)
    p.add_argument('--manual', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    inv = json.loads(a.inventory.read_text(encoding='utf8'))['images']
    groups = json.loads(a.selected.read_text(encoding='utf8'))['groups']
    manual = json.loads(a.manual.read_text(encoding='utf8'))
    if manual['status'] != 'MANUAL_DRAFT_OVERLAY_REVIEW_REQUIRED':
        raise ValueError('Expected manual draft, not model predictions')
    ids = [i for v in groups.values() for i in v]
    if len(ids) != len(set(ids)) or set(map(str, ids)) != set(manual['boxes']) | set(manual['excluded']):
        raise ValueError('Selected ids must have exactly one draft or exclusion')
    if set(manual['boxes']) & set(manual['excluded']):
        raise ValueError('Image both labelled and excluded')
    a.out.mkdir(parents=True, exist_ok=False)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 19)
    bins = dict(pear=0, used_tissue=3, empty_hand=None, banana_peel=0,
                plastic_food_container=1, glass_food_jar=1, latch_glass_jar=1, cardboard_box=1)
    aliases = dict(latch_glass_jar='glass_latch_jar', plastic_food_container='plastic_food_box')
    rows, tiles = [], []
    for group, selected in groups.items():
        for idx in selected:
            row = dict(inv[idx-1])
            if row['id'] != idx or sha(Path(row['path'])) != row['sha256']:
                raise ValueError('Source image identity changed')
            row.update(group=aliases.get(group, group), bin=bins[group],
                       split='val' if group in ('banana_peel', 'glass_food_jar', 'cardboard_box') else 'train')
            if str(idx) in manual['excluded']:
                row.update(status='EXCLUDED', reason=manual['excluded'][str(idx)])
                rows.append(row)
                continue
            obj, hand = manual['boxes'][str(idx)]
            if (obj is None) != (group == 'empty_hand'):
                raise ValueError('Empty-hand scene must have no subject box')
            for box in (obj, hand):
                if box is not None and not (len(box) == 4 and 0 <= box[0] < box[2] <= 1 and 0 <= box[1] < box[3] <= 1):
                    raise ValueError('Invalid manual xyxy')
            with Image.open(row['path']) as raw:
                im = ImageOps.exif_transpose(raw).convert('RGB')
                if list(im.size) != row['display_size']:
                    raise ValueError('EXIF orientation/size changed')
                im.thumbnail((384, 512))
            d = ImageDraw.Draw(im)
            for box, label, color in ((obj, 'subject', ['#00ff00', '#2070ff', '#ff2020', '#aaaaaa'][bins[group]] if obj else ''),
                                      (hand, 'hand', '#00ffff')):
                if box:
                    xy = (box[0]*im.width, box[1]*im.height, box[2]*im.width-1, box[3]*im.height-1)
                    d.rectangle(xy, outline=color, width=3)
                    d.text((xy[0]+3, xy[1]+3), label, font=font, fill='black', stroke_width=1, stroke_fill=color)
            tile = Image.new('RGB', (400, 552), 'white')
            tile.paste(im, ((400-im.width)//2, 0))
            ImageDraw.Draw(tile).text((8, 516), f'N{idx:03d} {group} {row["split"]}', font=font, fill='black')
            tiles.append(tile)
            row.update(status='DRAFT_OVERLAY_REVIEW_PENDING', hand_xyxy=hand, object_xyxy=obj,
                       relation='empty hand; no held subject' if obj is None else 'hand_0 holds object_0',
                       box_source='Manually placed from EXIF-oriented numbered detail sheet; no model predictions',
                       annotation_scope='palm/fingers through wrist and held subject; background waste not exhaustively labelled')
            rows.append(row)
    files = []
    for start in range(0, len(tiles), 6):
        sheet = Image.new('RGB', (1200, 1104), 'white')
        for n, tile in enumerate(tiles[start:start+6]):
            sheet.paste(tile, ((n % 3)*400, (n // 3)*552))
        file = a.out/f'overlay_{start//6+1:02d}.jpg'
        sheet.save(file, quality=97)
        files.append(dict(path=str(file.resolve()), sha256=sha(file)))
    report = dict(status='DRAFT_OVERLAY_REVIEW_PENDING', inventory_sha256=sha(a.inventory),
                  manual_sha256=sha(a.manual), images=rows, overlays=files,
                  coordinate_system='EXIF-oriented normalized xyxy', battery_test_used=False,
                  source_photos_modified=False, training_started=False)
    (a.out/'labels_draft.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print('DRAFT_OVERLAYS_READY', len(tiles), len(files))


if __name__ == '__main__':
    main()
