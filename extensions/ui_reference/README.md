# 简化源码交付包

本源码 ZIP 使用用户新给的 YOLO/RTL 基线 `pre_pnr_source_20261103_002112`，包含本次识别框修改和应用扩展。原始输入与修改边界见 `extensions/business/application/docs/本次修改与验证.md`。

- `yolo/` 保存输入包里的预 PnR 源快照、模型输入、IP 源码、`platform_main.c`、`test_bbox_osd.c` 和 `tb_bbox_osd.v`。
- `extensions/business/` 保存视觉/OSD、摄像头预览、分类映射源码、按键答题与 +100 会话积分逻辑、专项测试，以及 WAV 解析/播放排空支持、I²S 发送器和四种提示音及三种音乐 WAV。
- 正确答案固定播放 `MUSIC0.WAV`，经 `audio_bclk/audio_lrclk/audio_data` 输出到外接 I²S 功放；舵机控制仍不进入包。
- 不包含二维码登录、账户持久化账本、PnR 数据库、ELF 和位流。
- 本版采用白色亮系左右分屏；右侧 640×720 使用原生实时视频中心裁剪并保留 YOLO 框。三句中文提示音已重生成；详情见 `extensions/business/application/docs/白色分屏与提示语音.md`。

输入清单与当前 `software/platform_main.c` 不同的情况会在 `manifest.json` 的 `baseline.checksum_exceptions` 中记录原始/当前字节数和 SHA-256；其他清单文件仍逐项严格校验。

本包是源码交付物，不代表完成布局布线或实板验收。静态校验只依赖 Python 标准库，不需要 RISC-V 工具链、PDS、仿真器、串口或开发板。

重要：本包仍是源码交付物，未执行布局布线、位流生成或实板验收；输入快照中的 ROM 镜像不能代表本次 C/RTL 修改已经烧录。本次已把实时分屏接入 `portable/052_yolo_camera_top.v`；应用积分与音频状态还需总线/按键/音频时钟接口适配，新顶层暂接启动默认值，不能直接烧录验收积分与音频两项功能。

## 离线静态复核

```powershell
python tools_simplified/build_source_package.py --verify <source-package.zip>
```

包内自带打包与校验脚本；静态校验无需工具链。

## 重新生成源码 ZIP

```powershell
python tools_simplified/build_source_package.py `
  --baseline-root <pre_pnr_source_20261103_002112> `
  --repo-root <board_system> `
  --out <source-package.zip>
```

脚本核对输入包中的 checksums 与 source manifest，并拒绝覆盖已有输出。`manifest.json` 记录基线身份及每个交付文件的 SHA-256；`SHA256SUMS.txt` 校验清单和全部包内文件。输入相同则 ZIP 内容可复现。
