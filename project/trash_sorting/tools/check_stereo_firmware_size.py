"""Build all stereo paths with opaque synthetic calibration. Never install/flash.

An asm memory output prevents LTO pruning the disabled/default calibration or
specializing the math for identity matrices. This is a RAM budget check only.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--gcc-prefix', required=True)
    a = p.parse_args()
    live='benchmark_run_pending' in (a.source_dir/'yolo/software/benchmark_ui.c').read_text(encoding='utf8')
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = out/'source'
    for name in ('software', 'model'):
        shutil.copytree(a.source_dir.resolve()/'yolo'/name, source/'yolo'/name)
    sw = source/'yolo/software'
    cal = sw/'stereo_calibration.h'
    cal.write_text(cal.read_text(encoding='utf8').replace(
        'static const stereo_calibration_t stereo_calibration',
        '/* STEREO_COMPILE_SIZE_ONLY: NEVER INSTALL. */\nstatic stereo_calibration_t stereo_calibration'), encoding='utf8')
    main_c = sw/'platform_main.c'
    text = main_c.read_text(encoding='utf8')
    marker = 'int main(void)\n{'
    if text.count(marker) != 1:
        raise ValueError('Cannot identify the main entry for isolated compile check')
    text = text.replace(marker, marker+'\n    __asm__ volatile("" : "+m"(stereo_calibration));')
    main_c.write_text(text, encoding='utf8')
    command = [sys.executable, str(Path(__file__).parent/'overnight/rebuild_firmware.py'),
        '--source-dir', str(source), '--out', str(out/'firmware'),
        '--gcc-prefix', a.gcc_prefix, '--classes', '5', '--cpu-hz', '54000000',
        '--benchmark' if live else '--benchmark-demo', '--media', '--stereo', '--lto', '--compact-scratch',
        '--size-opt', '--nano-libc']
    if live:command.append('--save-restore')
    subprocess.run(command, check=True)
    (out/'scope.json').write_text(json.dumps(dict(status='ALL_STEREO_PATHS_LINKED',
        synthetic_opaque_calibration=True, physical_distance_verified=False,
        install_allowed=False, pnr_performed=False, board_modified=False,
        command=command), indent=2), encoding='utf8')


if __name__ == '__main__':
    main()
