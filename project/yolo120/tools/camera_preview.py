"""Read a frozen, sampled camera tensor through the existing UART DDR reader.

This is the normalized model input after RGB565 sampling, not an HDMI capture.
Run after model upload. No firmware changes or framebuffer allocation needed.
"""
import argparse
import json
from pathlib import Path
import struct
import time

from benchmark import HZ, YOLO, load_deployment, parse_detections, parse_profile
from benchmark import sha, transact, validate_profile, write_json


def sample_camera(port, model, out, detections, step=4):
    """Read the frozen input, preserving raw bytes beside the reconstructed PNG."""
    from PIL import Image, ImageDraw
    raw_pixels = bytearray()
    image = Image.new('RGB', (320//step, 180//step))
    try:
        for y in range(0, 180, step):
            for x in range(0, 320, step):
                address = model['tensors'][0]['address']+((y+70)*320+x)*8
                word = transact(port, 2, address)
                if len(word) != 8 or any(word[3:]) or any(v > 127 for v in word[:3]):
                    raise ValueError('Readback is not an RGB int8 input tensor')
                raw_pixels.extend(word)
                image.putpixel((x//step, y//step),
                               tuple((v*255+63)//127 for v in word[:3]))
            if y % (step*10) == 0:
                print(f'camera tensor row {y}/180', flush=True)
        image.save(out/'camera_sample.png')
        canvas = image.resize((640, 360), Image.Resampling.NEAREST)
        draw = ImageDraw.Draw(canvas)
        for d in detections:
            box = [v/2 for v in d['box']]
            draw.rectangle(box, outline='#00ff70', width=2)
            draw.text((box[0], max(0, box[1]-12)),
                      f"{d['category']} {d['score']:.3f}", fill='#00ff70')
        canvas.save(out/'camera_detections.png')
        return dict(sample_size=list(image.size), source='Frozen normalized model input; not HDMI capture',
                    extrema=image.getextrema(), unique_colors=len(set(image.getdata())))
    finally:
        (out/'sampled_tensor.bin').write_bytes(raw_pixels)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port', required=True)
    p.add_argument('--implementation', required=True, type=Path)
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--step', type=int, choices=(1, 2, 4), default=4,
                   help='4 reads an 80x45 sample; 1 reads all 320x180 camera pixels')
    a = p.parse_args()
    implementation = json.loads((a.implementation/'acceptance.json').read_text(encoding='utf-8'))
    bitstream = Path(implementation.get('bitstream') or '')
    if (not implementation.get('timing_pass') or implementation.get('cpu_hz') != HZ or
            not bitstream.is_file() or sha(bitstream) != implementation.get('bitstream_sha256')):
        p.error('Use the exact programmed candidate with passed final STA and matching bitstream')
    import serial
    model, _ = load_deployment(YOLO/'gen/integration/packed')
    a.out.mkdir(parents=True, exist_ok=False)
    report = dict(passed=False, implementation=implementation, step=a.step,
        source='Frozen model input: normalized RGB565 camera samples, excluding letterbox',
        note='Not an HDMI capture or accuracy score; normalized int8 values expanded for viewing. '
             'Host candidate identity is recorded; firmware cannot attest loaded bitstream.')
    try:
        with serial.Serial(a.port, 115200, timeout=240, write_timeout=10) as port:
            transact(port, 5)  # Verify the already-uploaded model in DDR.
            if transact(port, 9, 63) != struct.pack('<I', 63):
                raise ValueError('Optimization options not accepted')
            if transact(port, 10, 1) != struct.pack('<I', 1):
                raise ValueError('Camera stream mode not accepted')
            started = time.monotonic()
            raw = transact(port, 6)
            elapsed = time.monotonic()-started
            profile_raw = transact(port, 8)
            profile = parse_profile(profile_raw, model)
            validate_profile(profile, elapsed, len(model['ops']))
            detections = parse_detections(raw)
            (a.out/'detections.bin').write_bytes(raw)
            (a.out/'profile.bin').write_bytes(profile_raw)
            sampled = sample_camera(port, model, a.out, detections, a.step)
            report.update(passed=True, detections=detections, profile=profile,
                          **sampled, wall_seconds=elapsed)
    except Exception as exc:
        report['error'] = f'{type(exc).__name__}: {exc}'
        raise
    finally:
        write_json(a.out/'result.json', report)
    print('CAMERA_TENSOR_PREVIEW_SAVED; no recognition accuracy claim')


if __name__ == '__main__':
    main()
