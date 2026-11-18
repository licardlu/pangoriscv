"""Check all 14 decoded clips against independent audioop samples and page speech routing."""
import argparse, hashlib, json, shutil, subprocess
from pathlib import Path
def main():
 p=argparse.ArgumentParser();p.add_argument('--source-dir',type=Path,required=True)
 p.add_argument('--vectors',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 root=Path(__file__).resolve().parents[3];out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 rtl=a.source_dir.resolve()/'extensions/business/application/rtl';assets=rtl.parent/'assets/audio_rom'
 m=json.loads((assets/'voice_rom_manifest.json').read_text(encoding='utf8'));count=len(m['assets']);total=sum(c['samples'] for c in m['assets'])
 assert count==14 and m['bank_count']<=59
 for f in assets.glob('voice_pcm8.hex*'):shutil.copy2(f,out/f.name)
 for f in a.vectors.glob('*'):shutil.copy2(f,out/f.name)
 t=(root/'project/trash_sorting/tests/tb_overnight_adpcm.sv').read_text(encoding='utf8')
 t=t.replace('expected[0:237768]',f'expected[0:{total-1}]').replace('[1:13]','[1:14]').replace('id<=13','id<=14').replace('all13','all14')
 t=t.replace('../../project/trash_sorting/candidates/overnight_020/source/extensions/business/application/assets/audio_rom/voice_pcm8.hex','voice_pcm8.hex').replace('audio/vectors/voice_expected.hex','voice_expected.hex')
 (out/'tb_overnight_adpcm.sv').write_text(t,encoding='utf8')
 sim=Path('D:/FPGA_Project/Modelism/win64')
 def run(name,*args):
  r=subprocess.run([str(sim/name),*map(str,args)],cwd=out,capture_output=True,text=True,timeout=180)
  with (out/'checks.log').open('a',encoding='utf8')as f:f.write(r.stdout+r.stderr)
  r.check_returncode();assert '** Error' not in r.stdout and '** Fatal' not in r.stdout,r.stdout
  return r.stdout
 run('vlib.exe','work');run('vlog.exe','-sv','+incdir+'+str(out),*[rtl/n for n in ('trash_voice_rom_player.v','trash_i2s_tx.v','trash_voice_i2s.v')],out/'tb_overnight_adpcm.sv',root/'project/trash_sorting/tests/tb_feedback_voice_route.sv')
 for case in ('tb_overnight_adpcm','tb_feedback_voice_route'):
  result=run('vsim.exe','-c',case,'-do','onerror {quit -code 1}; run -all; quit -code 0');assert 'TEST_PASS' in result,result
 report=dict(status='AUDIO_RTL_PASS',clips=count,decoded_reference_samples=total,rom_bytes=m['rom_bytes'],bank_count=m['bank_count'],
  min_snr_db=min(c['snr_db'] for c in m['assets']),manifest_sha256=hashlib.sha256((assets/'voice_rom_manifest.json').read_bytes()).hexdigest(),board_modified=False,pnr_performed=False)
 (out/'result.json').write_text(json.dumps(report,indent=2),encoding='utf8');print(json.dumps(report))
if __name__=='__main__':main()
