# CPU + YOLO offline integration candidate

Scope: pretrained six-class YOLOv5n, CPU scheduling/software branches and heads,
RTL convolution, single CMOS1, HDMI boxes and English class labels. No mechanical
sorting and no requirement to put the whole network in RTL.

This is a candidate, not a board-accepted release. No JTAG or serial hardware
access was performed. The teammate's CPU source and the video source were read,
not edited.

## Canonical files

- `gen/integration/deployment/`: graph-aware Q15 calibration and arithmetic oracle.
- `gen/integration/packed/`: `model.bin`, `memory_map.json`, `deployment_model.h`.
- `gen/integration/firmware/`: RV32IM ELF, ROM hex, linker map, clock/model manifest.
- `rtl/conv_band_rt.v`: runtime-configurable convolution.
- `sw/yolo_runtime.c`: CPU branches and FP32 detection heads.
- `sw/yolo_decode.c`: objectness times class, per-class Top-32, NMS.
- `scripts/build_camera.py`: local video derivative, source snapshot, fresh PDS run.
- `scripts/board_loader.py`: model/image UART transfer; never programs FPGA.

Do not use legacy `gen/ddr_model.bin`, `gen/layer_table.h`, or `gen/graph.json`.
The old linear-convolution packer now exits with an explicit error. The current
forward function executes all 85 graph operations.

## Offline checks

Run from `E:/file/pango/project/ai_lab`, using Python with torch:

```powershell
& 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' scripts/offline_check.py
```

The command invokes ModelSim and WSL GCC. Native C checks cover all 28 software
operators, with convolution outputs supplied by the arithmetic oracle. Four
actual deployment convolution layers are checked separately against RTL. These
are not a full-network RTL simulation or a board performance measurement.
An additional native C run executes all 85 operators continuously, using scalar
integer convolutions with the packed deployment parameters and no intermediate
oracle injection. This checks graph composition, not FPGA throughput.

Deployment arithmetic evaluation on the same 222-image labeled subset:
FP32 AP@0.5 0.3423, Q15 + software heads 0.3365. The new bounded C NMS and camera
decimation have not been evaluated on that full subset. This model recognizes
biodegradable/cardboard/glass/metal/paper/plastic, not hazardous waste.

## Build

```powershell
& 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' scripts/build_camera.py --run --synthesis-only
# Full implementation, only after resources fit:
& 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' scripts/build_camera.py --run
```

Each run snapshots RTL, CPU headers, firmware, and constraints into a fresh
`pds/camera_offline_*` directory. Vendor IP remains referenced from its source
installation. Firmware uses the existing 32 KiB program ROM and 16 KiB data RAM.
The camera candidate deliberately runs CPU and accelerator at the 27 MHz board
source; the teammate's future CPU can replace the core behind the same interface.

Video template currently generates 1280x720 timing. It is not a verified
1920x1080p60 solution; the folder name `hdmi1080p` is not evidence of that mode.
DVP root clocks now have an explicit 150 MHz conservative implementation
budget instead of PDS's inferred 1 MHz default. Actual sensor-clock frequency
and external input setup/hold still require hardware acceptance.

## Hardware bring-up, when board returns

1. Preserve the working CPU/video bitstreams. Run the vendor DDR BIST first.
2. Verify native DDR word-address convention and the relocated video region.
   Model is at byte 0x01000000, tensors at 0x02000000, video at 0x08000000.
3. Use only a candidate whose PDS resource report fits and whose setup/hold
   constraints pass. UART TX C24 and RX B24 follow the vendor 100H constraints.
4. Load the model and run a known static image, then compare returned boxes with
   the deployment oracle before enabling camera mode.

```powershell
# Board commands below require explicit --port; do not run offline.
python scripts/board_loader.py --port COM13 --image path/to/known-image.jpg
python scripts/board_loader.py --port COM13 --skip-model --camera --frames 1
python scripts/board_loader.py --port COM13 --skip-model --autonomous
```

The device checks the entire model CRC before inference. Autonomous mode runs
until an inference error or board reset. Snapshot capture freezes a 320x180
decimation of 1280x720 RGB565, letterboxes to 320x320, and returns the buffer only
after inference. Results overlay on live video, so boxes have inference latency;
there is no claim of exact frame matching or object tracking. OSD shows at most
eight results and expires them after 120 display frames.
Model loading is required after FPGA/DDR reset; there is no persistent Flash
model boot path. Host loading is not host inference: all inference remains on
the board. Allow minutes for the 115200-baud model transfer.

## Remaining acceptance limits

- Latest complete-top synthesis (`pds/camera_offline_20261030_174504`):
  36,869/66,600 LUT, 85/155 DRM, 135/240 APM. Routing/timing is not
  accepted merely because synthesis fits.
- That build failed regional camera-clock placement. A global clock buffer
  and explicit divided-clock constraint fix passed the isolated
  `pds/camera_clock_probe_run3` implementation; the updated full build is
  `pds/camera_offline_20261030_185538`.
- Updated full build routes, but its post-route summary says
  **Some Constraints Violated**: final report slow-corner sys_clk setup WNS
  -2.268 ns (`cpu/w_csr` to `data_cache/.../WE`), pixel-domain internal setup
  -0.398 ns, plus pixel/DDR cross-domain and
  reset recovery violations. This build is rejected for programming. It is
  not evidence that deployment is impossible; timing and CDC/reset closure
  remain required offline work, not something to defer to board testing.
  Generated `.sbit` is explicitly rejected; generation is not timing acceptance.
- Whole-system PDS resources/routing/timing must pass on the final CPU snapshot.
- No board DDR read/write, camera color/preprocessing, HDMI, or latency test yet.
- Software FP32 heads and mailbox transfers may be slow on RV32IM; no FPS promise.
- CPU startup/UART/MMIO readback passes in simulation, but full inference has not
  been executed by the simulated CPU.
- CoreMark/ILA contest evidence remains a separate CPU-team deliverable.
