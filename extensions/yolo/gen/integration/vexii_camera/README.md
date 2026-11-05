# `gen/integration/vexii_camera/` —— 93.461538 MHz 上游候选

**这是上游候选，不是交付位流。** 本目录由
`scripts/generate_vexii_camera.py --cpu-hz 93461538` 生成（见 `provenance.json`
的 `cpu_hz` 与 `board_verified: false`）：CPU 与加速器跑 93.461538 MHz，视频走
`hdmi1080p` 模板。交付给评委的位流是 **27 MHz v3**（`project/trash_sorting/` 下的
`sources/042_conv_band_rt.v` + `software/platform_main.c`），时钟与源码版本都不同。

因此：

- 不要用这里的 `yolo_camera_top.v` 推断交付位流的时序、功耗或帧率；
- 它从未上板验证（`board_verified: false`），也没有被 `package_release.py` 收录；
- `yolo_camera_top.v` 里的 `PROGRAM_INIT_FILE` 现在是相对本文件的
  `../../vexii_firmware/program.hex`，是为了不携带原机器的绝对路径；用 PDS 从别的
  目录编译时请改成当前机器的绝对路径，重新运行生成脚本会自动写入当前机器路径。
- 重新生成需要上游视频模板（`VIDEO_SRC` 指向 `hdmi1080p`），本交付包未附带该目录。
