import os
from pathlib import Path
import subprocess,sys,argparse
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--case',default='servo_pwm4',help='default is the one case that needs no external stimulus; npu/business/soc reference files that are not in this package');p.add_argument('--modelsim',default=os.environ.get('MODELSIM_BIN', 'D:/modeltech64_10.6e/win64'));a=p.parse_args()
b=root/'build'/('sim_'+a.case);b.mkdir(parents=True,exist_ok=True)
files={'bridge':['rtl/pango256_bridge.sv','tests/bridge_tb.sv'],'fabric':['rtl/ddr_fabric.sv','tests/fabric_tb.sv'],'memory':['rtl/frame_dma.sv','tests/memory_tb.sv'],'display':['rtl/vision_overlay.sv','rtl/bcd32.sv','rtl/ui_rgb.sv','tests/display_tb.sv'],'cdc':['rtl/async_fifo.sv','tests/cdc_tb.sv'],'peripherals':['rtl/servo_pwm.sv','rtl/servo_guard.sv','rtl/i2s_tx.sv','rtl/dvp_rx.sv','tests/peripherals_tb.sv'],'soc':['rtl/independent_core.sv','rtl/iterative_divider.sv','rtl/npu_subsystem.sv','rtl/ddr_fabric.sv','../ai_lab/rtl/conv_engine_axil.v','../ai_lab/rtl/conv_band_rt.v','../ai_lab/rtl/mac_array.v','rtl/servo_pwm.sv','rtl/servo_guard.sv','rtl/i2s_tx.sv','rtl/async_fifo.sv','rtl/snapshot_cdc.sv','rtl/reset_sync.sv','rtl/uart_link.sv','rtl/app_mmio.sv','rtl/vision_mmio.sv','rtl/application_soc.sv','tests/soc_tb.sv']}
if a.case=='integration':
 files['integration']=['rtl/'+f for f in ['independent_core.sv','iterative_divider.sv','npu_subsystem.sv','servo_pwm.sv','servo_guard.sv','i2s_tx.sv','async_fifo.sv','snapshot_cdc.sv','reset_sync.sv','uart_link.sv','app_mmio.sv','application_soc.sv','dvp_rx.sv','camera_cdc.sv','frame_dma.sv','ddr_fabric.sv','vision_mmio.sv','vision_overlay.sv','bcd32.sv','ui_rgb.sv','application_core_top.sv']]+['../ai_lab/rtl/conv_engine_axil.v','../ai_lab/rtl/conv_band_rt.v','../ai_lab/rtl/mac_array.v','tests/integration_tb.sv']
 import shutil
 for name in ['program_even.hex','program_odd.hex']:shutil.copy2(root/'build/firmware'/name,b/name)
if a.case in ('display','vision_display','vision_frame','integration','business_display','business_top'):
 import shutil
 for name in (['business_bg.hex','business_palette.hex','business_status.hex'] if a.case in ('business_display','business_top') else ['ui_bg.hex','ui_palette.hex','ui_status.hex']):shutil.copy2(root/'assets'/name,b/name)
files['npu']=['rtl/npu_subsystem.sv','../ai_lab/rtl/conv_engine_axil.v','../ai_lab/rtl/conv_band_rt.v','../ai_lab/rtl/mac_array.v','tests/npu_tb.sv']
files['vision_frame']=['rtl/vision_overlay.sv','rtl/bcd32.sv','rtl/ui_rgb.sv','tests/vision_frame_tb.sv']
files['vision_display']=['rtl/snapshot_cdc.sv','rtl/vision_mmio.sv','rtl/vision_overlay.sv','rtl/bcd32.sv','rtl/ui_rgb.sv','tests/vision_display_tb.sv']
files['overlay']=['rtl/vision_overlay.sv','tests/overlay_tb.sv']
files['vision']=['rtl/snapshot_cdc.sv','rtl/vision_mmio.sv','tests/vision_tb.sv']
files['servo_guard']=['rtl/servo_guard.sv','tests/servo_guard_tb.sv']
files['bcd']=['rtl/bcd32.sv','tests/bcd_tb.sv']
files['audio_retire']=['rtl/i2s_tx.sv','tests/audio_retire_tb.sv']
files['servo_pwm4']=['rtl/servo_pwm4.sv','tests/servo_pwm4_tb.sv']
files['light_panel']=['rtl/bcd32.sv','rtl/ui_light_panel.sv','tests/light_panel_tb.sv']
if a.case=='light_panel':
 import shutil
 for name in ['ui_light_bg.hex','ui_light_palette.hex','ui_light_status.hex']:
  shutil.copy2(root/'assets'/name,b/name)
files['business_display']=['rtl/bcd32.sv','rtl/dvp_rx.sv','rtl/camera_preview.sv','rtl/business_display.sv','tests/business_display_tb.sv']
files['camera_preview']=['rtl/camera_preview.sv','tests/camera_preview_tb.sv']
if a.case=='business_display':
 import shutil
 shutil.copy2(root/'assets/camera_demo_rgb565.hex',b/'camera_demo_rgb565.hex')
files['business']=files['soc'][:-1]+['tests/business_tb.sv']
if a.case=='business_top':
 files['business_top']=(root/'project/files.f').read_text(encoding='utf-8').splitlines()+['tests/business_top_tb.sv']
if a.case in ('business','business_top'):
 import shutil
 for name in ['program_even.hex','program_odd.hex']:shutil.copy2(root/'build/firmware_business'/name,b/name)
top=a.case+'_tb';marker='TEST_PASS '+a.case
if a.case.startswith('deploy'):
 from gen_deployment_rtl_vectors import generate
 b=generate(int(a.case[6:]))
 files[a.case]=['../ai_lab/rtl/conv_engine_axil.v','../ai_lab/rtl/conv_band_rt.v','../ai_lab/rtl/mac_array.v','../ai_lab/tb/tb_engine_axil.v']
 top='tb_engine_axil';marker='AXI-AXIL-PASS'
logs=[]
if 'rtl/ui_rgb.sv' in files[a.case]:
 files[a.case].insert(0,'rtl/ui_light_panel.sv')
 import shutil
 for name in ['ui_light_bg.hex','ui_light_palette.hex','ui_light_status.hex']:
  shutil.copy2(root/'assets'/name,b/name)
for exe,args in [('vlib.exe',['work']),('vlog.exe',['-sv','+incdir+.', '+incdir+'+str(root/'rtl'),'+incdir+'+str(root/'tests'),*[str(root/f) for f in files[a.case]]]),('vsim.exe',['-c','-onfinish','exit',top,'-do','onerror {quit -code 1}; run -all; quit -code 0'])]:
 r=subprocess.run([str(Path(a.modelsim)/exe),*args],cwd=b,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);logs.append(r.stdout)
 if r.returncode:print(r.stdout);sys.exit(r.returncode)
(root/'evidence').mkdir(exist_ok=True)
log='\n'.join(logs);(root/'evidence'/(a.case+'_sim.log')).write_text(log,encoding='utf-8');print(log[-4000:])
if marker not in log or '** Fatal:' in log:sys.exit(1)

print('TEST_PASS '+a.case)
