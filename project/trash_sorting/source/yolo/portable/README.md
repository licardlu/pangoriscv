# 两个 009 / 052 的区别

`build_pre_pnr.tcl` 只选 **`portable/`** 下的这两个文件，**不选** `sources/` 下的同名文件。

| 文件 | 是否进综合 | 说明 |
| --- | --- | --- |
| `portable/009_Ram.v` | ✅ | 程序 ROM，`$readmemb("firmware_laneN.bin", ...)`。路径是**裸文件名**，所以综合时进程当前目录必须是 `sources/`——`build_pre_pnr.tcl` 开头已经 `cd` 过去 |
| `portable/052_yolo_camera_top.v` | ✅ | 27 MHz 板级顶层，含按键、舵机、I2S 音频端口 |
| `sources/009_Ram.v` | ❌ | 上游历史快照，里面写死了 `E:/file/pango/.../firmware_laneN.bin`，在别的机器上必然找不到 |
| `sources/052_yolo_camera_top.v` | ❌ | 上游历史快照，`sys_clk` 注释还是 50 MHz 版，端口比 portable 版少 |

## 为什么留着历史快照

`source/SHA256SUMS.txt` 和 `manifest.json` 记录的是上游资料包的原始状态，删掉就没法回溯"这份 IP 是从哪里来的"。它们不参与构建，但会在 grep 时冒出来，所以单独写这一页说明。

## 判断依据

```powershell
# 看 tcl 到底选了谁
Select-String -Path build_pre_pnr.tcl -Pattern '009_Ram|052_yolo_camera_top'
```

```
add_design [file join $pkg_dir portable 009_Ram.v]
add_design [file join $pkg_dir portable 052_yolo_camera_top.v]
```

如果改了 `sources/` 下的版本却发现综合没变化，原因就在这。
