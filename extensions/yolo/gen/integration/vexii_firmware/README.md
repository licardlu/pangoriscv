# `gen/integration/vexii_firmware/` —— 93.461538 MHz 上游候选固件

**这是上游候选固件，不是交付位流里的固件。** `manifest.json` 记录
`cpu_hz: 93461538`、`board_verified: false`，对应上一条 93.461538 MHz 的
`vexii_camera` 候选；交付的 v3 位流用的是 27 MHz 固件
（`project/trash_sorting/source/yolo/software/platform_main.c`）。

- 重新生成：`python scripts/build_firmware.py --platform vexii --cpu-hz 93461538`
  （需要 RISC-V GCC，用 `RISCV_GCC_BIN` 或 `--gcc` 指定）。
- `program.hex` 的 SHA256 与 `manifest.json` 的 `program_sha256` 绑定；换机器重建后
  务必比对，否则 `build_vexii_camera.py` 会直接拒绝该固件。
- 未上板，不要用这里的 `rom_bytes`、栈深度或 `.su` 结果推断 27 MHz 交付固件。
