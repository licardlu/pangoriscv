import unittest
import torch
from qat_tail import integer_conv,ste_round

class ExactIntegerConvolution(unittest.TestCase):
    def test_signed_strided_convolutions_are_exact(self):
        torch.manual_seed(20261118)
        for kernel,stride,pad in [(1,1,0),(3,1,1),(3,2,1)]:
            x=torch.randint(-128,128,(2,16,9,11)).double().requires_grad_()
            w=torch.randint(-127,128,(12,16,kernel,kernel)).double().requires_grad_()
            actual=integer_conv(x,w,stride,pad)
            expected=torch.nn.functional.conv2d(x,w,stride=stride,padding=pad)
            torch.testing.assert_close(actual,expected,rtol=0,atol=0)
            actual.square().mean().backward()
            self.assertTrue(torch.isfinite(x.grad).all());self.assertTrue(torch.isfinite(w.grad).all())

    def test_large_integer_accumulator_stays_exact(self):
        x=torch.full((1,1024,3,3),127.,dtype=torch.float64)
        w=torch.full((1,1024,3,3),127.,dtype=torch.float64)
        actual=integer_conv(x,w,1,0)
        self.assertEqual(float(actual),127*127*1024*9)

    def test_signed_round_ties_and_ste(self):
        x=torch.tensor([-2.5,-1.5,-.5,.5,1.5,2.5],dtype=torch.float64,requires_grad=True)
        y=ste_round(x)
        torch.testing.assert_close(y,torch.tensor([-3.,-2.,-1.,1.,2.,3.],dtype=torch.float64),rtol=0,atol=0)
        y.sum().backward();torch.testing.assert_close(x.grad,torch.ones_like(x),rtol=0,atol=0)

if __name__=='__main__':unittest.main()
