"""Compact 1280x112 header at 2x; lower 1280x608 belongs to live video."""
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
    'screen': [1280, 720], 'header': [0, 0, 1280, 112],
    'camera': [0, 112, 1280, 608], 'camera_source': [0, 112, 1280, 608],
    'title': [32, 20], 'tagline': [32, 66],
    'status_card': [640, 20, 608, 72], 'status_text': [660, 56, 556, 24],
    'background_rom': {'width': 640, 'height': 56, 'words': 4480},
    'status_rom': {'width': 360, 'row_height': 12, 'states': 9,
                   'text_area': [0, 0, 278, 12], 'words_per_state': 540},
}
STATUS = ['等待放入一件垃圾', '请按键：1绿厨余 2红有害 3灰其他 4蓝回收',
          '请根据识别结果投放垃圾', '请移走垃圾，开始下一轮',
          '音乐准备中，请稍候', '正在通过外接音箱播放',
          '设备异常，请检查设备', '回答正确，桶盖已打开',
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
    image = Image.new('RGB', (640, 56), PALETTE[0])
    draw = ImageDraw.Draw(image)
    text(draw, 32, 20, '青禾 · 垃圾分类', 32)
    text(draw, 32, 66, '看见绿色，让每一次选择都有意义', 18, 3)
    rect(draw, LAYOUT['status_card'], 5)
    text(draw, 660, 30, '当前状态', 16, 3)
    emit(image, OUT / 'ui_light_bg.hex')
    (OUT / 'ui_light_palette.hex').write_text('\n'.join(COLORS) + '\n', encoding='ascii')
    sprites = Image.new('RGB', (360, 12 * len(STATUS)), PALETTE[5])
    sd = ImageDraw.Draw(sprites)
    for i, value in enumerate(STATUS):
        f = font(11)
        bounds = sd.textbbox((0, 0), value, font=f)
        assert bounds[2] <= 278 and bounds[3] - bounds[1] <= 12, (value, bounds)
        sd.text((0, i * 12 - bounds[1]), value, font=f,
                fill=PALETTE[10 if i == 6 else 4])
    emit(sprites, OUT / 'ui_light_status.hex')
    preview = Image.new('RGB', (1280, 720), PALETTE[7])
    preview.paste(indexed(image).convert('RGB').resize((1280, 112), Image.Resampling.NEAREST), (0, 0))
    prompt = indexed(sprites).convert('RGB').crop((0, 12, 278, 24))
    preview.paste(prompt.resize((556, 24), Image.Resampling.NEAREST), (660, 56))
    preview.save(OUT / 'ui_light_preview.png')
    preview.crop((0, 0, 1280, 112)).save(OUT / 'ui_light_header.png')
    (OUT / 'ui_light_layout.json').write_text(json.dumps(LAYOUT, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('LIGHT_UI_ASSETS_PASS header=1280x112 camera=1280x608 ROM=640x56x4bpp')

if __name__ == '__main__':
    main()
