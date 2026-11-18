"""Restore the accepted full application in SRAM and load its paired model."""
import argparse
from contextlib import redirect_stdout
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import struct
import statistics
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
    parser.add_argument("--release-dir", type=Path, default=PROJECT / "bitstream/full_27mhz",
                        help="Accepted candidate folder with bitstream and passing manifest")
    parser.add_argument('--fixtures',type=Path,help='Optional prechecked numerical fixtures before autonomous mode')
    parser.add_argument('--measure-frames',type=int,default=0,help='Camera timing frames after one warmup, before autonomous mode')
    parser.add_argument('--probe-frames',type=int,default=0,
                        help='Diagnostic camera frames without committing quizzes; requires cmd12 release')
    parser.add_argument('--collect-profile',action='store_true',help='Collect stage/operator cycles for each timed frame')
    parser.add_argument('--verify-input',action='store_true',help='Compare legacy/stream full input CRC on one frozen camera snapshot')
    parser.add_argument('--leave-idle',action='store_true',
                        help='After non-committing checks start autonomous service but retain startup animation for manual key testing')
    parser.add_argument('--verify-stereo-pair',action='store_true',
                        help='Read complete frozen left/right snapshots and verify return to RGB via --verify-input; no distance calibration claim')
    parser.add_argument('--initial-uart-timeout', type=float, default=30,
                        help='Bound the first read-only firmware reply before allowing model writes')
    parser.add_argument('--experimental-timing-failure', action='store_true',
                        help='User-authorized SRAM experiment; retain failing STA status in all evidence')
    parser.add_argument('--reuse-jtag-evidence',type=Path,
                        help='Recover UART after USB-only reconnect without reconfiguring; reuse an exact-bit verified JTAG evidence directory')
    args = parser.parse_args()
    if not 5 <= args.initial_uart_timeout <= 120:
        parser.error('--initial-uart-timeout must be 5..120 seconds')
    release = args.release_dir.resolve()
    acceptance = json.loads((release / "manifest.json").read_text(encoding="utf8"))
    if args.leave_idle and not acceptance.get('recognition_single_click'):
        raise ValueError('Idle handoff requires the single-click recognition firmware')
    if args.leave_idle and (args.measure_frames or not args.probe_frames):
        raise ValueError('Idle handoff requires non-committing probes and no committing frame measurements')
    if args.verify_stereo_pair and not args.verify_input:
        raise ValueError('Stereo pair verification must also verify the return to RGB input')
    if args.probe_frames < 0 or args.probe_frames > 100:
        raise ValueError('Probe frames must be 0..100')
    if args.probe_frames and acceptance.get('camera_probe_command') != 12:
        raise ValueError('This release does not support non-committing camera probes')
    if args.probe_frames and not args.collect_profile:
        raise ValueError('Camera probes require device stage profiles')
    bit = release / "yolo_camera_top.sbit"
    bit_sha = hashlib.sha256(bit.read_bytes()).hexdigest()
    timing_allowed = acceptance['timing_pass'] or (
        args.experimental_timing_failure and acceptance.get('experimental_timing_failure') is True)
    if (bit_sha != acceptance["bitstream_sha256"] or not timing_allowed
            or acceptance["peripheral_test_mode"] != 0
            or acceptance["servo_reversed_mask"] != "1111"):
        raise ValueError("Release identity or acceptance mismatch")
    spec = importlib.util.spec_from_file_location(
        "board_loader", ROOT / "extensions/yolo/scripts/board_loader.py")
    loader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loader)
    if args.collect_profile:
        sys.path.insert(0,str(ROOT/'extensions/yolo/scripts'))
        from board_perf import parse_profile
    # Bind restoration to the implemented snapshot, even while active sources
    # are being prepared for a later model. Published folders may also bundle it.
    frozen_model=Path(acceptance.get('source_build',''))/'input/yolo/model'
    model_folder=release/'model'
    if not (model_folder/'model.bin').is_file():
        model_folder=frozen_model if (frozen_model/'model.bin').is_file() else PROJECT/'source/yolo/model'
    model, blob = loader.load_deployment(model_folder)
    model_sha = hashlib.sha256(blob).hexdigest()
    if model_sha != acceptance["model_sha256"]:
        raise ValueError("The model does not match the accepted source build")
    names=model.get('classes',loader.NAMES)
    if acceptance.get('raw_model_classes',6)!=len(names):
        raise ValueError('Release and UART class schema disagree')
    fixtures=None
    if args.fixtures:
        fixtures=json.loads((args.fixtures/'manifest.json').read_text(encoding='utf8'))
        if fixtures['model_sha256']!=model_sha:
            raise ValueError('Numerical fixtures belong to a different model')
        for case in fixtures['cases']:
            payload=(args.fixtures/case['file']).read_bytes()
            if len(payload)!=819200 or hashlib.sha256(payload).hexdigest()!=case['sha256']:
                raise ValueError('Invalid numerical fixture '+case['file'])
    # Check host dependencies before changing the running FPGA configuration.
    import serial
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    state = dict(started_utc=datetime.now(timezone.utc).isoformat(),
                 timing_pass=acceptance['timing_pass'],
                 experimental_timing_failure=not acceptance['timing_pass'],
                 bitstream_sha256=bit_sha, model_sha256=model_sha,
                 model_crc32=f"0x{model['blob_crc32']:08x}", port=args.port,
                 classes=list(names),four_bin_classes=acceptance.get('four_bin_classes',0),
                 model_folder=str(model_folder.resolve()),
                 board_programmed=False, model_loaded=False,
                 model_crc_verified=False, camera_inference_pass=False,
                 autonomous_started=False, autonomous_frame_received=False,
                 physical_full_application_verified=False)

    def save():
        (out / "result.json").write_text(
            json.dumps(state, ensure_ascii=False, indent=2), encoding="utf8")

    save()
    try:
        if args.reuse_jtag_evidence:
            jtag=json.loads((args.reuse_jtag_evidence/'result.json').read_text())
            if not (jtag.get('programming_requested') and jtag.get('trace_complete')
                    and jtag.get('configuration_active_verified') and jtag.get('sha256')==bit_sha
                    and jtag.get('configuration_status_hex')==['081ffca0','081ffca0']):
                raise ValueError('Previous JTAG evidence does not prove this exact configured bitstream')
            state.update(configuration_evidence_reused=str(args.reuse_jtag_evidence.resolve()),
                         jtag_programmed_this_attempt=False,
                         configuration_reuse_scope='USB-UART-only reconnect after this exact bit was programmed; no power cycle reported')
        else:
            subprocess.run([
                sys.executable, str(ROOT / "extensions/yolo/scripts/program_board.py"),
                "--sbit", str(bit), "--out", str(out / "jtag"),
                "--pds", str(args.pds.resolve())], check=True)
            state['jtag_programmed_this_attempt']=True
        state["board_programmed"] = True
        save()
        with (out / "uart.log").open("w", encoding="utf8") as log:
            with redirect_stdout(Tee(sys.stdout, log)):
                with serial.Serial(args.port, 115200, timeout=args.initial_uart_timeout, write_timeout=10) as port:
                    # A valid reply proves the newly loaded CPU firmware is serving UART.
                    loader.transact(port, 8)
                    port.timeout = 600
                    print("FIRMWARE_UART_REPLY_PASS", flush=True)
                    if args.leave_idle:
                        # Startup animation services SD/media between UART
                        # packets. Pause it during bulk maintenance transfers
                        # so a long media poll cannot overflow the RX FIFO.
                        paused=struct.unpack('<I',loader.transact(port,19,1))[0]
                        if paused!=1:raise ValueError('Media maintenance pause failed')
                        state['media_paused_for_transfer']=True
                        save();print('MEDIA_MAINTENANCE_PAUSE_PASS',flush=True)
                    if acceptance.get('benchmark_mode') == 'simulated_demo':
                        diagnostic = loader.transact(port, 15)
                        if len(diagnostic) != 16:
                            raise ValueError('Unexpected demo firmware diagnostic length')
                        benchmark_status, quiz_status, key_status, mode = struct.unpack('<4I', diagnostic)
                        state['demo_firmware_identity'] = dict(
                            mode=f'0x{mode:08x}', passed=mode == 0x44454d4f,
                            benchmark_status=benchmark_status, quiz_status=quiz_status,
                            key_status=key_status, is_real_measurement=False)
                        save()
                        if mode != 0x44454d4f:
                            raise ValueError('Loaded firmware does not identify as simulated DEMO')
                        print('DEMO_FIRMWARE_IDENTITY_PASS', flush=True)
                    started = time.monotonic()
                    loader.write_image(port, model["blob_base"], blob)
                    state.update(model_loaded=True,
                                 model_upload_seconds=time.monotonic() - started)
                    save()
                    loader.transact(port, 5)
                    state["model_crc_verified"] = True
                    print("DEVICE_MODEL_CRC_PASS", state["model_crc32"], flush=True)
                    save()
                    if acceptance.get('benchmark_mode') == 'simulated_demo':
                        boot = loader.transact(port, 20)
                        media = loader.transact(port, 16)
                        if len(boot) != 32 or len(media) != 36:
                            raise ValueError('Unexpected boot/media diagnostic length')
                        boot_words, media_words = struct.unpack('<8I', boot), struct.unpack('<9I', media)
                        if (boot_words[0] != 0x424f5431 or boot_words[1] != 1 or
                                boot_words[5] != len(blob) or boot_words[6] != model['blob_crc32'] or
                                boot_words[7] > 2 or media_words[0] != 0x4d454431 or
                                media_words[8] != acceptance['cpu_hz']):
                            raise ValueError('New application/model/media diagnostic identity mismatch')
                        state['application_diagnostics'] = dict(
                            passed=True, boot=list(boot_words), media=list(media_words),
                            tf_boot_error_before_uart=boot_words[3],
                            scope='Read-only firmware/model/media identity after verified UART load; no physical display or audio assessment')
                        save()
                        print('APPLICATION_DIAGNOSTIC_IDENTITY_PASS', flush=True)
                    if args.verify_stereo_pair:
                        gate=struct.unpack('<8I',loader.transact(port,23))
                        if gate[0]!=0x53444731 or gate[1] or gate[2]:
                            raise ValueError('Expected uncalibrated disabled automatic distance gate')
                        pair=struct.unpack('<9I',loader.transact(port,21))
                        if (pair[0]!=0x53545031 or pair[1:3]!=(320,180) or
                                pair[3]&31!=26 or pair[4]!=acceptance['cpu_hz'] or pair[8]!=pair[0]):
                            raise ValueError('Invalid complete stereo snapshot metadata')
                        packed=bytearray()
                        for offset in range(0,57600,128):
                            chunk=loader.transact(port,22,offset)
                            if len(chunk)!=256:raise ValueError('Truncated stereo snapshot')
                            packed.extend(chunk)
                        if loader.transact(port,22,0)!=packed[:256] or loader.transact(port,22,57472)!=packed[-256:]:
                            raise ValueError('Frozen stereo snapshot changed during read')
                        (out/'stereo_pair.bin').write_bytes(packed)
                        for side,name in enumerate(('left','right')):
                            data=bytes(packed[side::2])
                            (out/('stereo_'+name+'.pgm')).write_bytes(b'P5\n320 180\n255\n'+data)
                        difference=((pair[7]-pair[6]+0x80000000)&0xffffffff)-0x80000000
                        state['stereo_pair']=dict(passed=True,metadata=list(pair),
                            packed_sha256=hashlib.sha256(packed).hexdigest(),
                            left_distinct_levels=len(set(packed[0::2])),right_distinct_levels=len(set(packed[1::2])),
                            frame_start_skew_ms=difference*1000/pair[4],
                            timestamp_source='frame_start_common_clock',
                            exposure_sync_verified=False,physical_distance_verified=False,
                            distance_gate_enabled=False)
                        save();print('STEREO_PAIR_CAPTURE_PASS frame-start skew ms',state['stereo_pair']['frame_start_skew_ms'],flush=True)
                    if args.verify_input:
                        old,new,old_cycles,new_cycles=struct.unpack('<4I',loader.transact(port,11))
                        state['input_equivalence']=dict(legacy_crc32=f'0x{old:08x}',
                            stream_crc32=f'0x{new:08x}',passed=old==new,
                            legacy_seconds=old_cycles/acceptance['cpu_hz'],
                            stream_seconds=new_cycles/acceptance['cpu_hz'])
                        save()
                        if old!=new:
                            raise ValueError('Camera input equivalence failed')
                        print('CAMERA_INPUT_EQUIVALENCE_PASS',flush=True)
                    if fixtures:
                        state['numerical_fixtures']=[]
                        for case in fixtures['cases']:
                            loader.write_image(port,model['tensors'][0]['address'],
                                               (args.fixtures/case['file']).read_bytes())
                            metadata=struct.pack('<fffHH',case['ratio'],case['pad_x'],case['pad_y'],
                                                 case['width'],case['height'])
                            loader.transact(port,4,payload=metadata)
                            fixture_started=time.monotonic()
                            actual=loader.parse_detections(loader.transact(port,3),names)
                            fixture_seconds=time.monotonic()-fixture_started
                            expected=case['expected']
                            if len(actual)!=len(expected):
                                raise ValueError('Fixture detection count changed: '+case['file'])
                            for observed,reference in zip(actual,expected):
                                if (observed['category']!=names[reference['category']] or
                                    abs(observed['score']-reference['score'])>.003 or
                                    max(abs(x-y) for x,y in zip(observed['box'],reference['box']))>1.0):
                                    raise ValueError('Fixture inference differs from arithmetic oracle: '+case['file'])
                            checked=dict(id=case['id'],passed=True,detections=actual,
                                         inference_request_seconds=fixture_seconds)
                            if args.collect_profile:
                                profile=parse_profile(loader.transact(port,8),model)
                                if profile['cpu_hz']!=acceptance['cpu_hz'] or profile['flags']!=63:
                                    raise ValueError('Fixture timing clock/runtime flags mismatch')
                                if abs(sum(profile['stages'].values())-fixture_seconds)>max(.2,.05*fixture_seconds):
                                    raise ValueError('Fixture board/host timing mismatch')
                                checked['profile']=profile
                            state['numerical_fixtures'].append(checked)
                            save()
                            print('BOARD_NUMERICAL_FIXTURE_PASS',case['id'],json.dumps(actual),flush=True)
                    if args.probe_frames:
                        state['camera_probe_frames']=[]
                        for index in range(args.probe_frames+1):
                            started=time.monotonic()
                            picked=loader.parse_detections(loader.transact(port,12),names)
                            elapsed=time.monotonic()-started
                            raw_profile=loader.transact(port,8)
                            profile=parse_profile(raw_profile,model)
                            if profile['cpu_hz']!=acceptance['cpu_hz'] or profile['flags']!=63:
                                raise ValueError('Probe clock/runtime flags mismatch')
                            device_seconds=sum(profile['stages'].values())
                            if abs(device_seconds-elapsed)>max(.2,.05*elapsed):
                                raise ValueError('Probe device/host timing mismatch')
                            if any(op['cycles']<=0 for op in profile['operators']):
                                raise ValueError('Probe missing operator cycles')
                            (out/f'probe{index:02}_profile.bin').write_bytes(raw_profile)
                            item=dict(index=index,request_seconds=elapsed,device_seconds=device_seconds,
                                      seconds=max(elapsed,device_seconds),profile=profile,detections=picked)
                            if index:
                                state['camera_probe_frames'].append(item)
                            else:
                                state['camera_probe_warmup']=item
                            save()
                            print('CAMERA_DIAGNOSTIC_PROBE',index,item['seconds'],flush=True)
                        state['camera_probe_mean_seconds']=statistics.mean(x['seconds'] for x in state['camera_probe_frames'])
                        state['camera_probe_max_seconds']=max(x['seconds'] for x in state['camera_probe_frames'])
                        state['camera_probe_scope']='cmd12 real camera capture, full inference, decode and single-target selection after one warmup; NO display/quiz commit, voice, answer or servo; not full game latency'
                        save()
                    if args.leave_idle:
                        # cmd12 above checks real camera inference without creating
                        # a quiz. Keep the startup page for the user's first click.
                        paused=struct.unpack('<I',loader.transact(port,19,2))[0]
                        if paused:raise ValueError('Media playback resume failed')
                        state['media_resumed_after_transfer']=True
                        loader.transact(port,7)
                        boot_words=struct.unpack('<8I',loader.transact(port,20))
                        if boot_words[0]!=0x424f5431 or boot_words[2]!=1 or boot_words[7]!=2:
                            raise ValueError('Startup animation/autonomous handoff state mismatch')
                        state.update(camera_inference_pass=True,autonomous_started=True,
                            autonomous_frame_received=False,initial_page='animation',
                            first_question_pending=False,
                            autonomous_frame_note='Idle by design; single physical KEY0 click starts recognition',
                            handoff_boot_diagnostic=list(boot_words),
                            completed_utc=datetime.now(timezone.utc).isoformat())
                        save();print('IDLE_ANIMATION_HANDOFF_PASS single-click to recognize',flush=True)
                        return
                    started = time.monotonic()
                    detections = loader.parse_detections(loader.transact(port, 6),names)
                    state.update(camera_inference_pass=True, detections=detections,
                                 camera_request_seconds=time.monotonic() - started)
                    if args.collect_profile:
                        raw_profile=loader.transact(port,8)
                        profile=parse_profile(raw_profile,model)
                        if profile['cpu_hz']!=acceptance['cpu_hz'] or profile['flags']!=63:
                            raise ValueError('Initial camera clock/runtime flags mismatch')
                        device_seconds=sum(profile['stages'].values())
                        if abs(device_seconds-state['camera_request_seconds'])>max(.2,.05*state['camera_request_seconds']):
                            raise ValueError('Initial camera device/host timing mismatch')
                        (out/'camera_warmup_profile.bin').write_bytes(raw_profile)
                        state['camera_warmup_profile']=profile
                        state['camera_single_request_seconds']=max(device_seconds,state['camera_request_seconds'])
                        state['camera_single_request_scope']='One warmup request only; not a multi-frame average; excludes model loading, speech, answer and servo'
                    question_pending = bool(detections)
                    print("CAMERA_INFERENCE_PASS", json.dumps(detections), flush=True)
                    save()
                    if args.measure_frames:
                        state['camera_timing_seconds']=[]
                        if args.collect_profile:
                            state['camera_profiles']=[]
                        for index in range(args.measure_frames):
                            if question_pending:
                                state['camera_timing_stop_reason']='Selected target locked the quiz; no further camera command issued'
                                break
                            started=time.monotonic()
                            frame_detections = loader.parse_detections(loader.transact(port,6),names)
                            question_pending = question_pending or bool(frame_detections)
                            elapsed=time.monotonic()-started
                            if args.collect_profile:
                                raw_profile=loader.transact(port,8)
                                profile=parse_profile(raw_profile,model)
                                if profile['cpu_hz']!=acceptance['cpu_hz'] or profile['flags']!=63:
                                    raise ValueError('Timing profile clock/runtime flags mismatch')
                                device_seconds=sum(profile['stages'].values())
                                if abs(device_seconds-elapsed)>max(.2,.05*elapsed):
                                    raise ValueError('Board cycle timing and host time disagree')
                                if any(op['cycles']<=0 for op in profile['operators']):
                                    raise ValueError('Missing operator timing')
                                (out/f'frame{index+1:02}_profile.bin').write_bytes(raw_profile)
                                state['camera_profiles'].append(profile)
                                elapsed=max(elapsed,device_seconds)
                            state['camera_timing_seconds'].append(elapsed)
                            save()
                            print('CAMERA_TIMING_FRAME',index+1,elapsed,flush=True)
                        if state['camera_timing_seconds']:
                            state['camera_timing_mean_seconds']=statistics.mean(state['camera_timing_seconds'])
                        state['camera_timing_scope']='UART camera request/reply after one warmup; excludes model load, voice, answer wait and servo motion'
                        if args.collect_profile:
                            state['camera_timing_scope']='max(UART request/reply, sum of device stage cycles/CPU_HZ), after one warmup; excludes upload, voice, answer wait and servo motion'
                        save()
                    loader.transact(port, 7)
                    state["autonomous_started"] = True
                    save()
                    # Camera cmd6 commits a target and may already have locked
                    # a quiz. In that case cmd7's acknowledgement proves the
                    # autonomous loop was entered; its next frame deliberately
                    # waits for the answer and complete servo cycle. Do not
                    # report this expected wait as a failed download.
                    if question_pending:
                        state.update(autonomous_frame_received=False,
                                     first_question_pending=True,
                                     completed_utc=datetime.now(timezone.utc).isoformat(),
                                     autonomous_frame_note='Camera check selected a target; next autonomous frame waits for answer/open/hold/close')
                        save()
                        print('AUTONOMOUS_STARTED_FIRST_QUESTION_PENDING', flush=True)
                        return
                    header = loader.read_exact(port, 8)
                    length = int.from_bytes(header[5:7], "little")
                    if length > 1024:
                        raise ValueError("Oversized autonomous reply")
                    raw = loader.parse_reply(header + loader.read_exact(port, length + 4))
                    state.update(autonomous_frame_received=True,
                                 autonomous_detections=loader.parse_detections(raw,names))
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
