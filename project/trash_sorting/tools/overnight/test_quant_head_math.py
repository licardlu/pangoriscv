"""Check training math against runtime coefficient rules and image geometry."""
import unittest
from pathlib import Path
from adapt_quant_heads import setup,ROOT,q16_weight,targets_letterbox
setup(ROOT/'build/quant_head_adapt_20261118_001/math_tests')
import numpy as np
import torch

class HeadMath(unittest.TestCase):
    def test_signed_half_and_per_row_dynamic_scale(self):
        # Rows force 65536, 32768 and 8192 runtime scales. Include exact ties.
        w=torch.tensor([[.25,.5/65536,-.5/65536,0],
                        [.75,.5/32768,-.5/32768,0],
                        [3.,.5/8192,-.5/8192,0]],requires_grad=True)
        expected=np.array([[.25,1/65536,-1/65536,0],
                           [.75,1/32768,-1/32768,0],
                           [3.,1/8192,-1/8192,0]],dtype=np.float32)
        quant=q16_weight(w)
        np.testing.assert_array_equal(quant.detach().numpy(),expected)
        quant.sum().backward()
        torch.testing.assert_close(w.grad,torch.ones_like(w),rtol=0,atol=0)

    def test_landscape_and_portrait_geometry(self):
        np.testing.assert_allclose(targets_letterbox([[2,.5,.5,.2,.4]],640,480),
                                   [[2,.5,.5,.2,.3]],rtol=0,atol=1e-15)
        np.testing.assert_allclose(targets_letterbox([[4,.25,.75,.4,.2]],480,640),
                                   [[4,.3125,.75,.3,.2]],rtol=0,atol=1e-15)

    def test_odd_integer_padding_and_corner_box(self):
        # A one-pixel asymmetry must not silently use fractional centering.
        actual=targets_letterbox([[1,.5,.5,1,1]],320,239)[0]
        np.testing.assert_allclose(actual,[1,.5,159.5/320,1,239/320],rtol=0,atol=1e-15)
        self.assertEqual(actual[2]-actual[4]/2,40/320)

if __name__=='__main__':unittest.main()
