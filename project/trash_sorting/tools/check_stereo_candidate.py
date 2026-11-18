"""Code/ModelSim checks only. No PDS, placement, routing, UART or board access."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[3]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--modelsim', type=Path, default=Path('D:/FPGA_Project/Modelism/win64'))
    p.add_argument('--pango-sim', type=Path, default=ROOT.parent / 'pds/PDS_2022.2-SP6.1/arch/vendor/pango/verilog/simulation')
    a = p.parse_args()
    manual='input tri0 benchmark_key_event' in (a.source_dir/'extensions/media/media_page_router.sv').read_text(encoding='utf8')
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    src = a.source_dir.resolve() / 'yolo'
    tests=ROOT/'project/trash_sorting/tests'
    legacy=ROOT/'project/trash_sorting/tools/tb_full_snapshot_stream.sv'
    (out/legacy.name).write_text(legacy.read_text(encoding='utf8').replace(
        'frontend.capture.memory','frontend.legacy_capture.capture.memory'),encoding='utf8')
    keys=tests/('tb_feedback_navigation.sv' if manual else 'tb_overnight_navigation.sv')
    (out/'tb_stereo_keys.sv').write_text(keys.read_text(encoding='utf8').replace(
        'tb_feedback_navigation','tb_stereo_keys').replace('tb_overnight_navigation','tb_stereo_keys').replace(
        'check(2,3,0,0)','check(2,3,0,1)').replace(
        'TEST_PASS overnight navigation','TEST_PASS stereo_keys'),encoding='utf8')
    transition=tests/'tb_overnight_transition.sv'
    if manual:
        transition=out/'tb_overnight_transition.sv'
        transition.write_text((tests/'tb_feedback_transition.sv').read_text(encoding='utf8').replace('tb_feedback_transition','tb_overnight_transition'),encoding='utf8')
    navigation=tests/'tb_stereo_navigation.sv'
    if manual:
        navigation=out/'tb_stereo_navigation.sv'
        navigation.write_text((tests/'tb_stereo_navigation.sv').read_text(encoding='utf8').replace(
            '.long_press(long_press)',".benchmark_key_event(1'b0),.long_press(long_press)").replace(
            'page!=1 || !toggle','page!=1 || toggle'),encoding='utf8')
    files = [a.pango_sim.resolve()/'GTP_CLKBUFGMUX.v',
             src/'sources/073_camera_pair_snapshot.sv',
             src/'sources/048_camera_snapshot.v',src/'sources/049_video_ai_frontend.v',
             *(src/'sources'/name for name in ('042_conv_band_rt.v','043_mac_array.v','044_conv_engine_axil.v')),
             a.source_dir.resolve()/'extensions/business/application/rtl/yolo_class_to_bin.v',
             a.source_dir.resolve()/'extensions/business/application/rtl/benchmark_key_router.sv',
             a.source_dir.resolve()/'extensions/business/application/rtl/trash_quiz_controller.sv',
             a.source_dir.resolve()/'extensions/media/media_page_router.sv',
             out/'tb_stereo_keys.sv',out/legacy.name,
             transition,tests/'tb_overnight_quiz.sv',
             *(ROOT/'project/trash_sorting/tests'/name for name in
               ('tb_stereo_snapshot.sv','tb_stereo_frontend.sv')),navigation]
    def run(exe, *args):
        result = subprocess.run([str(a.modelsim.resolve()/exe), *map(str, args)], cwd=out,
                                capture_output=True, text=True, timeout=180)
        with (out/'checks.log').open('a', encoding='utf8') as log:
            log.write(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return result.stdout + result.stderr
    run('vlib.exe', 'work')
    run('vlog.exe', '-sv', *files)
    for case in ('stereo_snapshot','stereo_frontend','stereo_navigation','stereo_keys',
                 'overnight_transition','overnight_quiz','full_snapshot_stream'):
        output = run('vsim.exe', '-c', 'tb_'+case, '-do',
                     'onerror {quit -code 1}; run -all; quit -code 0')
        marker='SNAPSHOT_STREAM_PASS' if case=='full_snapshot_stream' else 'TEST_PASS '+case.replace('_',' ') if case.startswith('overnight_') else 'TEST_PASS '+case
        if marker not in output or 'Fatal:' in output:
            raise RuntimeError(output)
    roots=dict(pkg_dir=src,src_dir=src/'sources',
        business_dir=a.source_dir.resolve()/'extensions/business/application',
        media_dir=a.source_dir.resolve()/'extensions/media')
    entry=(src/'build_pre_pnr.tcl').read_text(encoding='utf8')
    top_files=[]
    for var,rest in re.findall(r'foreach source \[glob -nocomplain \[file join \$(\w+) ([^\]]+)\]\]',entry):
        parts=rest.split();top_files.extend(sorted(roots[var].joinpath(*parts[:-1]).glob(parts[-1])))
    for var,rest in re.findall(r'add_design \[file join \$(\w+) ([^\]]+)\]',entry):
        path=roots[var].joinpath(*rest.split())
        if path.suffix in ('.v','.sv'):top_files.append(path)
    top_files=list(dict.fromkeys(top_files))
    run('vlog.exe','+incdir+'+str(src/'sources/include'),
        '+incdir+'+str(roots['business_dir']/'rtl'),*top_files)
    payload = dict(status='RTL_SIMULATION_PASS', pnr_performed=False, board_modified=False,
                   physical_distance_verified=False,
                   cases=['stereo_snapshot','stereo_frontend','stereo_navigation','stereo_keys',
                       'overnight_transition','overnight_quiz','full_snapshot_stream'],
                   top_syntax_files=len(top_files),top_elaboration_verified=False,
                   top_files={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in top_files},
                   files={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files})
    (out/'result.json').write_text(json.dumps(payload, indent=2), encoding='utf8')
    print('TEST_PASS stereo snapshot; code/simulation only')


if __name__ == '__main__':
    main()
