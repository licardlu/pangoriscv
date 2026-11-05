"""Lite-A: YOLOv3-tiny topology, width x0.5, 4 classes, 128x128 input.

The layer sequence is the one in conv_int8/lite_a.py -- same order, same channel
counts -- so a checkpoint trained here maps onto the hardware layer by layer.
Anchors are yolov3-tiny's scaled to the 128 input.
"""

from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F

WIDTH = [8, 16, 32, 64, 128, 256, 512]
NC = 4
NA = 3
INPUT = 128

ANCHORS_FULL = [(10, 14), (23, 27), (37, 58), (81, 82), (135, 169), (344, 319)]
ANCHORS = [(round(w * INPUT / 416 / 2) * 2, round(h * INPUT / 416 / 2) * 2)
           for w, h in ANCHORS_FULL]
# head1 (stride 32) uses the three large anchors, head2 (stride 16) the small ones
A1 = ANCHORS[3:]
A2 = ANCHORS[0:3]


class DarkMaxPool(nn.Module):
    """Darknet maxpool: padding = k//2 applied to the right/bottom only.

    PyTorch pads symmetrically, so MaxPool2d(2,1,padding=1) turns 4x4 into 5x5
    while Darknet keeps 4x4. The mismatch only shows up at the route/upsample
    concat, which is exactly where it bit.
    """

    def __init__(self, k=2, s=2):
        super().__init__()
        self.k = k
        self.s = s
        self.pad = k // 2

    def forward(self, x):
        if self.pad:
            x = F.pad(x, (0, self.pad, 0, self.pad), value=float("-inf"))
        return F.max_pool2d(x, self.k, self.s)


def cbr(cin, cout, k=3, s=1):
    p = k // 2
    return nn.Sequential(
        nn.Conv2d(cin, cout, k, s, p, bias=False),
        nn.BatchNorm2d(cout),
        nn.LeakyReLU(0.125, inplace=True),
    )


class LiteA(nn.Module):
    def __init__(self, nc=NC):
        super().__init__()
        c = WIDTH
        self.l0 = cbr(3, c[0])
        self.l2 = cbr(c[0], c[1])
        self.l4 = cbr(c[1], c[2])
        self.l6 = cbr(c[2], c[3])
        self.l8 = cbr(c[3], c[4])          # skip for the second head
        self.l10 = cbr(c[4], c[5])
        self.l12 = cbr(c[5], c[6])
        self.l13 = cbr(c[6], c[4], k=1)
        self.l14 = cbr(c[4], c[5])
        self.head1 = nn.Conv2d(c[5], NA * (5 + nc), 1)
        self.l17 = cbr(c[6], c[3], k=1)
        self.l20 = cbr(c[3] + c[4], c[4])
        self.head2 = nn.Conv2d(c[4], NA * (5 + nc), 1)
        self.pool = DarkMaxPool(2, 2)
        self.pool_s1 = DarkMaxPool(2, 1)
        self.up = nn.Upsample(scale_factor=2, mode="nearest")

    def forward(self, x):
        x = self.pool(self.l0(x))          # /2
        x = self.pool(self.l2(x))          # /4
        x = self.pool(self.l4(x))          # /8
        x = self.pool(self.l6(x))          # /16
        s8 = self.l8(x)                    # stride 16 skip
        x = self.pool(s8)                  # /32
        x = self.l10(x)
        x = self.pool_s1(x)
        s12 = self.l12(x)                  # 512 ch, the route -4 source
        x = self.l13(s12)
        x = self.l14(x)
        h1 = self.head1(x)
        y = self.l17(s12)
        y = self.up(y)
        y = torch.cat([y, s8], dim=1)
        y = self.l20(y)
        h2 = self.head2(y)
        return h1, h2
