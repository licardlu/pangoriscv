"""Combined real control-path simulation; no synthesis, UART or board access."""
import argparse
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--snapshot', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    root = Path(__file__).resolve().parents[3]
    source, snapshot, out = a.source_dir.resolve(), a.snapshot.resolve(), a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inventory = json.loads((snapshot/'source_sha256.json').read_text(encoding='utf8'))
    current = {str(f.relative_to(source)).replace('\\', '/'): hashlib.sha256(f.read_bytes()).hexdigest()
               for f in source.rglob('*') if f.is_file() and '__pycache__' not in f.parts}
    if current != inventory:
        raise RuntimeError('Source differs from the specified frozen snapshot')
    rtl = source/'extensions/business/application/rtl'
    for f in (rtl.parent/'assets/audio_rom').glob('voice_pcm8.hex*'):
        shutil.copy2(f, out/f.name)
    files = [rtl/n for n in ('benchmark_key_router.sv', 'key_debounce4.sv',
             'trash_peripherals.sv', 'trash_quiz_controller.sv', 'servo_pwm4.sv',
             'trash_voice_i2s.v', 'trash_voice_rom_player.v', 'trash_i2s_tx.v', 'benchmark_page.sv')]
    files += [source/'extensions/media/media_page_router.sv',
              root/'project/trash_sorting/tests/tb_feedback_session_boundary.sv']
    sim = Path('D:/FPGA_Project/Modelism/win64')
    commands = []
    def run(name, *args):
        command = [str(sim/name), *map(str, args)]
        commands.append(command)
        r = subprocess.run(command, cwd=out, capture_output=True, text=True, timeout=120)
        with (out/'checks.log').open('a', encoding='utf8') as f:
            f.write(r.stdout+r.stderr)
        r.check_returncode()
        if '** Error' in r.stdout+r.stderr or '** Fatal' in r.stdout+r.stderr:
            raise RuntimeError(r.stdout+r.stderr)
        return r.stdout+r.stderr
    run('vlib.exe', 'work')
    run('vlog.exe', '-sv', *files)
    cases = [dict(CPU_HALF=5, PIX_HALF=7, CPU_OFFSET=0),
             dict(CPU_HALF=13, PIX_HALF=13, CPU_OFFSET=3),
             dict(CPU_HALF=3, PIX_HALF=5, CPU_OFFSET=2)]
    for case in cases:
        output = run('vsim.exe', '-c', 'tb_feedback_session_boundary',
                     *(f'-g{k}={v}' for k, v in case.items()), '-do',
                     'onerror {quit -code 1}; run -all; quit -code 0')
        if 'TEST_PASS feedback session boundary' not in output:
            raise RuntimeError(output)
    for name, expected in current.items():
        if hashlib.sha256((source/name).read_bytes()).hexdigest() != expected:
            raise RuntimeError('Source changed during simulation: '+name)
    result = dict(status='FEEDBACK_SESSION_BOUNDARY_PASS', created_utc=datetime.now(timezone.utc).isoformat(),
                  source_snapshot=str(snapshot), snapshot_files_verified=len(current),
                  source_unchanged=True, pnr_performed=False, board_modified=False,
                  limits=['Accelerated clocks/debounce/frame cadence; not physical timing or audio quality.',
                          'No CPU workload runs here; CPU safe-point behavior has separate host evidence.'],
                  cases=cases, commands=commands,
                  runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  files={str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in files})
    (out/'result.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print('TEST_PASS feedback session boundary; frozen source unchanged', flush=True)


if __name__ == '__main__':
    main()
