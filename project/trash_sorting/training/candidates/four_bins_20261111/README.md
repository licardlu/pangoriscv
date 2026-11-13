# Four-bin YOLOv5n 320 candidate

Classes: 0 kitchen (green), 1 recyclable (blue), 2 hazardous (red), 3 other (gray).
Existing application bin codes/keys: model class 0->1, 1->4, 2->2, 3->3. Do not use class+1.
Paper and cardboard both map to recyclable. This model predicts bin categories, not individual materials.

Floating point checkpoint for pinned YOLOv5 v7.0. Not a replacement FPGA weight blob.
Existing firmware assumes six raw classes / 33 head channels; this candidate has four / 27.
See docs/verification/trash-retraining-20261111.md for sources, tests and limits.

Held-out evaluation: 1,572 public images, fixed 320x320. Four-bin mAP50 76.99% (old six-class model mapped to bins: 21.10%). Per-bin AP50: kitchen 76.13%, recyclable 79.71%, hazardous 81.74%, other 70.37%.

Confidence 0.25 still produces many extra/incorrect boxes. Public-image scores do not establish FPGA camera accuracy; hazardous data has limited background/instance diversity. Quantization and on-board verification remain pending.

See ATTRIBUTION.md for sources and noncommercial/share-alike conditions.
