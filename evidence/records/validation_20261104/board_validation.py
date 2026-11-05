"""Explicit hardware validation; all UART packets and model identities retained."""
from pathlib import Path
import hashlib,json,sys,time,struct

REPO=Path(__file__).resolve().parents[3]
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(REPO/'extensions/yolo/scripts'))
import program_board,board_loader as loader
from board_perf import parse_profile
import serial

program_board.TOOLS=Path(r'D:\FPGA_Project\zi_guang_tong_chuang\pds\PDS_2022.2-SP6.1\bin')
V3=Path(r'D:\FPGA_Project\trash_white_split_voice_source_v1\yolo\build_camera_servo_v3_seed3_20261103\generate_bitstream\yolo_camera_top.sbit')

def program(out=BASE/'v3_program'):
    sys.argv=['program_board','--sbit',str(V3),'--out',str(out)]
    program_board.main()

def main():
    program()
    manifest,blob=loader.load_deployment(REPO/'extensions/yolo/gen/integration/packed')
    report=dict(started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
        bitstream_sha256=hashlib.sha256(V3.read_bytes()).hexdigest(),
        model_sha256=hashlib.sha256(blob).hexdigest(),port='COM34',model_crc_pass=False,
        runs=[],autonomous=False)
    def save(): (BASE/'board_result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    try:
        with serial.Serial('COM34',115200,timeout=40,write_timeout=10) as port:
            port.reset_input_buffer()
            loader.write_image(port,manifest['blob_base'],blob)
            loader.transact(port,5);report['model_crc_pass']=True;save()
            print('MODEL_BOARD_CRC_PASS',flush=True)
            loader.transact(port,9,63)
            for i in range(10):
                start=time.perf_counter();raw=loader.transact(port,6);elapsed=time.perf_counter()-start
                (BASE/f'camera_{i:02}.bin').write_bytes(raw)
                profile_raw=loader.transact(port,8)
                (BASE/f'camera_{i:02}_profile.bin').write_bytes(profile_raw)
                row=dict(frame=i,wall_s=elapsed,detections=loader.parse_detections(raw),profile=parse_profile(profile_raw,manifest))
                report['runs'].append(row);save()
                print('CAMERA',i,round(elapsed,6),row['detections'],flush=True)
    except Exception as e:
        report['error']=repr(e);save();raise
    save();print('CAMERA_VALIDATION_DONE',flush=True)

if __name__=='__main__':main()
