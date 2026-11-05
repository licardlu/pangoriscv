"""Run a precommitted labeled subset through the FPGA, never PC predictions."""
from pathlib import Path
import hashlib,json,sys,time,struct
sys.path.insert(0,r'C:\Users\TWINKL~1\AppData\Local\Temp\fpga_validation_deps_20261104')
BASE=Path(__file__).resolve().parent
REPO=BASE.parents[2]
sys.path.insert(0,str(REPO/'extensions/yolo/scripts'))
import board_loader as loader
from board_perf import parse_profile
import serial

def main():
    selected=BASE/'dataset/validation18_seed20261104.json'
    dataset=json.loads(selected.read_text(encoding='utf-8-sig'))
    model,blob=loader.load_deployment(REPO/'extensions/yolo/gen/integration/packed')
    report=dict(board_test=True,subset_sha256=hashlib.sha256(selected.read_bytes()).hexdigest(),
        subset_file=str(selected),confidence_threshold=.25,nms_iou=.45,
        model_sha256=hashlib.sha256(blob).hexdigest(),
        bitstream_sha256='2b98f90fbd0b4fd2de4074e74cb2c4aa8886d6009aa12bba4dfaf5d071bc4657',
        runs=[],failed=False)
    path=BASE/'dataset_board_results.json'
    if path.exists(): raise RuntimeError('Existing results must not be overwritten')
    def save():path.write_text(json.dumps(report,indent=2),encoding='utf-8')
    save()
    try:
        with serial.Serial('COM34',115200,timeout=60,write_timeout=10) as port:
            port.reset_input_buffer();loader.transact(port,5)
            report['model_board_crc_pass']=True;save()
            for image in dataset['images']:
                start=time.perf_counter()
                packed,metadata=loader.prepare_image(Path(image['path']))
                print('IMAGE_START',image['index'],image['target_class_name'],image['file_name'],flush=True)
                loader.write_image(port,model['tensors'][0]['address'],packed)
                transfer=time.perf_counter()-start
                loader.transact(port,4,payload=metadata)
                infer_start=time.perf_counter();raw=loader.transact(port,3)
                elapsed=time.perf_counter()-infer_start
                (BASE/f'dataset_{image["index"]:02}.bin').write_bytes(raw)
                profile_raw=loader.transact(port,8)
                (BASE/f'dataset_{image["index"]:02}_profile.bin').write_bytes(profile_raw)
                row=dict(index=image['index'],image_id=image['image_id'],file_name=image['file_name'],
                    image_sha256=hashlib.sha256(Path(image['path']).read_bytes()).hexdigest(),
                    width=image['width'],height=image['height'],gt=image['gt'],
                    upload_seconds=transfer,inference_seconds=elapsed,
                    detections=loader.parse_detections(raw),profile=parse_profile(profile_raw,model))
                report['runs'].append(row);save()
                print('IMAGE_DONE',image['index'],'inference_s',round(elapsed,6),'dets',row['detections'],flush=True)
            report['completed']=True;save()
            print('DATASET_BOARD_EVAL_DONE',flush=True)
    except Exception as e:
        report.update(failed=True,error=repr(e));save();raise

if __name__=='__main__':main()
