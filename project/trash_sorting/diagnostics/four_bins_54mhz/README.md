# Four-bin 54 MHz recovery package

This is the measured SRAM build: AI/CPU at 54 MHz, 320x320 input, four output bins. It passed final multi-corner timing, board configuration readback, UART firmware response, model CRC, same-input preprocessing CRC, four fixed numeric fixtures, ten camera timing frames, and autonomous-mode restart.

- Bitstream SHA256: `d1658824e107fd9a681e824bc3f10535038ac6237d3a2eacc62c5207d58a4b55`
- Model SHA256: `ea70896cec65e802cd063525ba8a09814b10c52b65a36822abbc0d7854ac447e`
- Board model CRC32: `0x209305e5`
- Camera request/reply mean: 1.790597 seconds over ten frames; the camera view was empty, so this is a speed measurement, not an object accuracy result.

`yolo_camera_top.sbit`, `manifest.json`, `model.bin`, and `memory_map.json` are the matching recovery artifacts. SRAM contents do not survive power loss. From this directory, full logs are four levels up under `evidence/records/trash-four-bin-fast54-program-20261112-001/`.
