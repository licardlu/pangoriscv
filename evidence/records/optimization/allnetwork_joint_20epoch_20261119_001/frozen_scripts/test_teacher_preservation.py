import unittest
import torch
from teacher_preservation import matched_preservation_loss


class TeacherPreservation(unittest.TestCase):
    def setUp(self):
        self.teacher = torch.tensor([[0.,0.,0.,0.,4.,4.,-4.,-4.,-4.]])
        self.boxes = torch.tensor([[.5,.5,2.,2.]])
        self.anchors = torch.tensor([[2.,2.]])

    def test_correct_teacher_has_gradient_only_in_existing_rows(self):
        student = torch.zeros((1,10), requires_grad=True)
        loss, counts = matched_preservation_loss(student,self.teacher,self.boxes,self.anchors,torch.tensor([0]))
        self.assertEqual(dict(counts),{'0':1})
        loss.backward()
        self.assertNotEqual(float(student.grad[0,4]),0)
        self.assertEqual(float(student.grad[0,9]),0)

    def test_wrong_category_or_disjoint_teacher_does_not_supply_labels(self):
        for boxes, cls in [(self.boxes,1),(torch.tensor([[8.,8.,2.,2.]]),0),(self.boxes,4)]:
            student = torch.zeros((1,10), requires_grad=True)
            loss, counts = matched_preservation_loss(student,self.teacher,boxes,self.anchors,torch.tensor([cls]))
            self.assertEqual(dict(counts),{})
            loss.backward()
            self.assertEqual(float(student.grad.abs().sum()),0.)

    def test_low_confidence_teacher_cannot_constrain_student(self):
        teacher = self.teacher.clone();teacher[:,4] = -4
        student = torch.zeros((1,10), requires_grad=True)
        loss, counts = matched_preservation_loss(student,teacher,self.boxes,self.anchors,torch.tensor([0]))
        self.assertEqual(dict(counts),{})
        self.assertEqual(float(loss),0.)

    def test_teacher_detached_and_perfect_student_has_zero_loss(self):
        teacher=self.teacher.clone().requires_grad_()
        student=torch.cat([self.teacher,torch.ones((1,1))],1).requires_grad_()
        loss, _ = matched_preservation_loss(student,teacher,self.boxes,self.anchors,torch.tensor([0]))
        loss.backward()
        self.assertEqual(float(loss),0.)
        self.assertIsNone(teacher.grad)

    def test_four_class_student_preserves_only_valid_supervised_anchors(self):
        teacher = self.teacher.repeat(2,1).requires_grad_()
        student = torch.zeros((2,9), requires_grad=True)
        loss, counts = matched_preservation_loss(student,teacher,self.boxes.repeat(2,1),
            self.anchors.repeat(2,1),torch.tensor([0,1]))
        self.assertEqual(dict(counts),{'0':1})
        loss.backward()
        self.assertGreater(float(student.grad[0].abs().sum()),0.)
        self.assertEqual(float(student.grad[1].abs().sum()),0.)
        self.assertIsNone(teacher.grad)

    def test_four_class_perfect_student_zero_and_unsupported_schema_rejected(self):
        student = self.teacher.clone().requires_grad_()
        loss,_ = matched_preservation_loss(student,self.teacher,self.boxes,self.anchors,torch.tensor([0]))
        loss.backward()
        self.assertEqual(float(loss),0.)
        self.assertEqual(float(student.grad.abs().sum()),0.)
        with self.assertRaises(ValueError):
            matched_preservation_loss(torch.zeros((1,11)),self.teacher,self.boxes,self.anchors,torch.tensor([0]))

    def test_native_fiveclass_teacher_preserves_battery_and_hand(self):
        teacher=torch.zeros((2,10),requires_grad=True)
        with torch.no_grad():
            teacher[:,4]=4;teacher[:,5:]=-4
            teacher[0,7]=4;teacher[1,9]=4
        student=torch.zeros((2,10),requires_grad=True)
        loss,counts=matched_preservation_loss(student,teacher,self.boxes.repeat(2,1),
            self.anchors.repeat(2,1),torch.tensor([2,4]))
        self.assertEqual(dict(counts),{'2':1,'4':1})
        loss.backward()
        self.assertGreater(float(student.grad[0,7].abs()),0.)
        self.assertGreater(float(student.grad[1,9].abs()),0.)
        self.assertIsNone(teacher.grad)

    def test_fiveclass_rejects_wrong_confidence_geometry_and_schema(self):
        teacher=torch.tensor([[0.,0.,0.,0.,4.,-4.,-4.,4.,-4.,-4.]])
        for variant in ('wrong','low','far'):
            t=teacher.clone();boxes=self.boxes;classes=torch.tensor([2])
            if variant=='wrong':classes=torch.tensor([1])
            if variant=='low':t[:,4]=-9
            if variant=='far':boxes=torch.tensor([[8.,8.,2.,2.]])
            student=torch.zeros((1,10),requires_grad=True)
            loss,counts=matched_preservation_loss(student,t,boxes,self.anchors,classes)
            self.assertFalse(counts);loss.backward()
            self.assertEqual(float(student.grad.abs().sum()),0.)
        with self.assertRaises(ValueError):
            matched_preservation_loss(torch.zeros((1,9)),teacher,self.boxes,self.anchors,torch.tensor([2]))

    def test_fiveclass_loss_is_balanced_over_present_classes(self):
        teacher=torch.tensor([[0.,0.,0.,0.,4.,-4.,-4.,4.,-4.,-4.],
                              [0.,0.,0.,0.,4.,-4.,-4.,-4.,-4.,4.]])
        student=torch.zeros((2,10),requires_grad=True)
        first,_=matched_preservation_loss(student,teacher,self.boxes.repeat(2,1),
            self.anchors.repeat(2,1),torch.tensor([2,4]))
        idx=torch.tensor([0,0,0,1])
        second,_=matched_preservation_loss(student[idx],teacher[idx],self.boxes.repeat(4,1),
            self.anchors.repeat(4,1),torch.tensor([2,2,2,4]))
        torch.testing.assert_close(first,second,rtol=0,atol=1e-7)


if __name__=='__main__':unittest.main()
