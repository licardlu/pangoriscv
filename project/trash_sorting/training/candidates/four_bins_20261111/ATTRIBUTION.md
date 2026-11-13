# Data and code attribution

- CodingBearHsun, trash-sort v1: https://www.kaggle.com/datasets/codingbearhsun/trash-sort (CC BY-NC-SA 4.0).
- Suman Kunwar, Garbage Classification v2 BBox 384 v1: https://www.kaggle.com/datasets/sumn2u/garbage-classification-v2-bbox-384 (CC BY 4.0). Source: https://www.kaggle.com/datasets/sumn2u/garbage-classification-v2.
- Ultralytics YOLOv5 v7.0, commit 915bbf294bb74c859f0b41f1c23bc395014ea679: https://github.com/ultralytics/yolov5/tree/v7.0 (GPL-3.0 source code).
- Transfer initialization: https://huggingface.co/keremberke/yolov5n-garbage, original checkpoint retained separately.

Modified work: the two detection datasets were audited, visually deduplicated/grouped, remapped into four bin labels, and class-balanced for training; YOLOv5n was fine-tuned for 24 epochs at 320 input. Paper/cardboard map to recyclable. Dataset images are not redistributed here.

License references: https://creativecommons.org/licenses/by-nc-sa/4.0/ and https://creativecommons.org/licenses/by/4.0/ . Retain attribution and the applicable noncommercial/share-alike conditions on reuse. This research candidate is not offered for commercial use.
