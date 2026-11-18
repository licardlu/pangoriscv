import unittest,torch
from fiveclass_distillation import matched_loss

class GroundTruthGate(unittest.TestCase):
    def inputs(self,category=2):
        teacher=torch.zeros((1,10),requires_grad=True)
        with torch.no_grad():teacher[:,4]=3;teacher[:,5:]=-4;teacher[:,5+category]=4
        student=torch.zeros((1,10),requires_grad=True)
        return student,teacher,torch.tensor([[.5,.5,1.,1.]]),torch.ones((1,2)),torch.tensor([category])

    def test_correct_teacher_and_no_teacher_gradient(self):
        values=self.inputs();loss,counts=matched_loss(*values)
        self.assertEqual(counts,{'2':1});self.assertGreater(float(loss),0)
        loss.backward();self.assertGreater(int(torch.count_nonzero(values[0].grad)),0);self.assertIsNone(values[1].grad)

    def test_wrong_class_low_confidence_bad_geometry_are_rejected(self):
        for failure in range(3):
            s,t,b,a,c=self.inputs()
            with torch.no_grad():
                if failure==0:c[:]=1
                elif failure==1:t[:,4]=-9
                else:b[:,:2]=10
            loss,counts=matched_loss(s,t,b,a,c)
            self.assertFalse(counts);self.assertEqual(float(loss),0)
            loss.backward();self.assertEqual(int(torch.count_nonzero(s.grad)),0)

    def test_hand_class_is_not_mapped_to_waste(self):
        loss,counts=matched_loss(*self.inputs(4))
        self.assertEqual(counts,{'4':1});self.assertGreater(float(loss),0)

if __name__=='__main__':unittest.main()
