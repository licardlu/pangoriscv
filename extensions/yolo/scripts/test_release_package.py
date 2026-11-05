"""Release-package contract checks.

The package must be self-contained and must prove that the firmware/model
metadata and bitstream hashes are the exact files being handed off.
"""
import json
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path
import zlib


ROOT = Path(__file__).resolve().parents[1]
PACKAGER = ROOT / "scripts" / "package_release.py"
sys.path.insert(0, str(ROOT / "scripts"))
from board_loader import load_deployment


def run(*args):
    return subprocess.run(
        [sys.executable, str(PACKAGER), *map(str, args)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def main():
    with tempfile.TemporaryDirectory(prefix="ai_release_test_") as tmp:
        package_dir = Path(tmp) / "loader_package"
        package_dir.mkdir()
        blob = b"01234567"
        (package_dir / "model.bin").write_bytes(blob)
        (package_dir / "memory_map.json").write_text(json.dumps({
            "blob_length": len(blob),
            "blob_crc32": zlib.crc32(blob),
            "blob_sha256": hashlib.sha256(blob).hexdigest(),
        }))
        loaded_map, loaded_blob = load_deployment(package_dir)
        if loaded_blob != blob or loaded_map["blob_length"] != len(blob):
            raise SystemExit("package loader did not return the exact model")
        (package_dir / "model.bin").write_bytes(blob + b"x")
        try:
            load_deployment(package_dir)
        except ValueError:
            pass
        else:
            raise SystemExit("package loader accepted a corrupted model")

        out = Path(tmp) / "release"
        result = run("--out", out)
        if result.returncode != 0:
            raise SystemExit(result.stdout + result.stderr)
        verify = run("--verify", "--out", out)
        if verify.returncode != 0:
            raise SystemExit(verify.stdout + verify.stderr)
        manifest = json.loads((out / "release_manifest.json").read_text())
        required = {
            "bitstream.sbit",
            "firmware.bin",
            "firmware.hex",
            "model.bin",
            "memory_map.json",
            "camera.fdc",
            "board_loader.py",
            "loader_requirements.txt",
            "SHA256SUMS.txt",
            "BOARD_TEST.md",
        }
        actual = {path.name for path in out.iterdir() if path.is_file()}
        missing = required - actual
        if missing:
            raise SystemExit(f"missing release files: {sorted(missing)}")
        if manifest["board_verified"] is not False:
            raise SystemExit("release must not claim board verification")
        if manifest["timing_pass"] is not True:
            raise SystemExit("release must carry timing_pass=true")
        copied_loader = subprocess.run(
            [
                sys.executable,
                str(out / "board_loader.py"),
                "--check",
                "--package-dir",
                str(out),
            ],
            cwd=out,
            capture_output=True,
            text=True,
            check=False,
        )
        if copied_loader.returncode or "LOADER_OFFLINE_PASS" not in copied_loader.stdout:
            raise SystemExit(copied_loader.stdout + copied_loader.stderr)
        damaged = out / "model.bin"
        original = damaged.read_bytes()
        damaged.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
        rejected = run("--verify", "--out", out)
        if rejected.returncode == 0:
            raise SystemExit("release verifier accepted a modified model")
        overwrite = run("--out", out)
        if overwrite.returncode == 0 or "refusing to overwrite" not in (
            overwrite.stdout + overwrite.stderr
        ):
            raise SystemExit("packager did not protect the existing package")
        print("RELEASE_PACKAGE_PASS")


if __name__ == "__main__":
    main()
