"""Accept GCC's aligned switch alias without accepting arbitrary computed jumps."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from audit_stereo_stack import dispatch_base


class DispatchTest(unittest.TestCase):
    def setUp(self):
        self.rows=[dict(mnemonic=op,operands=args) for op,args in [
            ('li','a5,7'),('bltu','a5,s2,800086c0 <media_player_poll+0x3fc>'),
            ('lui','a4,0x8000d'),('slli','a5,s2,0x2'),('mv','a4,a4'),
            ('add','a5,a5,a4'),('lw','a5,0(a5)')]]

    def test_aligned_alias(self):self.assertEqual(dispatch_base(self.rows,8),0x8000d000)

    def test_other_table_sizes_and_register_mismatch_fail(self):
        with self.assertRaises(ValueError):dispatch_base(self.rows,9)
        for index,operands in [(1,'a5,s3,800086c0'),(3,'a5,s2,0x1'),(4,'a4,a3'),(5,'a5,a5,a3'),(6,'a5,4(a5)')]:
            rows=[dict(r) for r in self.rows];rows[index]['operands']=operands
            with self.subTest(index=index),self.assertRaises(ValueError):dispatch_base(rows,8)

    def test_comment_address_still_supported(self):
        self.assertEqual(dispatch_base([dict(mnemonic='addi',operands='a3,a3,-268 # 8000fe80 <table>')],15),0x8000fe80)


if __name__=='__main__':unittest.main()
