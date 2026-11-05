"""Split a PCM8 hex ROM into native BRAM banks, preserving every byte.

PDS requires readmemh directly into each memory. Each output contains exactly
2048 bytes; only the last bank is padded with zero. Default input is the real
three-clip ROM. Pass another hex path for test fixtures.
"""
from pathlib import Path
import argparse
import hashlib
import json

BANK_SIZE = 2048


def split_rom(path):
    path = Path(path)
    samples = bytes(int(token, 16) for token in path.read_text(encoding="ascii").split())
    bank_count = (len(samples) + BANK_SIZE - 1) // BANK_SIZE
    if bank_count > 100:
        raise ValueError("RTL bank filenames support bank00 through bank99")
    banks = []
    for index in range(bank_count):
        content = samples[index * BANK_SIZE:(index + 1) * BANK_SIZE].ljust(BANK_SIZE, b"\0")
        output = Path(f"{path}.bank{index:02d}.hex")
        output.write_text("".join(f"{value:02x}\n" for value in content), encoding="ascii")
        banks.append(content)
    assert b"".join(banks)[:len(samples)] == samples
    return {"source": str(path), "samples": len(samples), "bank_size": BANK_SIZE,
            "bank_count": bank_count, "pcm_sha256": hashlib.sha256(samples).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[1] / "assets/audio_rom/voice_pcm8.hex")
    print(json.dumps(split_rom(parser.parse_args().rom), indent=2))
