"""Experimental SRAM bring-up of a setup-failing candidate, never release acceptance.

This separate path deliberately leaves acceptance.json and the release tools
unchanged. It requires complete final STA, passing hold/recovery/removal/pulse
width summaries, matching frozen sources, and passing RTL checks. Observations
at one board/temperature do not establish timing closure or reliability.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import struct
import sys
import time

from benchmark import assess_runs, load_deployment, parse_detections, parse_profile, validate_profile
from build import HZ, YOLO, module, sha, tool_config, write_json
from board_loader import transact, write_image


def diagnostic_candidate(folder):
    timing_path = folder/'report_timing/yolo_camera_top.rtr'
    timing = timing_path.read_text(errors='replace')
    if 'Timing analysis mode : multi corner' not in timing:
        raise ValueError('Complete final multi-corner STA required')
    for corner in ('Slow', 'Fast'):
        for kind in ('Hold', 'Recovery', 'Removal', 'Minimum Pulse Width'):
            match = re.search(re.escape(f'{kind} Summary({corner} Corner):') +
                              r'(.*?)(?=\n\s*\w[^\n]*Summary\(|\nSlow Corner|\nFast Corner|\Z)', timing, re.S)
            if not match:
                raise ValueError(f'Missing {corner} {kind} summary')
            for line in match[1].splitlines():
                values = line.split()
                if len(values) < 5:
                    continue
                try:
                    slack, total, failing = float(values[-4]), float(values[-3]), int(values[-2])
                except ValueError:
                    continue
                if slack < 0 or total < 0 or failing:
                    raise ValueError(f'Bring-up refuses {corner} {kind} violation: {line.strip()}')
    inputs = json.loads((folder/'inputs.json').read_text(encoding='utf-8'))
    for entry in inputs['snapshot']:
        if sha(folder/entry['path']) != entry['sha256']:
            raise ValueError('Frozen input changed: '+entry['path'])
    checks = json.loads((folder/'checks/result.json').read_text(encoding='utf-8'))
    if len(checks['cases']) != 8 or not all(c['passed'] for c in checks['cases']):
        raise ValueError('All eight frozen-source RTL checks required')
    bits = list((folder/'generate_bitstream').glob('*.sbit'))
    if len(bits) != 1:
        raise ValueError('Expected exactly one SRAM bitstream')
    return dict(experimental=True, release_accepted=False, timing_pass=False,
                reason='Final setup timing is not closed; board observations are diagnostic only',
                cpu_hz=HZ, bitstream=str(bits[0]), bitstream_sha256=sha(bits[0]),
                timing_report_sha256=sha(timing_path), inputs_sha256=sha(folder/'inputs.json'))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--implementation', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--port', required=True)
    p.add_argument('--experimental-setup-only', action='store_true', required=True)
    p.add_argument('--program', action='store_true')
    p.add_argument('--upload-model', action='store_true')
    p.add_argument('--baseline', action='store_true')
    p.add_argument('--frames', type=int, default=10)
    p.add_argument('--keep-running', action='store_true')
    p.add_argument('--camera-preview', action='store_true',
                   help='Save a sampled camera input before continuous inference; not an HDMI capture')
    a = p.parse_args()
    if a.frames < 3:
        p.error('Measure at least three frames')
    a.implementation = a.implementation.resolve()
    candidate = diagnostic_candidate(a.implementation)
    model, blob = load_deployment(YOLO/'gen/integration/packed')
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    shutil.copy2(a.implementation/'report_timing/yolo_camera_top.rtr', a.out/'final_timing.rtr')
    state = dict(candidate=candidate, state='starting', runs=[], release_accepted=False,
                 hdmi_visually_verified=False, port=a.port, frames=0,
                 model_sha256=sha(YOLO/'gen/integration/packed/model.bin'))

    def save():
        state['updated_utc'] = datetime.now(timezone.utc).isoformat()
        write_json(a.out/'result.json', state)

    save()
    try:
        if a.program:
            legacy = module(YOLO/'scripts/program_board.py', 'experimental_jtag')
            legacy.TOOLS = Path(tool_config()['pds']).parent
            previous = sys.argv
            try:
                sys.argv = ['program_board.py', '--sbit', candidate['bitstream'],
                            '--out', str(a.out/'program')]
                legacy.main()
            finally:
                sys.argv = previous
            time.sleep(3)
        import serial
        with serial.Serial(a.port, 115200, timeout=10, write_timeout=10) as port:
            port.reset_input_buffer()
            for command, value in ((10, 1), (9, 63)):
                if transact(port, command, value) != struct.pack('<I', value):
                    raise ValueError(f'Firmware command {command} not acknowledged')
            state['state'] = 'firmware_responding'
            save()
            print('EXPERIMENTAL_FIRMWARE_RESPONDING; setup timing remains failed', flush=True)
            port.timeout = 240
            if a.upload_model:
                state['state'] = 'uploading_model'
                save()
                write_image(port, model['blob_base'], blob)
            transact(port, 5)
            state['state'] = 'measuring'
            save()
            for mode in ([0, 1] if a.baseline else [1]):
                if transact(port, 10, mode) != struct.pack('<I', mode):
                    raise ValueError('Camera mode not acknowledged')
                for index in range(a.frames+1):
                    start = time.monotonic()
                    raw = transact(port, 6)
                    elapsed = time.monotonic()-start
                    profile_raw = transact(port, 8)
                    profile = parse_profile(profile_raw, model)
                    seconds = validate_profile(profile, elapsed, len(model['ops']))
                    (a.out/f'mode{mode}_frame{index:02}.bin').write_bytes(raw)
                    (a.out/f'mode{mode}_frame{index:02}_profile.bin').write_bytes(profile_raw)
                    state['runs'].append(dict(camera_fast=mode, warmup=index == 0,
                        wall_seconds=elapsed, device_seconds=seconds,
                        profile=profile, detections=parse_detections(raw)))
                    save()
                    print(f'EXPERIMENT mode={mode} frame={index} seconds={elapsed:.6f}', flush=True)
            state['latency_observation'] = assess_runs(state['runs'], a.frames, 1.2)
            if a.camera_preview:
                from camera_preview import sample_camera
                state['state'] = 'sampling_camera'
                save()
                state['camera_preview'] = sample_camera(port, model, a.out,
                                                        state['runs'][-1]['detections'])
            state['state'] = 'continuous' if a.keep_running else 'measured'
            save()
            with (a.out/'live.jsonl').open('a', encoding='utf-8', buffering=1) as log:
                while a.keep_running and not (a.out/'STOP').exists():
                    start = time.monotonic()
                    raw = transact(port, 6)
                    elapsed = time.monotonic()-start
                    detections = parse_detections(raw)
                    state['frames'] += 1
                    state.update(last_wall_seconds=elapsed, last_detections=detections)
                    log.write(json.dumps(dict(frame=state['frames'], wall_seconds=elapsed,
                                              detections=detections))+'\n')
                    save()
                    if state['frames'] == 1 or state['frames'] % 10 == 0:
                        print(f"EXPERIMENT LIVE frame={state['frames']} seconds={elapsed:.3f}", flush=True)
            if a.keep_running:
                state['state'] = 'stopped'
    except Exception as exc:
        state.update(state='failed', error=f'{type(exc).__name__}: {exc}')
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
