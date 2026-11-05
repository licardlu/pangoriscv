"""Bright left-half UI artwork; 640x360 packed 4bpp ROM, displayed at 2x.

The right 640x720 physical half is a uniform placeholder for the camera RTL.
No existing ui_bg/ui_palette/ui_status assets are overwritten.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets'
FONT = 'C:/Windows/Fonts/msyh.ttc'
COLORS = ['f4f8f6', 'ffffff', '17483f', '52756b', '158263', 'e4f1eb',
          'd0e4da', 'edf3f3', '397eb5', 'e8f2fb', 'dc6979', 'fceef0',
          'c99a35', 'fff4d8', '8ba49b', 'bfd3ca']
PALETTE = ['#' + value for value in COLORS]
LAYOUT = {
    'screen': [1280, 720], 'camera': [640, 0, 640, 720],
    'points_card': [32, 104, 576, 72], 'points_digits': [320, 112, 280, 48],
    'auto': [32, 192, 280, 32], 'quiz': [328, 192, 280, 32],
    'bins': [[32, 240, 280, 100], [328, 240, 280, 100],
             [32, 356, 280, 100], [328, 356, 280, 100]],
    'status_card': [32, 488, 576, 60], 'status_text': [52, 510, 556, 24],
    'music_card': [32, 574, 576, 106], 'music_state': [420, 630, 172, 24],
    'status_rom': {'width': 360, 'row_height': 24, 'states': 9,
                   'text_area': [0, 0, 278, 12], 'words_per_state': 1080},
}
STATUS = ['等待放入一件垃圾', '请按板载按键 1 至 4 选择分类',
          '请根据识别结果投放垃圾', '请移走垃圾，开始下一轮',
          '音乐准备中，请稍候', '正在通过外接音箱播放',
          '设备异常，请检查设备', '回答正确，自动播放音乐',
          '回答错误，请再接再厉']

def font(size):
    return ImageFont.truetype(FONT, size)

def text(draw, x, y, value, physical_size, color=2):
    """Place by the top of actual glyph ink, using physical pixel positions."""
    f = font(physical_size // 2)
    bounds = draw.textbbox((0, 0), value, font=f)
    draw.text((x // 2, y // 2 - bounds[1]), value, font=f, fill=PALETTE[color])

def rect(draw, box, fill, radius=16):
    x, y, w, h = box
    draw.rounded_rectangle((x // 2, y // 2, (x + w) // 2 - 1, (y + h) // 2 - 1),
                           radius // 2, fill=PALETTE[fill])

def indexed(image):
    pal = Image.new('P', (1, 1))
    flat = []
    for color in COLORS:
        flat.extend(bytes.fromhex(color))
    pal.putpalette(flat + [0] * (768 - len(flat)))
    return image.quantize(palette=pal, dither=Image.Dither.NONE)

def emit(image, path):
    pixels = indexed(image).tobytes()
    assert len(pixels) % 8 == 0
    path.write_text(''.join(f'{sum(pixels[i+k] << (4*k) for k in range(8)):08x}\n'
                            for i in range(0, len(pixels), 8)), encoding='ascii')

def main():
    OUT.mkdir(exist_ok=True)
    image = Image.new('RGB', (640, 360), PALETTE[7])
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 319, 359), fill=PALETTE[0])
    text(draw, 32, 28, '青禾 · 垃圾分类', 32)
    text(draw, 32, 74, '看见绿色，让每一次选择都有意义', 18, 3)
    rect(draw, LAYOUT['points_card'], 1)
    text(draw, 52, 118, '本机积分', 24)
    text(draw, 52, 150, '绿色行动，点滴积累', 16, 3)
    rect(draw, LAYOUT['auto'], 5, 12)
    rect(draw, LAYOUT['quiz'], 5, 12)
    text(draw, 120, 200, '自动识别', 20, 4)
    text(draw, 416, 200, '分类答题', 20, 4)
    names = ['可回收物', '厨余垃圾', '有害垃圾', '其他垃圾']
    ink = [8, 4, 10, 12]
    tint = [9, 5, 11, 13]
    for i, (box, name) in enumerate(zip(LAYOUT['bins'], names)):
        x, y, _, _ = box
        rect(draw, box, 1)
        rect(draw, [x + 20, y + 22, 46, 54], tint[i], 10)
        # A small bin pictogram, drawn in the 640x360 artwork grid.
        bx, by = (x + 30) // 2, (y + 34) // 2
        draw.rectangle((bx, by, bx + 12, by + 15), fill=PALETTE[ink[i]])
        draw.rectangle((bx - 2, by - 3, bx + 14, by - 1), fill=PALETTE[ink[i]])
        draw.rectangle((bx + 4, by - 5, bx + 8, by - 4), fill=PALETTE[ink[i]])
        draw.line((bx + 4, by + 3, bx + 4, by + 12), fill=PALETTE[1])
        draw.line((bx + 8, by + 3, bx + 8, by + 12), fill=PALETTE[1])
        text(draw, x + 86, y + 24, name, 26)
        text(draw, x + 88, y + 62, f'板载按键 {i + 1}', 18, 3)
    rect(draw, LAYOUT['status_card'], 5)
    text(draw, 52, 490, '当前状态', 16, 3)
    rect(draw, LAYOUT['music_card'], 1)
    text(draw, 52, 590, '答题音乐奖励', 22)
    text(draw, 52, 626, '晨光小径', 26, 4)
    text(draw, 52, 660, '外接音箱播放', 16, 3)
    text(draw, 32, 696, '看清一件垃圾，再选择分类', 18, 3)
    emit(image, OUT / 'ui_light_bg.hex')
    (OUT / 'ui_light_palette.hex').write_text('\n'.join(COLORS) + '\n', encoding='ascii')
    sprites = Image.new('RGB', (360, 24 * len(STATUS)), PALETTE[5])
    sd = ImageDraw.Draw(sprites)
    for i, value in enumerate(STATUS):
        f = font(11)
        bounds = sd.textbbox((0, 0), value, font=f)
        assert bounds[2] <= 278 and bounds[3] - bounds[1] <= 12, (value, bounds)
        sd.text((0, i * 24 - bounds[1]), value, font=f,
                fill=PALETTE[10 if i == 6 else 4])
    emit(sprites, OUT / 'ui_light_status.hex')
    preview = indexed(image).convert('RGB').resize((1280, 720), Image.Resampling.NEAREST)
    preview.save(OUT / 'ui_light_preview.png')
    preview.crop((0, 0, 640, 720)).save(OUT / 'ui_light_left.png')
    (OUT / 'ui_light_layout.json').write_text(json.dumps(LAYOUT, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('LIGHT_UI_ASSETS_PASS left=640x720 right=blank ROM=640x360x4bpp')

if __name__ == '__main__':
    main()
