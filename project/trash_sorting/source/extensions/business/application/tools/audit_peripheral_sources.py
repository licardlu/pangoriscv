"""Record current active source hashes without overwriting baseline manifests.

No synthesis, placement, routing, programming, serial or hardware access.
"""
from pathlib import Path
import hashlib
import json
import re

app=Path(__file__).resolve().parents[1]
root=app.parents[2]
yolo=root/'yolo'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pin_plan=json.loads((root/'docs/pin_evidence/conflict_check.json').read_text('utf-8-sig'))
fdc=yolo/'sources/camera.fdc'
assert sha(fdc)==pin_plan['constraint_sha256'], 'Active pin/timing constraints have changed'
for item in pin_plan['servo_candidates'].values():
    assert item['conflict'] is None

roots={'pkg_dir':yolo,'src_dir':yolo/'sources','business_dir':app}
paths={fdc,yolo/'build_pre_pnr.tcl'}
rtl_count=0
for var,rest in re.findall(r'add_design \[file join \$(\w+) ([^\]]+)\]',
                          (yolo/'build_pre_pnr.tcl').read_text()):
    p=roots[var].joinpath(*rest.split())
    assert p.is_file(),str(p)
    paths.add(p)
    rtl_count+=p.suffix in ('.sv','.v')
paths.update((app/'assets').glob('ui_light_*.hex'))
paths.update((app/'assets/audio_rom').glob('*'))
paths.add(yolo/'sources/program.hex')
paths.update((yolo/'sources').glob('firmware_lane*.bin'))
baseline=json.loads((root/'manifest.json').read_text('utf-8-sig'))
old={row['path']:row for row in baseline['files']}
records=[]
for p in sorted(paths):
    rel=p.relative_to(root).as_posix()
    row={'path':rel,'bytes':p.stat().st_size,'sha256':sha(p)}
    if rel in old:
        row['original_package_sha256']=old[rel]['sha256']
        row['changed_from_original_package']=row['sha256']!=old[rel]['sha256']
    else: row['new_source_or_asset']=True
    records.append(row)
out=root/'docs/peripheral_current_sources.json'
out.write_text(json.dumps({
    'date':'2026-11-03',
    'scope':'active Tcl source inputs plus peripheral ROMs; baseline manifests preserved',
    'active_top':'yolo/portable/052_yolo_camera_top.v',
    'default_peripheral_test_mode':1,
    'fixed_correct_answer':1,
    'active_pin_constraint_unchanged':True,
    'rtl_source_count':rtl_count,
    'pnr_run':False,'bitstream_generated':False,'board_verified':False,
    'files':records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'SOURCE_AUDIT_PASS {rtl_count} active RTL inputs, {len(records)} records, original FDC unchanged')
