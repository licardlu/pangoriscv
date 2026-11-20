import unittest
import torch
from waste_hand_margin import waste_hand_margin, waste_hand_loss_class


class WasteHandMarginTests(unittest.TestCase):
    def test_only_hand_and_actual_waste_class_gradients(self):
        logits = torch.zeros(5, 10, requires_grad=True)
        loss, counts = waste_hand_margin(logits, torch.arange(5))
        loss.backward()
        self.assertEqual(counts, {'0': 1, '1': 1, '2': 1, '3': 1})
        self.assertEqual(float(logits.grad[:, :5].abs().sum()), 0.)
        for c in range(4):
            self.assertLess(float(logits.grad[c, 5+c]), 0.)
            self.assertGreater(float(logits.grad[c, 9]), 0.)
            self.assertEqual(int((logits.grad[c] != 0).sum()), 2)
        self.assertEqual(float(logits.grad[4].abs().sum()), 0.)

    def test_hand_only_and_empty_do_not_suppress_real_hands(self):
        for classes in [torch.tensor([4]), torch.empty(0, dtype=torch.long)]:
            logits = torch.zeros(len(classes), 10, requires_grad=True)
            loss, counts = waste_hand_margin(logits, classes)
            loss.backward()
            self.assertEqual(float(loss), 0.)
            self.assertEqual(counts, {})
            self.assertEqual(float(logits.grad.abs().sum()), 0.)

    def test_present_classes_have_equal_weight_despite_anchor_imbalance(self):
        a = torch.zeros(2, 10);a[0, 9] = 2.;a[1, 9] = -2.
        expected, _ = waste_hand_margin(a, torch.tensor([0, 2]))
        actual, _ = waste_hand_margin(torch.cat([a[:1].repeat(20, 1), a[1:]]),
                                      torch.tensor([0]*20+[2]))
        self.assertAlmostEqual(float(actual), float(expected), places=6)

    def test_optimizing_margin_reduces_competitive_false_hand(self):
        logits = torch.zeros(1, 10, requires_grad=True)
        optimizer = torch.optim.SGD([logits], lr=.1)
        before, _ = waste_hand_margin(logits, torch.tensor([2]))
        before.backward();optimizer.step()
        after, _ = waste_hand_margin(logits, torch.tensor([2]))
        self.assertLess(float(after), float(before))
        self.assertLess(float(logits[0, 9]), 0.)
        self.assertGreater(float(logits[0, 7]), 0.)

    def test_wrapper_evaluation_bypasses_auxiliary(self):
        class Fake:
            nc = 5
            def __init__(self, model):pass
            def __call__(self, p, t):return p[0].sum()*0, torch.zeros(3)
            def build_targets(self, p, t):raise AssertionError('Evaluation must not build extra targets')
        tracked = []
        loss = waste_hand_loss_class(Fake, tracked)(None)
        with torch.no_grad():
            value, _ = loss([torch.zeros(1, 1, 1, 1, 10)], torch.empty(0, 6))
        self.assertEqual(float(value), 0.)
        self.assertEqual(loss.take_margin_stats().get('training_batches', 0), 0)


if __name__ == '__main__':unittest.main()
