# FPGA YOLO + CPU + AI Accelerator

## Current Board Status (2026-11-01)

- Target: MES2L676-100HP / PG2L100H; Vexii CPU and accelerator at 27 MHz.
- `release/board_perf4_20261101/`: programmed and tested. Model upload/CRC and
  camera inference replies pass; the latest camera request took 4.953 seconds.
- `release/board_perf5_20261101/`: newer optimized candidate. PDS timing and
  package verification pass; this candidate has not been board-tested.
- **HDMI remains blank on the user's monitor. Display acceptance has failed.**
  Neither release is a fully accepted contest deliverable.
- Model: YOLOv5n, 320 input, six classes: biodegradable, cardboard, glass,
  metal, paper, plastic. It has no hazardous-waste class.

## Files And Dependencies

- `rtl/`, `sw/`, `tb/`, `scripts/`: accelerator/SoC RTL, CPU firmware, tests,
  model export, quantization, packing, programming and board tools.
- `data/models/yolov5n-garbage.pt`: original selected checkpoint.
- `gen/integration/deployment/`: integer model parameters and graph contract.
- `gen/integration/packed/`: DDR model, memory map and generated C model table.
- `release/board_perf{4,5}_20261101/`: matched bitstream, firmware, model,
  constraints, timing evidence, checksums and standalone UART loader.
- `../project/pds_native_120/`: CPU checkout referenced by the Vexii generator.
- `../video/hdmi1080p/`: copied video source/IP/constraints; the camera generator
  prefers this repository copy over its historical absolute path.
- `pds/vexii_camera_20261101_{171914,181152}/sources/`: accepted source snapshots.
  Tool databases, downloaded datasets and installed Python packages are excluded.
- `STATUS.md`: results and limitations; T55 records the latest board state.

## Programming

Run from this directory with Python 3.11 and pyserial installed. First verify
`scripts/package_release.py --verify --out release/board_perf4_20261101`.
Start the PDS `cdt_js.exe` JTAG server on port 65420, then use
`scripts/program_board.py --sbit release/board_perf4_20261101/bitstream.sbit
--out sim/<unique-run>/program`.

After every FPGA/DDR reset, upload the model using
`scripts/board_loader.py --package-dir release/board_perf4_20261101 --port COM13`.
Then use the same command with `--skip-model --camera --frames 3` for camera
requests. Firmware is already embedded in the bitstream. The current video mode
is 1280x720@60, and the physical cable must use HDMI OUT.

The existing build scripts contain local PDS, ModelSim and RISC-V GCC paths;
adjust these tool paths on another machine. Model scripts also need NumPy,
OpenCV, PyTorch, torchvision and the `yolov5` checkpoint package. The standalone
loader's dependencies are listed in each release's `loader_requirements.txt`.

## Historical Workspace Notes

本目录只做赛题 AI 应用的小规模可行性验证，**独立于 `firmware/code`**：

- 不修改另一名 AI 正在处理的 CPU RTL、公共连接文件、`docs/` 下的正式文档；正式集成阶段才统一改公共文件。
- 下载串行进行，避免与另一 AI 争用下载工具；每个下载记录 URL、字节数、SHA256。
- 状态记录：本文件下方与 `STATUS.md`；错误写入 `logs/`；不建多份重复报告。
- 数据布局：`data/models/` 权重，`data/images/` 独立测试图片，`data/raw/` 原始包，`scripts/` 可复现脚本，`results/` 结果表与原始输出，`rtl/`、`tb/`、`sim/` 最小计算电路，`logs/` 运行日志。
- 数字标注：`实测`=本次运行/PDS 报告得到；`估计`=由实测或结构推算，不得写成已验证。

## 开始/完成/错误约定

| 状态 | 含义 | 记录位置 |
|---|---|---|
| RUNNING | 已开始、未完成 | `STATUS.md` 对应任务行 |
| DONE | 完成且有原始证据（日志/文件哈希/结果表） | `STATUS.md` + `results/` |
| FAILED | 失败，记录错误与下一步 | `STATUS.md` + `logs/` |

任务编号：T1 现成模型、T2 PC 对照、T3 YOLO-Fastest 逐层预算、T4 最小计算电路与 PDS、T5 固定图片 vs 摄像头边界、T6 集成约定。
