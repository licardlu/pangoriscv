"""Restore the accepted full application in SRAM and load its paired model."""
import argparse
from contextlib import redirect_stdout
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / "project/trash_sorting"


class Tee:
    def __init__(self, *streams):
        self.streams = streams

    def write(self, value):
        for stream in self.streams:
            stream.write(value)
        self.flush()

    def flush(self):
        for stream in self.streams:
            stream.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="Application UART, not JTAG FTDI")
    parser.add_argument("--pds", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path, help="New evidence directory")
    args = parser.parse_args()
    release = PROJECT / "bitstream/full_27mhz"
    acceptance = json.loads((release / "manifest.json").read_text(encoding="utf8"))
    bit = release / "yolo_camera_top.sbit"
    bit_sha = hashlib.sha256(bit.read_bytes()).hexdigest()
    if (bit_sha != acceptance["bitstream_sha256"] or not acceptance["timing_pass"]
            or acceptance["peripheral_test_mode"] != 0
            or acceptance["servo_reversed_mask"] != "1111"):
        raise ValueError("Release identity or acceptance mismatch")
    spec = importlib.util.spec_from_file_location(
        "board_loader", ROOT / "extensions/yolo/scripts/board_loader.py")
    loader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loader)
    model, blob = loader.load_deployment(PROJECT / "source/yolo/model")
    model_sha = hashlib.sha256(blob).hexdigest()
    if model_sha != acceptance["model_sha256"]:
        raise ValueError("The model does not match the accepted source build")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    state = dict(started_utc=datetime.now(timezone.utc).isoformat(),
                 bitstream_sha256=bit_sha, model_sha256=model_sha,
                 model_crc32=f"0x{model['blob_crc32']:08x}", port=args.port,
                 board_programmed=False, model_loaded=False,
                 model_crc_verified=False, camera_inference_pass=False,
                 autonomous_started=False, autonomous_frame_received=False,
                 physical_full_application_verified=False)

    def save():
        (out / "result.json").write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf8")

    save()
    try:
        subprocess.run([
            sys.executable, str(ROOT / "extensions/yolo/scripts/program_board.py"),
            "--sbit", str(bit), "--out", str(out / "jtag"),
            "--pds", str(args.pds.resolve())], check=True)
        state["board_programmed"] = True
        save()
        import serial
        with (out / "uart.log").open("w", encoding="utf8") as log:
            with redirect_stdout(Tee(sys.stdout, log)):
                with serial.Serial(args.port, 115200, timeout=600, write_timeout=10) as port:
                    # A valid reply proves the newly loaded CPU firmware is serving UART.
                    loader.transact(port, 8)
                    print("FIRMWARE_UART_REPLY_PASS", flush=True)
                    started = time.monotonic()
                    loader.write_image(port, model["blob_base"], blob)
                    state.update(model_loaded=True,
                                 model_upload_seconds=time.monotonic() - started)
                    save()
                    loader.transact(port, 5)
                    state["model_crc_verified"] = True
                    print("DEVICE_MODEL_CRC_PASS", state["model_crc32"], flush=True)
                    save()
                    started = time.monotonic()
                    detections = loader.parse_detections(loader.transact(port, 6))
                    state.update(camera_inference_pass=True, detections=detections,
                                 camera_request_seconds=time.monotonic() - started)
                    print("CAMERA_INFERENCE_PASS", json.dumps(detections), flush=True)
                    save()
                    loader.transact(port, 7)
                    state["autonomous_started"] = True
                    save()
                    header = loader.read_exact(port, 8)
                    length = int.from_bytes(header[5:7], "little")
                    if length > 1024:
                        raise ValueError("Oversized autonomous reply")
                    raw = loader.parse_reply(header + loader.read_exact(port, length + 4))
                    state.update(autonomous_frame_received=True,
                                 autonomous_detections=loader.parse_detections(raw))
                    print("AUTONOMOUS_CAMERA_FRAME_PASS",
                          json.dumps(state["autonomous_detections"]), flush=True)
        state["completed_utc"] = datetime.now(timezone.utc).isoformat()
        save()
    except Exception as error:
        state["error"] = str(error)
        save()
        raise


if __name__ == "__main__":
    main()
