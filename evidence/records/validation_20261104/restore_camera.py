"""Restore full v3 and observe autonomous camera replies without simulating them."""
from pathlib import Path
import hashlib,json,sys,time,struct
import serial
BASE=Path(__file__).resolve().parent
REPO=BASE.parents[2]
sys.path.insert(0,str(REPO/'extensions/yolo/scripts'))
import board_validation as initial
import board_loader as loader
from board_perf import parse_profile

def receive(port):
    header=loader.read_exact(port,8)
    if header[:4]!=b'YAR1':raise ValueError('Autonomous reply header mismatch')
    length=struct.unpack('<H',header[5:7])[0]
    if length>1024:raise ValueError('Oversized autonomous reply')
    return loader.parse_reply(header+loader.read_exact(port,length+4))

def main():
    output=BASE/'restore_camera_result.json'
    if output.exists():raise RuntimeError('Preserve existing restore result')
    initial.program(BASE/'v3_restore_program')
    model,blob=loader.load_deployment(REPO/'extensions/yolo/gen/integration/packed')
    result=dict(bitstream_sha256=hashlib.sha256(initial.V3.read_bytes()).hexdigest(),
        model_sha256=hashlib.sha256(blob).hexdigest(),camera_runs=[],autonomous_runs=[])
    def save():output.write_text(json.dumps(result,indent=2),encoding='utf-8')
    save()
    try:
        with serial.Serial('COM34',115200,timeout=60,write_timeout=10) as port:
            port.reset_input_buffer()
            loader.write_image(port,model['blob_base'],blob)
            loader.transact(port,5);result['model_crc_pass']=True
            loader.transact(port,9,63);save()
            for i in range(3):
                start=time.perf_counter();raw=loader.transact(port,6)
                elapsed=time.perf_counter()-start
                (BASE/f'restore_camera_{i:02}.bin').write_bytes(raw)
                profile=loader.transact(port,8)
                (BASE/f'restore_camera_{i:02}_profile.bin').write_bytes(profile)
                result['camera_runs'].append(dict(frame=i,wall_s=elapsed,
                    detections=loader.parse_detections(raw),profile=parse_profile(profile,model)))
                save();print('RESTORE_CAMERA_FRAME',i,elapsed,flush=True)
            loader.transact(port,7);result['autonomous_ack']=True;save()
            start=time.perf_counter()
            for i in range(30):
                frame_start=time.perf_counter();raw=receive(port);elapsed=time.perf_counter()-frame_start
                (BASE/f'autonomous_{i:02}.bin').write_bytes(raw)
                result['autonomous_runs'].append(dict(frame=i,interval_s=elapsed,
                    detections=loader.parse_detections(raw)))
                save();print('AUTONOMOUS_FRAME',i+1,elapsed,flush=True)
            result.update(autonomous_observation_s=time.perf_counter()-start,
                autonomous_continues=True,completed=True)
            save();print('RESTORE_AND_AUTONOMOUS_VALIDATION_DONE',flush=True)
    except Exception as e:
        result['error']=repr(e);save();raise

if __name__=='__main__':main()
