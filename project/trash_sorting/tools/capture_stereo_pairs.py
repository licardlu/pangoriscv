"""Export frozen paired snapshots from candidate firmware; never programs FPGA.

Run only AFTER the user approves implementation/download of the new candidate.
No connection is made by importing this module. Capture stops autonomous mode;
--resume explicitly restarts it after a successful export.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]


def capture(port, transact, output, count, between=None):
    from PIL import Image
    output.mkdir(parents=True, exist_ok=False)
    pairs = []
    manifest = dict(timestamp_source='frame_start_common_clock',
                    exposure_sync_verified=False, physical_distance_verified=False,
                    board_programmed=False, autonomous_stopped=True, pairs=pairs)
    for number in range(count):
        if between:
            between(number)
        raw = transact(port, 21)
        if len(raw) != 36:
            raise ValueError('Unexpected stereo metadata length')
        magic, width, height, status, hz, ids, tick_l, tick_r, version = struct.unpack('<9I', raw)
        if (magic != 0x53545031 or version != magic or width != 320 or height != 180
                or status & 15 != 10 or not status & 16 or not hz):
            raise ValueError('Snapshot is not a complete STP1 stereo pair')
        packed = bytearray()
        for offset in range(0, width*height, 128):
            chunk = transact(port, 22, offset)
            if len(chunk) != 256:
                raise ValueError('Truncated frozen snapshot chunk')
            packed.extend(chunk)
        left = output/f'left_{number:03d}.png'
        right = output/f'right_{number:03d}.png'
        Image.frombytes('L', (width,height), bytes(packed[0::2])).save(left)
        Image.frombytes('L', (width,height), bytes(packed[1::2])).save(right)
        difference = ((tick_r-tick_l+0x80000000)&0xffffffff)-0x80000000
        pairs.append(dict(left=left.name,right=right.name,
            left_frame_id=ids&65535,right_frame_id=ids>>16,
            left_frame_tick=tick_l,right_frame_tick=tick_r,cpu_hz=hz,
            left_timestamp_ms=tick_l*1000/hz,
            right_timestamp_ms=(tick_l+difference)*1000/hz,
            utc=datetime.now(timezone.utc).isoformat(),
            left_sha256=hashlib.sha256(left.read_bytes()).hexdigest(),
            right_sha256=hashlib.sha256(right.read_bytes()).hexdigest()))
        (output/'pairs.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
        print(f'PAIR {number+1}/{count}: frame-start skew {difference*1000/hz:.3f} ms',flush=True)
    return manifest


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--count',type=int,default=1)
    p.add_argument('--interactive',action='store_true',help='Wait for a new static calibration pose before each pair')
    p.add_argument('--resume',action='store_true',help='Explicitly resume autonomous recognition after successful export')
    a=p.parse_args()
    if not 1<=a.count<=100 or (a.count>1 and not a.interactive):
        p.error('Use 1..100 pairs; multiple calibration poses require --interactive')
    import serial
    spec=importlib.util.spec_from_file_location('board_loader',ROOT/'extensions/yolo/scripts/board_loader.py')
    loader=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loader)
    with serial.Serial(a.port,115200,timeout=30,write_timeout=10) as port:
        capture(port,loader.transact,a.output,a.count,
                (lambda n:input(f'Pose {n+1}: hold target still, then press Enter: ')) if a.interactive else None)
        if a.resume:
            loader.transact(port,7)


if __name__=='__main__':main()
