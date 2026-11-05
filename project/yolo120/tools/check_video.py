"""Check the supplied white UI compositor with the canonical YOLO frontend.

Synthetic video verification only. This does not program a board or attest HDMI.
"""
import argparse
from pathlib import Path
import shutil
import subprocess

from build import PROJECT, REPO, sha, tool_config, write_json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--evidence', type=Path, required=True)
    p.add_argument('--modelsim', type=Path)
    a = p.parse_args()
    out = a.out.resolve()
    if not out.is_relative_to(PROJECT/'build'):
        p.error('Output must be inside project/yolo120/build')
    tools = a.modelsim or Path(tool_config()['modelsim'])
    app = REPO/'extensions/ui_reference/extensions/business/application'
    out.mkdir(parents=True, exist_ok=False)
    a.evidence.mkdir(parents=True, exist_ok=False)
    from PIL import Image
    scene = Image.open(app/'assets/摄像头仿真输入.png').convert('RGB').resize((1280, 720))
    with (out/'native_camera.hex').open('w', encoding='ascii') as f:
        pixels = scene.get_flattened_data() if hasattr(scene, 'get_flattened_data') else scene.getdata()
        for r, g, b in pixels:
            f.write(f'{((r>>3)<<11)|((g>>2)<<5)|(b>>3):04x}\n')
    for name in ('ui_light_bg.hex', 'ui_light_palette.hex', 'ui_light_status.hex'):
        shutil.copy2(app/'assets'/name, out/name)
    frontend = PROJECT/'rtl/video_ai_frontend.v'
    capture = REPO/'extensions/yolo/rtl/camera_snapshot.v'
    common = [app/'rtl/light_split_video.sv']
    cases = [
        ('split', app/'tests/light_split_video_tb.sv', common,
         'TEST_PASS light_split_video'),
        ('frame', app/'tests/light_live_frame_tb.sv',
         [frontend, capture, app/'rtl/bcd32.sv', app/'rtl/ui_light_panel.sv', *common],
         'TEST_PASS light_live_frame')]
    records = []
    for name, tb, sources, marker in cases:
        folder = out/name
        folder.mkdir()
        for asset in out.glob('*.hex'):
            shutil.copy2(asset, folder/asset.name)
        text = tb.read_text(encoding='utf-8')
        if name == 'frame':
            text = text.replace('.wr_en(wr),', '.wr_en(wr),.rd_en(1\'b0),')
        staged_tb = folder/tb.name
        staged_tb.write_text(text, encoding='utf-8')
        commands = [[tools/'vlib.exe', 'work'],
            [tools/'vlog.exe', '-sv', '+incdir+'+str(app/'rtl'), staged_tb, *sources],
            [tools/'vsim.exe', '-c', '-quiet', '-onfinish', 'exit', tb.stem, '-do',
             'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']]
        log = ''
        for command in commands:
            r = subprocess.run(list(map(str, command)), cwd=folder, capture_output=True,
                               text=True, errors='replace', timeout=180)
            log += r.stdout+r.stderr
            (a.evidence/(name+'.log')).write_text(log, encoding='utf-8')
            if r.returncode or '** Error' in log or '** Fatal' in log:
                raise RuntimeError(log[-4000:])
        if marker not in log:
            raise RuntimeError('Missing positive pass marker: '+marker+'\n'+log[-2000:])
        records.append(dict(case=name, passed=True, marker=marker,
            test_sha256=sha(staged_tb),
            inputs=[dict(path=f.relative_to(REPO).as_posix(),sha256=sha(f)) for f in sources]))
        print(name+' PASS', flush=True)
    Image.open(out/'frame/frame.ppm').save(a.evidence/'synthetic_video.png')
    write_json(a.evidence/'result.json', dict(cases=records, board_verified=False,
        note='Synthetic fixture -> canonical frontend OSD -> supplied white split compositor; '
             'not a camera capture, neural recognition result, or complete board-top verification.'))
    print('YOLO120_WHITE_VIDEO_SIM_PASS')


if __name__ == '__main__':
    main()
