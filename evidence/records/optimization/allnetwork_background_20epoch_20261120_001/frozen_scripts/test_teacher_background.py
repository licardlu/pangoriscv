import unittest
import torch
from teacher_background import background_preservation_loss


class BackgroundRetentionTests(unittest.TestCase):
    def setup_pair(self, size=6):
        teacher = torch.zeros(1, 3, size, size, 10)
        teacher[..., 4] = -5.
        student = teacher.clone().requires_grad_()
        empty = tuple(torch.empty(0, dtype=torch.long) for _ in range(4))
        return student, teacher, empty

    def test_identical_teacher_zero_and_no_teacher_gradient(self):
        student, teacher, index = self.setup_pair()
        teacher.requires_grad_()
        value, stats = background_preservation_loss([student], [teacher], torch.empty(0, 6), [index])
        value.backward()
        self.assertEqual(float(value), 0.)
        self.assertGreater(stats['selected_anchors'], 0)
        self.assertEqual(float(student.grad.abs().sum()), 0.)
        self.assertIsNone(teacher.grad)

    def test_false_objectness_only_receives_suppressing_gradient(self):
        student, teacher, index = self.setup_pair()
        with torch.no_grad():student[0, 0, 0, 0, 4] = 0.
        value, stats = background_preservation_loss([student], [teacher], torch.empty(0, 6), [index])
        value.backward()
        self.assertGreater(float(student.grad[0, 0, 0, 0, 4]), 0.)
        self.assertEqual(int((student.grad != 0).sum()), 1)
        self.assertEqual(stats['positive_drift_anchors'], 1)

    def test_true_hand_and_waste_rectangle_and_assignments_protected(self):
        for category in [0, 1, 2, 3, 4]:
            student, teacher, empty = self.setup_pair(10)
            with torch.no_grad():
                student[0, :, 5, 5, 4] = 1.
                student[0, 0, 0, 0, 4] = 1.
            target = torch.tensor([[0., category, .5, .5, .2, .2]])
            indices = tuple(torch.tensor([0]) for _ in range(4))
            value, _ = background_preservation_loss([student], [teacher], target, [indices])
            value.backward()
            self.assertEqual(float(student.grad.abs().sum()), 0.)
            self.assertEqual(float(value), 0.)

    def test_confident_teacher_object_cannot_supply_negative(self):
        student, teacher, index = self.setup_pair()
        teacher[..., 4] = 0.
        with torch.no_grad():student[..., 4] = 3.
        value, stats = background_preservation_loss([student], [teacher], torch.empty(0, 6), [index])
        value.backward()
        self.assertEqual(float(value), 0.)
        self.assertEqual(stats['selected_anchors'], 0)
        self.assertEqual(float(student.grad.abs().sum()), 0.)

    def test_decreased_objectness_is_not_raised(self):
        student, teacher, index = self.setup_pair()
        with torch.no_grad():student[..., 4] = -8.
        value, _ = background_preservation_loss([student], [teacher], torch.empty(0, 6), [index])
        value.backward()
        self.assertEqual(float(value), 0.)
        self.assertEqual(float(student.grad.abs().sum()), 0.)

    def test_topk_bounds_per_image(self):
        student, teacher, index = self.setup_pair()
        with torch.no_grad():student[..., 4] = 0.
        _, stats = background_preservation_loss([student], [teacher], torch.empty(0, 6), [index], topk=7)
        self.assertEqual(stats['selected_anchors'], 7)

    def test_wrapper_handles_empty_gt_and_skips_evaluation_teacher(self):
        from teacher_preservation import PreservationLoss
        class Head(torch.nn.Module):
            def __init__(self):
                super().__init__();self.nc=5;self.anchors=torch.ones(1);self.stride=torch.ones(1)
        class Model(torch.nn.Module):
            def __init__(self, raw):
                super().__init__();self.model=torch.nn.ModuleList([Head()]);self.raw=raw;self.calls=0
            def forward(self, image):
                self.calls+=1;return None,[self.raw]
        student_raw, teacher_raw, empty = self.setup_pair()
        with torch.no_grad():student_raw[...,4]=0.
        class Supervised:
            def __call__(self,p,t):return p[0].sum()*0,torch.zeros(3)
            def build_targets(self,p,t):
                return [torch.empty(0,dtype=torch.long)],[torch.empty(0,4)],[empty],[torch.empty(0,2)]
        student,teacher=Model(student_raw),Model(teacher_raw)
        loss=PreservationLoss(Supervised(),student,teacher,5.,background_strength=.1)
        targets=torch.empty(0,6)
        value,_=loss([student_raw],targets,images=torch.zeros(1,3,320,320))
        value.backward()
        self.assertGreater(float(value),0.)
        self.assertEqual(teacher.calls,1)
        self.assertEqual(loss.take_stats()['background_preservation']['selected_anchors'],32)
        with torch.no_grad():value,_=loss([student_raw],targets)
        self.assertEqual(float(value),0.)
        self.assertEqual(teacher.calls,1)


if __name__ == '__main__':unittest.main()
