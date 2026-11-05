"""Explicit-port board acceptance: repeated camera latency, raw replies and cycles."""
import argparse
import json
import math
from pathlib import Path
import statistics
import struct
import sys
import time

from build import HZ, PROJECT, YOLO, sha, write_json
sys.path.insert(0, str(YOLO/'scripts'))
from board_loader import load_deployment, parse_detections, transact, write_image
from board_perf import parse_profile


def assess_runs(runs, frames, target):
    final=[r for r in runs if r['camera_fast']==1 and not r['warmup']]
    complete=len(final)==frames
    latency=[max(r['wall_seconds'],r['device_seconds']) for r in final]
    return dict(passed=complete and all(v<=target for v in latency),
                target_seconds=target, measured_frames=len(final),
                worst_seconds=max(latency) if latency else None,
                median_seconds=statistics.median(latency) if latency else None,
                metric='max(host request/reply wall time, capture+forward+decode+display cycles/Hz)',
                excludes='one-time UART model upload and CRC; includes camera acquisition')


def validate_profile(profile, elapsed, op_count):
    if profile['cpu_hz'] != HZ or profile['flags'] != 63:
        raise ValueError('Clock or optimization mode differs from requested build')
    operators = profile['operators']
    if (len(operators) != op_count or
            any(op['cycles'] <= 0 for op in operators)):
        raise ValueError('Incomplete full-model operator profile')
    stages = profile['stages']
    if any(not math.isfinite(v) or v <= 0 for v in stages.values()):
        raise ValueError('Invalid camera stage timing')
    if sum(op['seconds'] for op in operators) > stages['forward'] + 1/HZ:
        raise ValueError('Operator timing exceeds complete forward pass')
    seconds = sum(stages.values())
    if not math.isfinite(elapsed) or abs(seconds-elapsed) > max(.2, .05*elapsed):
        raise ValueError('Device timing and wall clock disagree')
    return seconds


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port',required=True)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--implementation',type=Path,required=True,
                   help='Matching build directory with passed final STA and bitstream hash')
    p.add_argument('--frames',type=int,default=10)
    p.add_argument('--target-seconds',type=float,default=1.2,
                   help='Default 1.2 s allows the requested approximately one-second refresh')
    p.add_argument('--upload-model',action='store_true')
    p.add_argument('--baseline',action='store_true',help='also measure legacy camera preprocessing')
    args=p.parse_args()
    if args.frames<3 or not math.isfinite(args.target_seconds) or args.target_seconds<=0:
        p.error('Use >=3 measured frames and a finite positive target')
    implementation=json.loads((args.implementation/'acceptance.json').read_text(encoding='utf-8'))
    bitstream=Path(implementation['bitstream']) if implementation.get('bitstream') else None
    if (not implementation.get('timing_pass') or implementation.get('cpu_hz')!=HZ or
            not bitstream or not bitstream.is_file() or
            sha(bitstream)!=implementation.get('bitstream_sha256')):
        p.error('Implementation must have a present bitstream matching passed final timing')
    args.out.mkdir(parents=True,exist_ok=False)
    model,blob=load_deployment(YOLO/'gen/integration/packed')
    report=dict(board_test=True,cpu_hz=HZ,runs=[],passed=False,
                implementation=implementation,
                implementation_path=str(args.implementation.resolve()),
                identity_note='Host candidate hash recorded; firmware protocol cannot attest the loaded bitstream. Program this exact candidate first.',
                model_sha256=sha(YOLO/'gen/integration/packed/model.bin'))
    try:
        import serial
        with serial.Serial(args.port,115200,timeout=240,write_timeout=10) as port:
            if args.upload_model:
                write_image(port,model['blob_base'],blob)
            transact(port,5)
            if transact(port,9,63) != struct.pack('<I',63):
                raise ValueError('Firmware did not accept full-model optimization options')
            for mode in ([0,1] if args.baseline else [1]):
                if transact(port,10,mode)!=struct.pack('<I',mode):
                    raise ValueError('YOLO120 cmd10 not supported by running firmware')
                for i in range(args.frames+1):
                    started=time.monotonic()
                    raw=transact(port,6)
                    elapsed=time.monotonic()-started
                    detections=parse_detections(raw)
                    raw_profile=transact(port,8)
                    profile=parse_profile(raw_profile,model)
                    seconds=validate_profile(profile, elapsed, len(model['ops']))
                    (args.out/f'mode{mode}_frame{i:02}.bin').write_bytes(raw)
                    (args.out/f'mode{mode}_frame{i:02}_profile.bin').write_bytes(raw_profile)
                    report['runs'].append(dict(camera_fast=mode,warmup=i==0,
                        wall_seconds=elapsed,device_seconds=seconds,profile=profile,detections=detections))
                    write_json(args.out/'result.json',report)
                    print(f'camera_fast={mode} frame={i} warmup={i==0} seconds={elapsed:.6f}',flush=True)
            report['acceptance']=assess_runs(report['runs'],args.frames,args.target_seconds)
            report['passed']=report['acceptance']['passed']
    except Exception as exc:
        report['error']=f'{type(exc).__name__}: {exc}'
        raise
    finally:
        write_json(args.out/'result.json',report)
    if not report['passed']:
        raise SystemExit('Requested latency target FAILED; inspect per-operator profile in result.json')
    print('YOLO120_BOARD_LATENCY_PASS')


if __name__=='__main__':
    main()
