"""Convert the three existing PCM16/48 kHz prompts to a compact FPGA ROM.

Only Python standard-library modules are required.  A 63-tap windowed-sinc
low-pass filter precedes 3:1 decimation.  Signed PCM8 is expanded to PCM16
inside RTL and repeated three times for a 48 kHz I2S stream.  This is an
intentional speech-storage tradeoff, not a bit-exact copy of the source WAV.
"""
import hashlib
import json
import math
import pathlib
import struct
import wave
from make_voice_banks import split_rom

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "audio"
DEST = ROOT / "assets" / "audio_rom"
NAMES = [(1, "PROMPT.WAV", 16000), (2, "CORRECT.WAV", 16000),
         (3, "WRONG.WAV", 16000), (4, "KITCHEN.WAV", 12000),
         (5, "HAZARDOUS.WAV", 12000), (6, "OTHER.WAV", 12000),
         (7, "RECYCLABLE.WAV", 12000)]


def convert(path, sample_hz=16000, trim_silence=False):
    if sample_hz not in (12000,16000):
        raise ValueError('Unsupported speech rate')
    with wave.open(str(path), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (1, 2, 48000):
            raise ValueError(f"Expected mono PCM16/48000: {path}")
        data = wav.readframes(wav.getnframes())
    pcm = struct.unpack("<" + "h" * (len(data) // 2), data)
    if trim_silence:
        active = [i for i,value in enumerate(pcm) if abs(value)>200]
        if not active:
            raise ValueError('Silent category asset')
        pcm = pcm[max(0,active[0]-3840):min(len(pcm),active[-1]+3841)]
    taps = []
    for n in range(-31, 32):
        fc = (sample_hz/2-1000) / 48000
        sinc = 2 * fc if n == 0 else math.sin(2 * math.pi * fc * n) / (math.pi * n)
        window = 0.54 + 0.46 * math.cos(math.pi * n / 31)
        taps.append(sinc * window)
    scale = sum(taps)
    taps = [x / scale for x in taps]
    result = []
    for center in range(0, len(pcm), 48000//sample_hz):
        value = sum(pcm[i] * taps[k] for k, i in enumerate(range(center - 31, center + 32))
                    if 0 <= i < len(pcm))
        sample = max(-128, min(127, round(value / 256)))
        result.append(sample & 255)
    return result


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    samples = []
    entries = []
    for asset_id, name, sample_hz in NAMES:
        path = SOURCE / name
        clip = convert(path, sample_hz, trim_silence=asset_id>=4)
        entries.append({"asset_id": asset_id, "source": name,
                        "offset": len(samples), "samples": len(clip),
                        "sample_rate_hz": sample_hz, "repeat_at_48000": 48000//sample_hz,
                        "duration_seconds": len(clip) / sample_hz,
                        "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        samples.extend(clip)
    output = "".join(f"{x:02x}\n" for x in samples)
    (DEST / "voice_pcm8.hex").write_text(output, encoding="ascii")
    split_rom(DEST / "voice_pcm8.hex")
    metadata = {"format": "signed PCM8 mono; prompts 16kHz x3, categories 12kHz x4 at 48kHz",
                "rom_bytes": len(samples), "assets": entries,
                "hex_sha256": hashlib.sha256(output.encode("ascii")).hexdigest()}
    (DEST / "voice_rom_manifest.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
