"""Render and check the real frontend + native split-video path, without PnR."""
from pathlib import Path
import argparse
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--baseline-root', type=Path)
p.add_argument('--modelsim', type=Path, default=Path('D:/modeltech64_10.6e/win64'))
a = p.parse_args()
candidates = [ROOT.parents[2] / 'yolo', ROOT.parents[1] / 'incoming_pre_pnr_20261103_002112/pre_pnr_source_20261103_002112']
baseline = a.baseline_root or next((d for d in candidates if (d / 'sources/049_video_ai_frontend.v').exists()), None)
if baseline is None:
    p.error('use --baseline-root to select the supplied YOLO source folder')
b = ROOT / 'build/sim_light_live_frame'
b.mkdir(parents=True, exist_ok=True)
for name in ('ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex'):
    shutil.copy2(ROOT / 'assets' / name, b / name)
im = Image.open(ROOT / 'assets/摄像头仿真输入.png').convert('RGB').resize((1280, 720), Image.Resampling.LANCZOS)
draw = ImageDraw.Draw(im)
draw.rectangle((0, 0, 1279, 90), fill=(234, 242, 238))
draw.text((340, 20), '仿真输入 · 非实拍', font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22), fill=(66, 103, 90))
with (b / 'native_camera.hex').open('w', encoding='ascii') as f:
    pixels = im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata()
    for r, g, blue in pixels:
        f.write(f'{((r >> 3) << 11) | ((g >> 2) << 5) | (blue >> 3):04x}\n')
files = [baseline / 'sources/048_camera_snapshot.v', baseline / 'sources/049_video_ai_frontend.v',
         ROOT / 'rtl/bcd32.sv', ROOT / 'rtl/ui_light_panel.sv', ROOT / 'rtl/light_split_video.sv',
         ROOT / 'tests/light_live_frame_tb.sv']
logs = []
for exe, args in [('vlib.exe', ['work']), ('vlog.exe', ['-sv', '+incdir+' + str(ROOT / 'rtl'), *map(str, files)]),
                  ('vsim.exe', ['-c', '-onfinish', 'exit', 'light_live_frame_tb', '-do', 'onerror {quit -code 1}; run -all; quit -code 0'])]:
    result = subprocess.run([str(a.modelsim / exe), *args], cwd=b, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    logs.append(result.stdout)
    if result.returncode:
        break
log = '\n'.join(logs)
(ROOT / 'evidence').mkdir(exist_ok=True)
(ROOT / 'evidence/light_live_frame_sim.log').write_text(log, encoding='utf-8')
print(log[-4500:])
if result.returncode or 'TEST_PASS light_live_frame' not in log or '** Fatal:' in log:
    raise SystemExit(1)
out = ROOT / 'assets/白色布局_实时视频链路_RTL仿真.png'
Image.open(b / 'frame.ppm').save(out)
print('RTL_FRAME_READY', out)
