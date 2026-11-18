"""Generate fixed-size standby font and labels for the candidate only."""
import argparse
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

LINES=['互动待机','STANDBY / TF MEDIA','识别暂停动画待机','内置波动动画',
       '单击开始识别','单击开始识别，双击切页','KEY0 单击启停识别 / 双击切换页面']
def main():
    p=argparse.ArgumentParser();p.add_argument('--source-dir',type=Path,required=True);a=p.parse_args()
    out=a.source_dir/'yolo/sources'
    chars=' '+''.join(dict.fromkeys(''.join(LINES).replace(' ','')))
    assert len(chars)<=128 and all(len(line)<=40 for line in LINES)
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14);words=[]
    for ch in chars:
        im=Image.new('1',(16,16));d=ImageDraw.Draw(im)
        b=d.textbbox((0,0),ch,font=font)
        d.text(((16-(b[2]-b[0]))//2-b[0],1-b[1]),ch,font=font,fill=1)
        words.extend(sum(int(bool(im.getpixel((x,y))))<<(15-x) for x in range(16)) for y in range(16))
    words += [0]*(2048-len(words))
    (out/'media_font.hex').write_text(''.join(f'{v:04x}\n' for v in words),encoding='ascii')
    cells=[chars.index(c) for line in LINES for c in line.ljust(40)];cells += [0]*(512-len(cells))
    (out/'media_labels.hex').write_text(''.join(f'{v:02x}\n' for v in cells),encoding='ascii')
    print(f'MEDIA_ASSETS_PASS glyphs={len(chars)} font_words={len(words)} label_words={len(cells)}')
if __name__=='__main__':main()
