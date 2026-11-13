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
NAMES = [(1, "PROMPT.WAV"), (2, "CORRECT.WAV"), (3, "WRONG.WAV")]


def convert(path):
    with wave.open(str(path), "rb") as wav:
        if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (1, 2, 48000):
            raise ValueError(f"Expected mono PCM16/48000: {path}")
        data = wav.readframes(wav.getnframes())
    pcm = struct.unpack("<" + "h" * (len(data) // 2), data)
    taps = []
    for n in range(-31, 32):
        fc = 7000 / 48000
        sinc = 2 * fc if n == 0 else math.sin(2 * math.pi * fc * n) / (math.pi * n)
        window = 0.54 + 0.46 * math.cos(math.pi * n / 31)
        taps.append(sinc * window)
    scale = sum(taps)
    taps = [x / scale for x in taps]
    result = []
    for center in range(0, len(pcm), 3):
        value = sum(pcm[i] * taps[k] for k, i in enumerate(range(center - 31, center + 32))
                    if 0 <= i < len(pcm))
        sample = max(-128, min(127, round(value / 256)))
        result.append(sample & 255)
    return result


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    samples = []
    entries = []
    for asset_id, name in NAMES:
        path = SOURCE / name
        clip = convert(path)
        entries.append({"asset_id": asset_id, "source": name,
                        "offset": len(samples), "samples": len(clip),
                        "duration_seconds": len(clip) / 16000,
                        "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        samples.extend(clip)
    output = "".join(f"{x:02x}\n" for x in samples)
    (DEST / "voice_pcm8.hex").write_text(output, encoding="ascii")
    split_rom(DEST / "voice_pcm8.hex")
    metadata = {"format": "signed PCM8, mono, 16000 Hz; repeat x3 at 48000 Hz",
                "rom_bytes": len(samples), "assets": entries,
                "hex_sha256": hashlib.sha256(output.encode("ascii")).hexdigest()}
    (DEST / "voice_rom_manifest.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
