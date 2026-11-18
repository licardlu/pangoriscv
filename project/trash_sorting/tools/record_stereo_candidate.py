"""Freeze the code-review evidence, never performs FPGA implementation."""
import argparse
from datetime import datetime,timezone
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf8'))
def write(path,value):path.write_text(json.dumps(value,indent=2,ensure_ascii=False),encoding='utf8')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--rtl-dir',type=Path,default=ROOT/'build/continuation_022_stereo_sim_final')
    p.add_argument('--native-dir',type=Path,default=ROOT/'build/continuation_022_native_final')
    p.add_argument('--firmware-dir',type=Path,default=ROOT/'build/continuation_022_firmware_final')
    p.add_argument('--allpaths-dir',type=Path,default=ROOT/'build/continuation_022_allpaths_final')
    p.add_argument('--interfaces-dir',type=Path)
    p.add_argument('--stack-dir',type=Path)
    p.add_argument('--standby-dir',type=Path)
    p.add_argument('--dashboard-dir',type=Path)
    p.add_argument('--rowstream-dir',type=Path)
    a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
    candidate=ROOT/'project/trash_sorting/candidates/continuation_022'
    source=candidate/'source';baseline=read(candidate/'baseline.json')
    previous=ROOT/baseline['source']
    for name,expected in baseline['files'].items():
        if sha(previous/name)!=expected:raise ValueError('Historical source changed: '+name)
    sys.path.insert(0,str(Path(__file__).parent/'overnight'))
    from build_full import verify_firmware_sources
    verify_firmware_sources(source)  # read-only; do NOT call build_full.main
    firmware=read(source/'yolo/sources/firmware-source-manifest.json')
    assert firmware['stereo_candidate'] and firmware['compact_scratch'] and firmware['nano_libc']
    assert firmware['board_programmed'] is False
    tests={
        'rtl':a.rtl_dir/'result.json',
        'native':a.native_dir/'result.json',
        'head':ROOT/'build/continuation_022_head_003/result.json',
        'linear_pool':ROOT/'build/continuation_022_linear_final/result.json',
        'actual_model':ROOT/'build/continuation_022_actual_model_final/result.json',
        'allpaths':a.allpaths_dir/'scope.json'}
    if a.interfaces_dir:tests['interfaces']=a.interfaces_dir/'result.json'
    if a.stack_dir:tests['stack']=a.stack_dir/'result.json'
    if a.rowstream_dir:tests['rowstream']=a.rowstream_dir/'result.json'
    summaries={name:read(path) for name,path in tests.items()}
    assert all('PASS' in summaries[k]['status'] for k in ('rtl','native','head','linear_pool','actual_model'))
    assert summaries['allpaths']['status']=='ALL_STEREO_PATHS_LINKED'
    if a.interfaces_dir:assert summaries['interfaces']['status']=='TOP_INTERFACE_ELABORATION_PASS'
    if a.stack_dir:
        assert summaries['stack']['status']=='STATIC_STACK_AUDIT_PASS'
        assert summaries['stack']['elf_sha256']==sha(a.allpaths_dir/'firmware/firmware.elf')
    if a.rowstream_dir:
        row=summaries['rowstream']
        assert row['status']=='ALL_COMMITTED_CANVASES_IDENTICAL_PASS'
        assert row['candidate_source_sha256']==sha(source/'yolo/software/benchmark_ui.c')
        assert row['baseline_source_sha256']==sha(previous/'yolo/software/benchmark_ui.c')
        assert row['test_sha256']==sha(ROOT/'project/trash_sorting/tests/test_overnight_demo.c')
    assert summaries['actual_model']['model_sha256']==firmware['model_sha256']
    assert read(a.firmware_dir/'manifest.json')['firmware_sha256']==firmware['firmware_sha256']
    assert sha(a.firmware_dir/'firmware.bin')==firmware['firmware_sha256']
    # Arithmetic/model evidence may be reused only when its participating
    # runtime/decoder headers are byte-identical to the earlier frozen review.
    prior_inventory=read(ROOT/'evidence/records/optimization/continuation_022_code_review/source_sha256.json')
    reused_sources={name:expected for name,expected in prior_inventory.items()
        if Path(name).name in ('yolo_runtime.c','yolo_runtime.h','yolo_decode.c','yolo_decode.h')}
    assert len(reused_sources)==4
    for name,expected in reused_sources.items():assert sha(source/name)==expected
    assert summaries['linear_pool']['runtime_sha256']==sha(source/'yolo/software/yolo_runtime.c')
    original=read(ROOT/'build/overnight_20261116/numeric_stage4_exact_001/predictions.json')
    predictions=ROOT/'build/continuation_022_actual_model_final/predictions.json'
    assert read(predictions)==original
    for path,expected in summaries['rtl']['top_files'].items():
        assert sha(Path(path))==expected
    for path,expected in summaries['native']['source_hashes'].items():
        assert sha(Path(path))==expected
    if a.interfaces_dir:
        for path,expected in summaries['interfaces']['top_files'].items():assert sha(Path(path))==expected
    # The size-only build differs only in its documented opaque calibration
    # and its main-entry asm barrier; every other compiled C/header must match.
    isolated=a.allpaths_dir/'source/yolo/software'
    for path in (source/'yolo/software').iterdir():
        if path.suffix not in ('.c','.h'):continue
        expected=path.read_bytes();actual=(isolated/path.name).read_bytes()
        if path.name=='stereo_calibration.h':
            expected=path.read_text(encoding='utf8').replace(
                'static const stereo_calibration_t stereo_calibration',
                '/* STEREO_COMPILE_SIZE_ONLY: NEVER INSTALL. */\nstatic stereo_calibration_t stereo_calibration').encode()
            actual=(isolated/path.name).read_text(encoding='utf8').encode()
        elif path.name=='platform_main.c':
            expected=path.read_text(encoding='utf8').replace('int main(void)\n{',
                'int main(void)\n{\n    __asm__ volatile("" : "+m"(stereo_calibration));').encode()
            actual=(isolated/path.name).read_text(encoding='utf8').encode()
        assert actual==expected,'Size-only source mismatch: '+path.name
    # Save the five transport/export checks as actual executed evidence.
    result=subprocess.run([sys.executable,str(Path(__file__).parent/'test_stereo_tools.py')],
        capture_output=True,text=True,timeout=60)
    (out/'tools_tests.log').write_text(result.stdout+result.stderr,encoding='utf8')
    result.check_returncode()
    mapping=a.allpaths_dir/'firmware/firmware.map'
    match=re.search(r'(0x[0-9a-f]+)\s+_bss_end =',mapping.read_text())
    bss_end=int(match[1],16);stack_bytes=0x80014000-bss_end
    assert stack_bytes>=8192
    for name,path in tests.items():shutil.copy2(path,out/(name+'.json'))
    for name in ('manifest.json','firmware.map','build.log','firmware.elf.ltrans0.ltrans.su'):
        shutil.copy2(a.firmware_dir/name,out/('firmware_'+name))
    for name in ('firmware.map','build.log','firmware.elf.ltrans0.ltrans.su'):
        shutil.copy2(mapping.parent/name,out/('allpaths_'+name))
    shutil.copy2(predictions,out/'actual_model_predictions.json')
    shutil.copy2(a.rtl_dir/'checks.log',out/'rtl_checks.log')
    for path in a.native_dir.glob('*.log'):
        shutil.copy2(path,out/('native_'+path.name))
    if a.interfaces_dir:shutil.copy2(a.interfaces_dir/'checks.log',out/'top_interfaces.log')
    if a.rowstream_dir:
        for path in a.rowstream_dir.glob('*.log'):shutil.copy2(path,out/('rowstream_'+path.name))
    renders={}
    for kind,directory,names in [('standby',a.standby_dir,('standby0.png','standby1.png')),
            ('dashboard',a.dashboard_dir,('dashboard.png',))]:
        if directory:
            log=(directory/'checks.log').read_text(encoding='utf8')
            assert 'TEST_PASS' in log and 'TEST_FAIL' not in log
            shutil.copy2(directory/'checks.log',out/(kind+'_render.log'))
            for name in names:
                shutil.copy2(directory/name,out/name);renders[name]=sha(out/name)
    if a.standby_dir:
        for name in ('media_font.hex','media_labels.hex'):
            assert sha(a.standby_dir/name)==sha(source/'yolo/sources'/name)
    if a.dashboard_dir:assert sha(a.dashboard_dir/'benchmark_font.hex')==sha(source/'yolo/sources/benchmark_font.hex')
    inventory={str(path.relative_to(source)):sha(path) for path in sorted(source.rglob('*'))
        if path.is_file() and not {'build','evidence','__pycache__'}.intersection(path.relative_to(source).parts)}
    write(out/'source_sha256.json',inventory)
    added=[];changed=[];diff=[]
    for name,expected in inventory.items():
        old=baseline['files'].get(name)
        if old==expected:continue
        (added if old is None else changed).append(name)
        if Path(name).suffix in ('.v','.sv','.c','.h','.tcl'):
            before=(previous/name).read_text(encoding='utf8') if (previous/name).exists() else ''
            after=(source/name).read_text(encoding='utf8')
            diff.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
                fromfile='baseline/'+name,tofile='candidate/'+name))
    (out/'source_changes.diff').write_text(''.join(diff),encoding='utf8')
    write(out/'result.json',dict(status='CODE_AND_SIMULATION_REVIEW_READY',
        utc=datetime.now(timezone.utc).isoformat(),candidate=str(candidate),
        placement_routing_performed=False,board_modified=False,serial_accessed=False,
        user_approval_required_before_placement_routing=True,physical_distance_verified=False,
        real_calibration_supplied=False,default_distance_gate_enabled=False,
        startup_page='animation',single_click='recognition start/stop',
        double_click='score/animation',baseline_verified_files=len(baseline['files']),
        previous_model_predictions_identical=True,training_performed=False,
        firmware_sha256=firmware['firmware_sha256'],firmware_bytes=firmware['firmware_bytes'],
        model_sha256=firmware['model_sha256'],allpaths_bss_end=hex(bss_end),
        allpaths_stack_bytes=stack_bytes,minimum_stack_bytes=8192,
        reused_arithmetic_sources=reused_sources,rendered_images=renders,
        static_stack_bytes=summaries.get('stack',{}).get('conservative_call_chain_bytes'),
        static_stack_margin_bytes=summaries.get('stack',{}).get('remaining_bytes'),
        added=added,changed=changed,tests={name:dict(path=str(path),sha256=sha(path))
            for name,path in tests.items()},source_inventory_sha256=sha(out/'source_sha256.json'),
        limitations=['No real calibration/distance/exposure-sync verification',
            'Generated DDR/PLL/RAM IP behavior not simulated; interface elaboration only',
            'Static stack call-chain audit is not a runtime high-water measurement',
            'No measured new resource usage/timing/inference speed',
            'Existing board 006 remains experimental with -0.012ns hold']))
    print('TEST_PASS candidate identities, historical source preserved, evidence recorded; no PNR/download')


if __name__=='__main__':main()
