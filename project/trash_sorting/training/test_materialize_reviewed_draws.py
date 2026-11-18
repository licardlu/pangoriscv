"""Check real YOLO replay counts and reject JPEGs before source hardlink mutation."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from PIL import Image


ROOT=Path(__file__).resolve().parents[3]


def main():
    tool=Path(__file__).with_name('materialize_reviewed_draws.py')
    yolo=ROOT/'build/overnight_20261116/upstream/yolov5-7.0'
    env=dict(os.environ,PYTHONUTF8='1',YOLOv5_AUTOINSTALL='false')
    (ROOT/'build').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='replay_loader_check_',dir=ROOT/'build') as directory:
        temp=Path(directory)
        first=temp/'first.jpg';second=temp/'second.jpg'
        Image.new('RGB',(32,32),'red').save(first)
        Image.new('RGB',(32,32),'blue').save(second)
        def row(image):
            return dict(split='train',prepared_image=str(image),image_sha256=hashlib.sha256(image.read_bytes()).hexdigest(),
                        boxes=[[0,.5,.5,.5,.5]],source='synthetic_preflight_only')
        rows=[row(first),row(first),row(second)]
        held=dict(split='val',prepared_image='not_opened_validation_sentinel.jpg',boxes=[])
        manifest=temp/'manifest.json';manifest.write_text(json.dumps(rows+[held]),encoding='utf8')
        out=temp/'aliases'
        subprocess.run([sys.executable,str(tool),'--manifest',str(manifest),'--out',str(out)],env=env,cwd=ROOT,check=True,capture_output=True)
        report=json.loads((out/'result.json').read_text(encoding='utf8'))
        assert report['training_draws']==3 and report['unique_file_identities']==2
        assert json.loads((out/'manifest.json').read_text(encoding='utf8'))[-1]==held
        os.environ['YOLOV5_CONFIG_DIR']=str(temp/'config')
        os.environ['YOLOv5_AUTOINSTALL']='false'
        sys.path.insert(0,str(yolo))
        from utils.dataloaders import LoadImagesAndLabels
        dataset=LoadImagesAndLabels(str(out/'train.txt'),img_size=320,batch_size=2,augment=False,cache_images=False)
        assert len(dataset)==3 and len(set(dataset.im_files))==3
        broken=temp/'broken.jpg';broken.write_bytes(first.read_bytes()[:-2])
        bad_manifest=temp/'broken_manifest.json';bad_manifest.write_text(json.dumps([row(broken)]),encoding='utf8')
        before=broken.read_bytes()
        result=subprocess.run([sys.executable,str(tool),'--manifest',str(bad_manifest),'--out',str(temp/'rejected')],env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf8')
        assert result.returncode!=0 and 'JPEG lacks EOI' in result.stderr
        assert broken.read_bytes()==before and not list((temp/'rejected/images/train').iterdir())
        assert hashlib.sha256(first.read_bytes()).hexdigest()==rows[0]['image_sha256']
    print('PASS: 3 replay aliases survive real YOLO cache for 2 synthetic images; corrupt JPEG rejected before hardlinks; sources unchanged; temporary fixtures removed.',flush=True)


if __name__=='__main__':
    main()
