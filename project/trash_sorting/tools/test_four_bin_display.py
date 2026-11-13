"""Run display/DDR/OSD simulations only. Never invokes PDS or a downloader."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parents[1]
YOLO = PROJECT / 'source/yolo'
APP = PROJECT / 'source/extensions/business/application'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modelsim', type=Path, default=Path('D:/FPGA_Project/Modelism/win64'))
    parser.add_argument('--evidence', type=Path, default=ROOT / 'evidence/records/trash-display-20261111-001')
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)
    logs = []
    results = []
    with tempfile.TemporaryDirectory(prefix='trash_display_') as temporary:
        work = Path(temporary)

        def run(exe, *command):
            result = subprocess.run([str(args.modelsim / exe), *map(str, command)], cwd=work,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=180)
            logs.append(result.stdout)
            (args.evidence / 'simulation.log').write_text('\n'.join(logs), encoding='utf8')
            if result.returncode or re.search(r'\*\* (?:Fatal|Error):', result.stdout):
                raise RuntimeError(result.stdout)
            return result.stdout

        for name in ('ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex'):
            shutil.copy2(APP / 'assets' / name, work / name)
        image = Image.open(APP / 'assets/摄像头仿真输入.png').convert('RGB').resize((1280, 720), Image.Resampling.NEAREST)
        # Existing artificial camera fixture is visibly marked simulation input.
        with (work / 'native_camera.hex').open('w', encoding='ascii') as handle:
            for r, g, b in image.getdata():
                handle.write(f'{((r>>3)<<11)|((g>>2)<<5)|(b>>3):04x}\n')
        run('vlib.exe', 'work')
        sources = [
            YOLO / 'sources/048_camera_snapshot.v', YOLO / 'sources/049_video_ai_frontend.v',
            YOLO / 'sources/055_fram_buf.v', YOLO / 'sources/062_rd_buf.v',
            YOLO / 'sources/065_sync_vg.v', YOLO / 'portable/052_yolo_camera_top.v',
            APP / 'rtl/yolo_class_to_bin.v', APP / 'rtl/ui_light_panel.sv', APP / 'rtl/light_split_video.sv',
            YOLO / 'tb/tb_bbox_osd.v', YOLO / 'tb/tb_yolo_result_commit.v',
            YOLO / 'tb/tb_four_bin_colors.sv', YOLO / 'tb/tb_status_viewport.sv',
            YOLO / 'tb/tb_game_target_lock.sv',
            APP / 'rtl/result_event_cdc.sv', APP / 'rtl/trash_quiz_controller.sv',
            APP / 'tests/light_panel_tb.sv',
        ]
        run('vlog.exe', '-sv', *sources)
        cases = [
            ('tb_bbox_osd', [], 'BBOX_OSD_RTL_PASS'),
            ('tb_yolo_result_commit', [], 'TEST_PASS yolo_result_commit'),
            ('tb_four_bin_colors', ['-gFOUR=0'], 'TEST_PASS four_bin_colors'),
            ('tb_four_bin_colors', ['-gFOUR=1'], 'TEST_PASS four_bin_colors'),
            ('light_panel_tb', [], 'TEST_PASS light_panel'),
            ('tb_status_viewport', [], 'TEST_PASS status_viewport'),
            ('tb_game_target_lock', [], 'TEST_PASS game_target_lock'),
        ]
        for case, options, marker in cases:
            print('SIMULATE', case, *options, flush=True)
            output = run('vsim.exe', '-c', '-onfinish', 'exit', case, *options,
                         '-do', 'onerror {quit -code 1}; run -all; quit -code 0')
            if marker not in output:
                raise RuntimeError('Simulation did not report explicit pass: ' + output)
            message = next(line.strip('# ') for line in output.splitlines() if marker in line)
            print(message, flush=True)
            results.append(message)
        preview = ROOT / 'docs/verification/assets/trash-status48-rtl.png'
        preview.parent.mkdir(parents=True, exist_ok=True)
        Image.open(work / 'frame.ppm').save(preview)
        report = {
            'scope': 'source edits and RTL simulation only; no PDS, routing or download',
            'status': [0, 0, 1280, 48], 'viewport': [0, 48, 1280, 672],
            'camera_source': [0, 0, 1280, 720],
            'source_row': 'floor((screen_y-48)*719/671)',
            'tests': results, 'preview': str(preview.relative_to(ROOT)),
            'preview_kind': 'real RTL render of artificial camera fixture; manually injected box, not model inference',
            'sources': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in sources + [Path(__file__), APP / 'tools/light_ui_assets.py',
                                               *(APP / 'assets' / name for name in (
                                                   'ui_light_bg.hex', 'ui_light_palette.hex',
                                                   'ui_light_status.hex', 'ui_light_layout.json'))]},
            'unchanged_release_sha256': hashlib.sha256(
                (PROJECT / 'bitstream/full_27mhz/yolo_camera_top.sbit').read_bytes()).hexdigest(),
            'firmware_sha256': hashlib.sha256((YOLO / 'sources/firmware.bin').read_bytes()).hexdigest(),
            'trained_candidate_sha256': hashlib.sha256((PROJECT / 'training/candidates/four_bins_20261111/four_bins_yolov5n_320.pt').read_bytes()).hexdigest(),
        }
        (args.evidence / 'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    print('TEST_PASS display regressions; preview=', preview)


if __name__ == '__main__':
    main()
