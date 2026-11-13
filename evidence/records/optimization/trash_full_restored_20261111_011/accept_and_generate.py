from pathlib import Path
import importlib.util, json, hashlib, shutil, subprocess, re
out=Path(__file__).resolve().parent
root=out.parents[1]
base=root/'build/trash_full_restored_20261111_004'
cwd=base/'input/yolo/sources'
spec=importlib.util.spec_from_file_location('build_full',root/'project/trash_sorting/tools/build_full.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
manifest=json.loads((base/'inputs.json').read_text(encoding='utf8'))
for name,expected in manifest['files'].items():
    if b.sha(base/'input'/name)!=expected: raise ValueError('Frozen source changed: '+name)
for name in ['yolo_camera_top_map.adf','yolo_camera_top.pcf']:
    if b.sha(out/'mapped_input'/name)!=b.sha(cwd/'device_map'/name):raise ValueError('Mapped identity mismatch')
log=(out/'implementation.log').read_text(errors='replace')
if re.search(r'^\s*E:',log,re.M) or "Design 'yolo_camera_top' has been routed successfully." not in log:raise ValueError('PNR not successful')
timing=out/'report_timing/yolo_camera_top.rtr'
clocks=b.timing_gate(timing.read_text(errors='replace'))
memories=b.accept_memories(cwd)
maplog=(cwd/'device_map/run.log').read_text(errors='replace')
resources={n:dict(used=float(u),available=float(a)) for n,u,a in re.findall(r'\|\s*(APM|FF|LUT|Distributed RAM|DRM|IO)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|',maplog)}
if len(resources)!=6 or any(x['used']>x['available'] for x in resources.values()):raise ValueError('Resource capacity gate failed')
area=json.loads((base/'pre-route-area-gate.json').read_text())
if area['status']!='PASS':raise ValueError('Documented budget failed')
result=dict(model_sha256=b.sha(base/'input/yolo/model/model.bin'),timing_pass=True,final_timing=clocks,resources=resources,memory_loads=memories,source_build=str(base),source_manifest_sha256=b.sha(base/'inputs.json'),mapped_sha256=b.sha(out/'mapped_input/yolo_camera_top_map.adf'),servo_reversed_mask='1111',peripheral_test_mode=0,fast_router=True,share_router_control_signal=True,route_parameters=json.loads((out/"route_parameters.json").read_text()),board_programmed=False,model_loaded=False,physical_full_application_verified=False)
b.write_json(out/'acceptance.json',result)
pnr=out/'place_route/yolo_camera_top_pnr.adf'
result['pnr_sha256']=b.sha(pnr)
result['resources_stage']='device_map'
prr=out/'place_route/yolo_camera_top.prr'
row=re.search(r'\|\s*yolo_camera_top\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([0-9.]+)',prr.read_text(errors='replace'))
if not row:raise ValueError('Missing routed resource usage')
result['routed_resources']=dict(zip(['LUT','FF','Distributed RAM','APM','DRM'],map(float,row.groups())))
if any(result['routed_resources'][n]>resources[n]['available'] for n in result['routed_resources']):raise ValueError('Routed capacity exceeded')
shutil.copy2(out/'multiseed_summary.csv',out/'final_multiseed_summary.csv')

tcl=out/'generate.tcl'
tcl.write_text(f'set_arch -input_db_file {{{pnr.as_posix()}}}\ngen_bit_stream -force_to_run -input_db_file {{{pnr.as_posix()}}}\nputs FULL_APPLICATION_BITSTREAM_COMPLETE\n',encoding='ascii')
# Stage enforcement already passed the final multi-corner timing gate above.
b.run_pds(Path('D:/FPGA_Project/zi_guang_tong_chuang/pds/PDS_2022.2-SP6.1/bin'),tcl,out,out/'bitstream.log')
bit=out/'generate_bitstream/yolo_camera_top.sbit'
if not bit.is_file() or not bit.stat().st_size:raise ValueError('Missing bitstream')
result.update(bitstream=str(bit),bitstream_sha256=b.sha(bit))
b.write_json(out/'acceptance.json',result)
e=root/'evidence/records/optimization'/out.name;e.mkdir(parents=True,exist_ok=False)
for p in [out/'acceptance.json',base/'inputs.json',base/'pre-route-area-gate.json',base/'memory-gate.json',base/'implementation.log',timing,out/'implementation.log',out/'bitstream.log',out/'mapped_input/mapped_identity.json',out/'implement.tcl',out/'route_parameters.json',out/'placed_identity.json',out/'generate.tcl',Path(__file__)]:
    label='source_implementation.log' if p==base/'implementation.log' else p.name
    shutil.copy2(p,e/label)
for phase in ['compile','synthesize','device_map']:
    shutil.copy2(cwd/phase/'run.log',e/(phase+'.log'))
shutil.copy2(out/'place_route/run.log',e/'place_route.log')
shutil.copy2(out/'final_multiseed_summary.csv',e/'multiseed_summary.csv')
shutil.copy2(prr,e/'yolo_camera_top.prr')
release=root/'project/trash_sorting/bitstream/full_27mhz';release.mkdir(parents=True,exist_ok=True)
shutil.copy2(bit,release/bit.name);b.write_json(release/'manifest.json',result)
print('FULL_APPLICATION_BITSTREAM_READY',bit,'SHA256='+b.sha(bit),flush=True)
