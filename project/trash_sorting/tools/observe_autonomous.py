"""Receive autonomous replies without issuing commands or changing the game."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'extensions/yolo/scripts'))
from board_loader import parse_reply, parse_detections


class Stream:
    def __init__(self):
        self.buffer = bytearray()
        self.synced = False
        self.initial_skipped_bytes = 0
        self.after_sync_skipped_bytes = 0
        self.invalid_frames = 0

    def feed(self, data):
        self.buffer.extend(data)
        frames = []
        def discard(n):
            if self.synced: self.after_sync_skipped_bytes += n
            else: self.initial_skipped_bytes += n
            del self.buffer[:n]
        while len(self.buffer) >= 8:
            pos = self.buffer.find(b'YAR1')
            if pos < 0:
                discard(len(self.buffer)-3); break
            if pos:
                discard(pos)
            if len(self.buffer) < 8: break
            length = struct.unpack_from('<H', self.buffer, 5)[0]
            if self.buffer[7] or length > 1024:
                self.invalid_frames += 1; discard(1); continue
            total = length+12
            if len(self.buffer) < total: break
            packet = bytes(self.buffer[:total])
            try: raw = parse_reply(packet)
            except (ValueError, RuntimeError):
                self.invalid_frames += 1; discard(1); continue
            del self.buffer[:total]
            self.synced = True
            frames.append(raw)
        return frames


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port', required=True)
    p.add_argument('--restore-evidence', type=Path, required=True)
    p.add_argument('--until-utc', required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    source = a.restore_evidence/'result.json'
    restore = json.loads(source.read_text(encoding='utf8'))
    if not all(restore.get(k) for k in ('board_programmed', 'model_crc_verified', 'camera_inference_pass', 'autonomous_started')):
        raise ValueError('Completed accepted restore required before passive observation')
    deadline = datetime.fromisoformat(a.until_utc)
    if deadline.tzinfo is None or deadline <= datetime.now(timezone.utc):
        raise ValueError('Future timezone-aware observation deadline required')
    a.out.mkdir(parents=True, exist_ok=False)
    stream = Stream(); started = time.monotonic(); last = None; intervals = []
    state = dict(status='OBSERVING', port=a.port, started_utc=datetime.now(timezone.utc).isoformat(),
                 deadline_utc=deadline.isoformat(), passive_only=True, bytes_written=0,
                 bitstream_sha256=restore['bitstream_sha256'], model_sha256=restore['model_sha256'],
                 restore_result_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                 frames=0, empty_frames=0, selected_frames=0, detection_payload_errors=0,
                 limits=['Autonomous UART arrival intervals, not device stage timing',
                         'Target selection can pause subsequent frames while awaiting answer/open/hold/close',
                         'No remote proof of screen appearance, object correctness or physical servo motion'])
    def save():
        state.update(elapsed_seconds=time.monotonic()-started, initial_skipped_bytes=stream.initial_skipped_bytes,
                     after_sync_skipped_bytes=stream.after_sync_skipped_bytes, invalid_frames=stream.invalid_frames,
                     pending_tail_bytes=len(stream.buffer), observed_until_utc=datetime.now(timezone.utc).isoformat())
        if intervals:
            state.update(interarrival_mean_seconds=sum(intervals)/len(intervals),
                         interarrival_max_seconds=max(intervals), interarrival_samples=len(intervals))
        (a.out/'result.json').write_text(json.dumps(state, indent=2), encoding='utf8')
    save()
    try:
        import serial
        with serial.Serial(a.port, 115200, timeout=1, write_timeout=1) as port, (a.out/'frames.jsonl').open('w', encoding='utf8') as log:
            next_save = time.monotonic()+30
            while datetime.now(timezone.utc) < deadline:
                data = port.read(max(1, port.in_waiting))
                for raw in stream.feed(data):
                    now = time.monotonic()
                    try: detections = parse_detections(raw, restore['classes'])
                    except ValueError:
                        state['detection_payload_errors'] += 1; continue
                    interval = now-last if last is not None else None
                    if interval is not None: intervals.append(interval)
                    last = now
                    state['frames'] += 1
                    state['empty_frames' if not detections else 'selected_frames'] += 1
                    state['last_frame_utc'] = datetime.now(timezone.utc).isoformat()
                    log.write(json.dumps(dict(index=state['frames'], utc=state['last_frame_utc'],
                                             elapsed_seconds=now-started, interval_seconds=interval, detections=detections))+'\n')
                    log.flush()
                if time.monotonic() >= next_save:
                    save(); next_save = time.monotonic()+30
                    print('PASSIVE_OBSERVE frames='+str(state['frames'])+' invalid='+str(stream.invalid_frames)+
                          ' payload_errors='+str(state['detection_payload_errors']), flush=True)
        state['status'] = 'OBSERVATION_COMPLETED'
    except Exception as exc:
        state.update(status='OBSERVATION_FAILED', error=str(exc)); raise
    finally: save()


if __name__ == '__main__': main()
