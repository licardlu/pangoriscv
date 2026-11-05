"""Start continuous camera inference and keep the board available for diagnostics.

Each iteration is a complete command-6 transaction. A stop file ends the host
loop after the current frame, leaving the FPGA's live video output running.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import struct
import subprocess
import sys
import time

from benchmark import (HZ, YOLO, load_deployment, parse_detections, parse_profile,
                       sha, transact, validate_profile, write_image, write_json)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--implementation', required=True, type=Path)
    p.add_argument('--port', required=True)
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--program', action='store_true', help='Program accepted SRAM image first')
    p.add_argument('--upload-model', action='store_true', help='Required after FPGA/DDR reset')
    p.add_argument('--frames', type=int, default=0, help='0 runs until STOP file or Ctrl+C')
    a = p.parse_args()
    if a.frames < 0:
        p.error('--frames must be nonnegative')
    a.implementation = a.implementation.resolve()
    accepted = json.loads((a.implementation/'acceptance.json').read_text(encoding='utf-8'))
    bitstream = Path(accepted.get('bitstream') or '')
    if (not accepted.get('timing_pass') or accepted.get('cpu_hz') != HZ or
            not bitstream.is_file() or sha(bitstream) != accepted.get('bitstream_sha256')):
        p.error('Use a matching bitstream with passed final timing')
    model, blob = load_deployment(YOLO/'gen/integration/packed')
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    state = dict(state='starting', port=a.port, frames=0,
                 implementation=str(a.implementation),
                 bitstream_sha256=accepted['bitstream_sha256'], cpu_hz=HZ,
                 hdmi_visually_verified=False,
                 identity_note='Host image recorded; firmware cannot attest loaded bitstream')

    def save():
        state['updated_utc'] = datetime.now(timezone.utc).isoformat()
        write_json(a.out/'status.json', state)

    save()
    try:
        if a.program:
            subprocess.run([sys.executable, str(Path(__file__).with_name('program.py')),
                '--implementation', str(a.implementation), '--out', str(a.out/'program')], check=True)
            time.sleep(3)  # Camera, HDMI controller and DDR calibration settle.
        import serial
        with serial.Serial(a.port, 115200, timeout=120, write_timeout=10) as port:
            # Check the running protocol before spending minutes uploading weights.
            if transact(port, 10, 1) != struct.pack('<I', 1):
                raise ValueError('Running firmware did not accept YOLO120 camera stream mode')
            if transact(port, 9, 63) != struct.pack('<I', 63):
                raise ValueError('Running firmware did not accept optimization flags')
            if a.upload_model:
                state['state'] = 'uploading_model'
                save()
                write_image(port, model['blob_base'], blob)
            state['state'] = 'verifying_model'
            save()
            transact(port, 5)
            state['state'] = 'running'
            save()
            with (a.out/'frames.jsonl').open('a', encoding='utf-8', buffering=1) as log:
                while not (a.out/'STOP').exists() and (not a.frames or state['frames'] < a.frames):
                    started = time.monotonic()
                    raw = transact(port, 6)
                    elapsed = time.monotonic()-started
                    detections = parse_detections(raw)
                    profile = parse_profile(transact(port, 8), model)
                    device_seconds = validate_profile(profile, elapsed, len(model['ops']))
                    state['frames'] += 1
                    frame = dict(frame=state['frames'], wall_seconds=elapsed,
                                 device_seconds=device_seconds, detections=detections,
                                 profile=profile)
                    log.write(json.dumps(frame, ensure_ascii=False)+'\n')
                    state.update(last_wall_seconds=elapsed, last_device_seconds=device_seconds,
                                 last_detections=detections)
                    save()
                    if state['frames'] == 1 or state['frames'] % 10 == 0:
                        print(f"LIVE frame={state['frames']} seconds={elapsed:.3f} "
                              f"detections={len(detections)}", flush=True)
            state['state'] = 'stopped'
    except KeyboardInterrupt:
        state['state'] = 'interrupted'
    except Exception as exc:
        state.update(state='failed', error=f'{type(exc).__name__}: {exc}')
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
