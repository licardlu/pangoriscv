"""RTL-only checks. Never launches PDS, P&R, programming or serial access."""
import os
from pathlib import Path
import argparse
import subprocess

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--modelsim', default=os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64'))
a = p.parse_args()
cases = {
    'servo_key_controller': ['servo_pwm4.sv', 'key_debounce4.sv', 'servo_key_controller.sv'],
    'trash_audio_select': ['trash_audio_select.v'],
    'trash_quiz_controller': ['trash_quiz_controller.sv'],
    'trash_peripherals': ['key_debounce4.sv', 'trash_quiz_controller.sv', 'servo_pwm4.sv', 'trash_peripherals.sv'],
    'ms7210_audio_init': ['ms7210_audio_init.v'],
    'ms72xx_audio_chain': ['ms7210_audio_init.v'],
}
for name, files in cases.items():
    build = root / 'build' / ('sim_' + name)
    build.mkdir(parents=True, exist_ok=True)
    test = root / 'tests' / (name + '_tb.sv')
    if not test.exists():
        test = test.with_suffix('.v')
    sources = [str(root/'rtl'/f) for f in files]
    if name == 'ms72xx_audio_chain':
        sources += [str(root.parents[2]/'yolo/sources/060_ms72xx_ctl.v')]
    commands = [
        ('vlib.exe', ['work']),
        ('vlog.exe', ['-sv', *sources, str(test)]),
        ('vsim.exe', ['-c', '-onfinish', 'exit', name + '_tb', '-do',
                      'onerror {quit -code 1}; run -all; quit -code 0']),
    ]
    logs = []
    for exe, args in commands:
        r = subprocess.run([str(Path(a.modelsim)/exe), *args], cwd=build,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        logs.append(r.stdout)
        if r.returncode:
            print(r.stdout)
            raise SystemExit(r.returncode)
    log = '\n'.join(logs)
    (root/'evidence').mkdir(exist_ok=True)
    (root/'evidence'/(name+'_sim.log')).write_text(log, encoding='utf-8')
    # Positive completion marker is mandatory; a zero simulator exit isn't proof.
    marker = 'PASS: keys 1..4' if name == 'trash_audio_select' else 'TEST_PASS ' + name
    if marker not in log or '** Fatal:' in log or '** Error:' in log:
        print(log)
        raise SystemExit(1)
    print('PASS ' + name)
