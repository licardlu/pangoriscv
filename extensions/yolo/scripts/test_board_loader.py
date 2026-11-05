"""Host-side loader tests; fake serial responses are not board measurements."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import struct
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
import zlib

import cv2
import numpy as np

import board_loader


def reply(payload=b""):
    message=struct.pack("<4sBHB",b"YAR1",0,len(payload),0)+payload
    return message+struct.pack("<I",zlib.crc32(message))


class FirmwarePort:
    """Models UART framing only, not the CPU, accelerator, or DDR RTL."""
    def __init__(self,detections=b""):
        self.pending=bytearray()
        self.commands=[]
        self.detections=detections or struct.pack("<I",0)

    def __enter__(self):
        return self

    def __exit__(self,*args):
        return False

    def write(self,data):
        magic,cmd,reserved,n,address,crc=struct.unpack("<4sBBHII",data[:16])
        assert magic==b"YAI1" and reserved==0 and n==len(data)-16
        assert crc==zlib.crc32(data[:12]+data[16:])
        self.commands.append((cmd,address,bytes(data[16:])))
        payload=self.detections if cmd in (3,6) else b""
        self.pending.extend(reply(payload))
        return len(data)

    def read(self,n):
        result=bytes(self.pending[:n])
        del self.pending[:n]
        return result


class Loader(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix="yolo_loader_test_")
        self.addCleanup(self.tmp.cleanup)
        self.folder=Path(self.tmp.name)
        blob=b"01234567"
        (self.folder/"model.bin").write_bytes(blob)
        (self.folder/"memory_map.json").write_text(json.dumps({
            "blob_length":len(blob),"blob_crc32":zlib.crc32(blob),
            "blob_sha256":hashlib.sha256(blob).hexdigest(),
            "blob_base":0x1000000,"tensors":[{"address":0x2000000}],
        }),encoding="utf-8")
        copied=self.folder/"board_loader.py"
        shutil.copy2(board_loader.__file__,copied)
        spec=importlib.util.spec_from_file_location("isolated_board_loader",copied)
        self.loader=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.loader)

    def invoke(self,port,*args):
        serial=types.SimpleNamespace(Serial=lambda *a,**k:port)
        output=io.StringIO()
        with patch.dict(sys.modules,{"serial":serial,"torch":None,
                                     "quant_yolov5n":None}), \
             patch.object(sys,"argv",["board_loader.py","--port","FAKE",
                                      "--skip-model","--package-dir",str(self.folder),*args]), \
             contextlib.redirect_stdout(output):
            self.loader.main()
        return output.getvalue()

    def test_standalone_image_has_exact_deployment_preprocessing(self):
        # Odd dimensions exercise letterbox rounding; channel constants expose BGR/RGB swaps.
        for height,width in ((5,7),(7,5),(320,320)):
            with self.subTest(shape=(height,width)):
                yy,xx=np.indices((height,width))
                bgr=np.stack(((xx*17)%256,(yy*31)%256,
                              (xx*13+yy*29)%256),axis=-1).astype(np.uint8)
                path=self.folder/(f"image_{width}_{height}_"+"\u56fe"+".png")
                encoded=cv2.imencode(".png",bgr)[1]
                encoded.tofile(path)
                ratio=min(320/height,320/width)
                nh,nw=int(round(height*ratio)),int(round(width*ratio))
                top,left=(320-nh)//2,(320-nw)//2
                canvas=np.full((320,320,3),114,np.uint8)
                canvas[top:top+nh,left:left+nw]=cv2.resize(bgr,(nw,nh))
                rgb=canvas[:,:,::-1].astype(np.float32)/255.0
                expected=np.zeros((320,320,8),np.int8)
                expected[:,:,:3]=np.floor(rgb*127+0.5).astype(np.int8)
                port=FirmwarePort()
                try:
                    output=self.invoke(port,"--image",str(path))
                except Exception as exc:
                    self.fail(f"Standalone image mode depends on repository/training code: {exc}")
                writes=[(addr,payload) for cmd,addr,payload in port.commands if cmd==1]
                self.assertEqual(len(writes),3200)
                self.assertEqual([addr for addr,_ in writes],
                                 list(range(0x2000000,0x2000000+819200,256)))
                self.assertEqual(b"".join(payload for _,payload in writes),expected.tobytes())
                metadata=[data for cmd,_,data in port.commands if cmd==4]
                self.assertEqual(metadata,[struct.pack("<fffHH",ratio,left,top,width,height)])
                self.assertEqual(json.loads(output.splitlines()[-1]),[])

    def test_camera_prints_category_score_and_box(self):
        packet=struct.pack("<I5fI",1,10,20,100,150,0.75,5)
        text=self.invoke(FirmwarePort(packet),"--camera")
        self.assertIn('"plastic"',text,"Camera output must include the recognized class")
        self.assertIn('0.75',text)
        self.assertIn('150.0',text)

    def test_camera_rejects_malformed_detection_packet(self):
        with self.assertRaisesRegex(ValueError,"detection"):
            self.invoke(FirmwarePort(struct.pack("<I",1)),"--camera")

    def test_camera_rejects_unknown_class(self):
        packet=struct.pack("<I5fI",1,10,20,100,150,0.75,6)
        with self.assertRaisesRegex(ValueError,"category"):
            self.invoke(FirmwarePort(packet),"--camera")

    def test_camera_rejects_nonfinite_score(self):
        packet=struct.pack("<I5fI",1,10,20,100,150,float("nan"),5)
        with self.assertRaisesRegex(ValueError,"detection"):
            self.invoke(FirmwarePort(packet),"--camera")

    def test_conflicting_modes_rejected_before_serial_write(self):
        port=FirmwarePort()
        with self.assertRaises(SystemExit),contextlib.redirect_stderr(io.StringIO()):
            self.invoke(port,"--camera","--autonomous")
        self.assertEqual(port.commands,[])

    def test_zero_camera_frames_rejected_before_serial_write(self):
        port=FirmwarePort()
        with self.assertRaises(SystemExit),contextlib.redirect_stderr(io.StringIO()):
            self.invoke(port,"--camera","--frames","0")
        self.assertEqual(port.commands,[])


if __name__=="__main__":
    unittest.main()
