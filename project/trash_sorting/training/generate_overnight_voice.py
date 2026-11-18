"""Create reviewable neural Mandarin sources; no FPGA ROM is changed here."""
import argparse,asyncio,hashlib,json,subprocess,wave,array
from pathlib import Path
import edge_tts,imageio_ffmpeg
LINES={1:'请问，这是什么垃圾？',2:'答对了！',3:'再想一想。',
 4:'这是厨余垃圾。',5:'这是有害垃圾。',6:'这是其他垃圾。',7:'这是可回收垃圾。',
 8:'恭喜你，又答对了！',9:'你已经连续三次答对了，非常棒！',
 10:'分类小能手，继续加油！',11:'太棒了，判断很准确！',
 12:'别灰心，下一次一定可以。',13:'差一点点，记住这个答案。',
 14:'当前是跑分页面，请按按键一开始跑分。'}
async def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 a.out.mkdir(parents=True,exist_ok=True);manifest=[]
 for ident,line in LINES.items():
  mp3=a.out/f'voice_{ident:02d}.mp3';wav=a.out/f'voice_{ident:02d}.wav'
  if not mp3.exists():
   await edge_tts.Communicate(line,'zh-CN-XiaoxiaoNeural',rate='-2%',volume='-8%').save(str(mp3))
  subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-i',str(mp3),
   '-af','highpass=f=70,lowpass=f=5400,silenceremove=start_periods=1:start_duration=0.02:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_duration=0.02:start_threshold=-45dB,areverse',
   '-ac','1','-ar','12000','-c:a','pcm_s16le',str(wav)],check=True)
  with wave.open(str(wav),'rb') as f:pcm=array.array('h',f.readframes(f.getnframes()))
  peak=max(abs(x) for x in pcm);gain=min(1.8,26000/max(1,peak))
  pcm=array.array('h',(round(x*gain) for x in pcm))
  # Gentle boundary ramps prevent request changes from creating clicks.
  ramp=min(120,len(pcm)//2)
  for i in range(ramp):pcm[i]=round(pcm[i]*i/ramp);pcm[-1-i]=round(pcm[-1-i]*i/ramp)
  with wave.open(str(wav),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(12000);f.writeframes(pcm.tobytes())
  entry={'id':ident,'text':line,'voice':'zh-CN-XiaoxiaoNeural','rate':'-2%',
   'source':'Microsoft Edge TTS','samples':len(pcm),'sample_hz':12000,'peak':max(abs(x) for x in pcm),
   'wav_sha256':hashlib.sha256(wav.read_bytes()).hexdigest(),'source_mp3_sha256':hashlib.sha256(mp3.read_bytes()).hexdigest()}
  manifest.append(entry);print(ident,line,round(len(pcm)/12000,3),flush=True)
 (a.out/'sources.json').write_text(json.dumps({'clips':manifest,'total_samples':sum(x['samples'] for x in manifest)},ensure_ascii=False,indent=2),encoding='utf8')
if __name__=='__main__':asyncio.run(main())
