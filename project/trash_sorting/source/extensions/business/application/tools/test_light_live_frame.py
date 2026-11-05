"""Render and check the real frontend + native split-video path, without PnR."""
import os
from pathlib import Path
import argparse
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--baseline-root', type=Path)
p.add_argument('--frontend', type=Path, help='use a frozen custom video_ai_frontend RTL')
p.add_argument('--modelsim', type=Path, default=Path(os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64')))
p.add_argument('--no-result', action='store_true', help='render with no recognition result; verify no default guide')
a = p.parse_args()
candidates = [ROOT.parents[2] / 'yolo', ROOT.parents[1] / 'incoming_pre_pnr_20261103_002112/pre_pnr_source_20261103_002112']
baseline = a.baseline_root or next((d for d in candidates if (d / 'sources/049_video_ai_frontend.v').exists()), None)
if baseline is None:
    p.error('use --baseline-root to select the supplied YOLO source folder')
b = ROOT / ('build/sim_light_live_frame_no_result' if a.no_result else 'build/sim_light_live_frame')
b.mkdir(parents=True, exist_ok=True)
for name in ('ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex'):
    shutil.copy2(ROOT / 'assets' / name, b / name)
im = Image.open(ROOT / 'assets/摄像头仿真输入.png').convert('RGB').resize((1280, 720), Image.Resampling.LANCZOS)
draw = ImageDraw.Draw(im)
draw.rectangle((0, 0, 1279, 111), fill=(234, 242, 238))
draw.text((1000, 678), '仿真输入 · 非实拍', font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22), fill=(66, 103, 90))
with (b / 'native_camera.hex').open('w', encoding='ascii') as f:
    pixels = im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()
    for r, g, blue in pixels:
        f.write(f'{((r >> 3) << 11) | ((g >> 2) << 5) | (blue >> 3):04x}\n')
frontend = a.frontend or (baseline / 'sources/049_video_ai_frontend.v')
files = [baseline / 'sources/048_camera_snapshot.v', frontend,
         ROOT / 'rtl/bcd32.sv', ROOT / 'rtl/ui_light_panel.sv', ROOT / 'rtl/light_split_video.sv',
         ROOT / 'tests/light_live_frame_tb.sv']
logs = []
for exe, args in [('vlib.exe', ['work']), ('vlog.exe', ['-sv', '+incdir+' + str(ROOT / 'rtl'), *map(str, files)]),
                  ('vsim.exe', ['-c', '-onfinish', 'exit', 'light_live_frame_tb', '-gHAS_RESULT=' + ('0' if a.no_result else '1'), '-do', 'onerror {quit -code 1}; run -all; quit -code 0'])]:
    result = subprocess.run([str(a.modelsim / exe), *args], cwd=b, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    logs.append(result.stdout)
    if result.returncode:
        break
log = '\n'.join(logs)
(ROOT / 'evidence').mkdir(exist_ok=True)
(ROOT / ('evidence/light_live_frame_no_result_sim.log' if a.no_result else 'evidence/light_live_frame_sim.log')).write_text(log, encoding='utf-8')
print(log[-4500:])
if result.returncode or 'TEST_PASS' not in log or '** Fatal:' in log:
    raise SystemExit(1)
if not a.no_result:
    rendered = Image.open(b / 'frame.ppm').convert('RGB')
    tag = rendered.crop((50,68,178,100))
    pixels = list(tag.getdata())
    solid = sum(1 for r,g,blue in pixels if r < 45 and g < 100 and blue < 90)
    white = sum(1 for r,g,blue in pixels if r > 240 and g > 240 and blue > 240)
    if solid < 3000 or white < 80:
        raise SystemExit(f'Chinese opaque label missing/too small: dark={solid}, white={white}')
    print(f'TEST_PASS chinese bbox label opaque background={solid} white glyph pixels={white}')
out = ROOT / ('assets/白色布局_无识别框_RTL仿真.png' if a.no_result else 'assets/白色布局_实时视频链路_RTL仿真.png')
Image.open(b / 'frame.ppm').save(out)
print('RTL_FRAME_READY', out)
