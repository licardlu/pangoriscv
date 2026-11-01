import struct
import unittest
import zlib
from board_loader import request,parse_reply,transact


def reply(payload=b"",status=0,magic=b"YAR1",reserved=0):
    message=struct.pack("<4sBHB",magic,status,len(payload),reserved)+payload
    return message+struct.pack("<I",zlib.crc32(message))


class FragmentedPort:
    def __init__(self,data,fragment=1024):
        self.data=data
        self.fragment=fragment
        self.written=bytearray()
        self.reads=0

    def write(self,data):
        self.written.extend(data)
        return len(data)

    def read(self,count):
        self.reads+=1
        n=min(count,self.fragment,len(self.data))
        result,self.data=self.data[:n],self.data[n:]
        return result


class Protocol(unittest.TestCase):
    def test_request(self):
        frame=request(1,0x1000000,b"12345678")
        self.assertEqual(struct.unpack("<4sBBHI",frame[:12]),
                         (b"YAI1",1,0,8,0x1000000))
        self.assertEqual(struct.unpack("<I",frame[12:16])[0],
                         zlib.crc32(frame[:12]+frame[16:]))

    def test_reply(self):
        message=struct.pack("<4sBHB",b"YAR1",0,8,0)+b"12345678"
        frame=message+struct.pack("<I",zlib.crc32(message))
        self.assertEqual(parse_reply(frame),b"12345678")
        with self.assertRaises(ValueError):
            parse_reply(frame[:-1]+b"\xff")
        with self.assertRaises(ValueError):
            request(1,payload=bytes(257))

    def test_fragmented_reply(self):
        port=FragmentedPort(reply(b"12345678"),fragment=3)
        try:
            result=transact(port,2,0x1000000)
        except Exception as exc:
            self.fail(f"A complete fragmented response was rejected: {exc}")
        self.assertEqual(result,b"12345678")
        self.assertEqual(bytes(port.written),request(2,0x1000000))

    def test_invalid_magic_rejected_before_body_read(self):
        port=FragmentedPort(reply(b"12345678",magic=b"BAD!"))
        with self.assertRaisesRegex(ValueError,"header"):
            transact(port,2)
        self.assertEqual(port.reads,1,"Must reject invalid magic before trusting length")

    def test_reserved_header_byte_is_checked(self):
        with self.assertRaisesRegex(ValueError,"header"):
            parse_reply(reply(reserved=1))

    def test_truncated_response_reports_progress(self):
        port=FragmentedPort(reply(b"12345678")[:11])
        with self.assertRaisesRegex(TimeoutError,r"3/12"):
            transact(port,2)

    def test_firmware_error_is_not_retried(self):
        port=FragmentedPort(reply(b"detail",status=2))
        with self.assertRaisesRegex(RuntimeError,"Firmware error 2"):
            transact(port,3)
        self.assertEqual(bytes(port.written),request(3))

    def test_oversized_reply_rejected_before_body_read(self):
        port=FragmentedPort(struct.pack("<4sBHB",b"YAR1",0,1025,0))
        with self.assertRaisesRegex(ValueError,"Oversized"):
            transact(port,3)
        self.assertEqual(port.reads,1)


if __name__=="__main__":
    unittest.main()
