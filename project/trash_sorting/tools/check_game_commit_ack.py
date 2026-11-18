"""Run candidate GAME_TARGET_LOCK RTL only; never invokes PDS or a downloader."""
import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();source=args.source_dir.resolve();out=args.out.resolve()
    out.mkdir(parents=True,exist_ok=False)
    root=Path(__file__).resolve().parents[3]
    app=source/'extensions/business/application/rtl'
    files=[source/'yolo/sources/048_camera_snapshot.v',
           source/'yolo/sources/049_video_ai_frontend.v',
           app/'result_event_cdc.sv',app/'trash_quiz_controller.sv',app/'yolo_class_to_bin.v',
           source/'yolo/tb/tb_game_target_lock.sv']
    sim=Path('D:/FPGA_Project/Modelism/win64');commands=[]
    def run(name,*args):
        command=[str(sim/name),*map(str,args)];commands.append(command)
        result=subprocess.run(command,cwd=out,capture_output=True,text=True,timeout=180)
        with (out/'checks.log').open('a',encoding='utf8') as log:
            log.write(result.stdout+result.stderr)
        if result.returncode or '** Error' in result.stdout or '** Fatal' in result.stdout:
            raise RuntimeError(result.stdout+result.stderr)
        return result.stdout+result.stderr
    run('vlib.exe','work');run('vlog.exe','-sv',*files)
    output=run('vsim.exe','-c','tb_game_target_lock','-do',
        'onerror {quit -code 1}; run -all; quit -code 0')
    if 'TEST_PASS game_target_lock' not in output:raise RuntimeError(output)
    result=dict(status='GAME_COMMIT_ACK_RTL_PASS',created_utc=datetime.now(timezone.utc).isoformat(),
        pnr_performed=False,board_modified=False,commands=commands,
        source_hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files})
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print('TEST_PASS candidate GAME_TARGET_LOCK token acceptance and round flow',flush=True)


if __name__=='__main__':main()
