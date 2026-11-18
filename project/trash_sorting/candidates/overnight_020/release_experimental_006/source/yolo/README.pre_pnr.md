# Pre-P&R 源码包说明

本包是 `vexii_camera_20261103_000352` 的 seed-1 构建在开始布局布线前抓取的源码快照。

## 内容

- `sources/`：抓取时的 RTL、include、FDC、固件和 CPU ROM 镜像，与 `source_manifest.json` 一致。
- `portable/009_Ram.v`：同一份 RAM RTL，仅把八路 ROM 镜像路径由机器绝对路径改成包内裸文件名。
- `portable/052_yolo_camera_top.v`：抓取的顶层 RTL，仅把固件参数改成包内的 `program.hex`。
- `build_pre_pnr.tcl`：可重定位的 PDS 流程，止于 `dev_map`；不执行布局布线、时序报告或位流生成。
- `ipcore/`：DDR3、PLL、读写帧缓存 IP 引用的 IDF 与源文件。
- `software/`：固件与 YOLO 运行时源码。
- `model/`：打包后的模型及其图/内存元数据。
- `source_manifest.json`：抓取时记录的原始源码路径与 SHA-256。

## 构建边界

本包只覆盖布局布线之前。它不含 P&R 数据库或位流，也没有经过上板验证。打包时 seed-1 构建仍在进行；打包过程只读取其源码目录，没有改动或中止该构建。

Tcl 使用包内源码树，并把工作目录切到 `sources/`，使 ROM 镜像文件名按包内相对位置解析。这是必需的：`$readmemh/$readmemb` 按进程当前目录解析，`portable/009_Ram.v` 用的是裸文件名，`trash_voice_rom_player.v` 用的是从 `sources/` 往上两级的路径。综合前若不切目录，ROM 会全 0 且工具不报错。流程需要 Pango PDS 2022.2 和流程内写明的目标器件设置。

`sources/009_Ram.v` 的抓取原样保留以便审计；构建脚本选的是 `portable/009_Ram.v`，避免指向原机器路径。

`software/` 与模型元数据是打包时工作文件的副本，不声称是抓取固件的冻结输入；构建实际使用的固件保留在 `sources/` 下。

## 与已烧录 v3 位流的关系

本快照**不是**板上 v3 位流的输入集，两者要分开表述：

- 本包来源：`vexii_camera_20261103_000352` 的 seed-1 构建，止于映射。
- 已烧录 v3 位流：`build_camera_servo_v3_seed3_20261103`，seed-3，P&R 从包外映射后 ADF（`mapped_input/yolo_camera_top_map.adf`）起跑，SHA256 为 `2b98f90fbd0b4fd2de4074e74cb2c4aa8886d6009aa12bba4dfaf5d071bc4657`。

因此本包不能用来逐位重建那份位流；v3 的局部顶层/前端与下载记录见 `../../variants/v3_programmed_reference/`。
