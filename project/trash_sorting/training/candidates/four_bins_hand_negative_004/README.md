# Hand-negative candidate 004

This is an evaluated but **not deployed** YOLOv5n/320 candidate. It trains the later layers for four epochs while keeping the first ten layers and their BatchNorm statistics frozen.

- Checkpoint SHA256: `43bf04c1df736ab9688cb65257e0e59cbefb45d53fc0e52106f576f75ab34bf1`
- Quantized model SHA256: `9690dea6ece2953de52bb7f70323938696d867ede0203c54a45e142f81cfa575`
- Public validation/test: mAP50 77.84% / 78.4%.
- Reviewed hand crops: 6/29 validation and 3/21 test false-positive frames.
- Personal photos: 71/80 under the accepted medicine-bottle rule; batteries 7/9; two images had no detection.
- Quantized arithmetic check: 240 head outputs, maximum absolute error 0.0001893. No FPGA build or board test was done.

The hand false positives improve over the original 28/29 validation frames, but the personal battery count is below the original 8/9. Keep the deployed model until representative hand-held battery/medicine/tissue pictures show a net improvement.
