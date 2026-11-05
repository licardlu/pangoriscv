"""Run the dedicated synthesizable points/audio-panel pixel checks."""
from pathlib import Path
import shutil
import subprocess
import sys
import os

root = Path(__file__).resolve().parents[1]
case = 'ui_points_audio_frame' if '--frame' in sys.argv else 'ui_points_audio'
build = root / ('build/sim_' + case)
build.mkdir(parents=True, exist_ok=True)
for name in ('ui_bg.hex', 'ui_palette.hex', 'ui_status.hex', 'ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex'):
    shutil.copy2(root / 'assets' / name, build / name)
bin_dir = Path(os.environ.get('MODELSIM_BIN', os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64')))
commands = [
    ('vlib.exe', ['work']),
    ('vlog.exe', ['-sv', '+incdir+' + str(root / 'rtl'),
                  *[str(root / name) for name in ('rtl/vision_overlay.sv', 'rtl/bcd32.sv', 'rtl/ui_light_panel.sv',
                                                 'rtl/ui_rgb.sv', 'tests/' + case + '_tb.sv')]]),
    ('vsim.exe', ['-c', '-onfinish', 'exit', case + '_tb', '-do',
                  'onerror {quit -code 1}; run -all; quit -code 0']),
]
logs = []
for exe, args in commands:
    result = subprocess.run([str(bin_dir / exe), *args], cwd=build, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    logs.append(result.stdout)
    if result.returncode:
        break
log = '\n'.join(logs)
(root / 'evidence').mkdir(exist_ok=True)
(root / ('evidence/' + case + '_sim.log')).write_text(log, encoding='utf-8')
print(log[-4500:])
sys.exit(0 if result.returncode == 0 and 'TEST_PASS ' + case in log
         and '** Fatal:' not in log else 1)
