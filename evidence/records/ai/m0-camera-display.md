# M0：单路 OV5640 + HDMI 显示验证

**状态：通过（2026-10-28 18:42）**

## 结论

摄像头在 1280×720@60 下稳定出图，经 HDMI 全屏显示，颜色与几何正确。

**最终根因是硬件，不是代码**：FMC 子卡 **J20 跳线帽一根都没插**，摄像头所在的
Bank L6 完全没有供电。跳线帽插上后立即出全幅图像，此前所有"位流/时序/分辨率"
方向的怀疑都是伪线索。

## 跳线（唯一正确接法）

| 位置 | 接法 | 说明 |
|---|---|---|
| **J20** | 跳线帽跨「中间脚 + 靠 ADJ 那脚」 | 中间脚是 Bank L6 的供电输入，两边是候选电源。**3V3 那脚必须空着**，短接两边 = 电源并联，会烧 |
| **J24** | 跳线帽接 2V5 | ADJ = 2.5 V |
| **J15**（6 螺丝端子） | 空着 | 12 V 输入，与旁边 DC 圆头插座二选一，中间 NC 组不接 |

判断依据是丝印，不是"左右"：从丝印 `3V3` 那一头往外数第 1/2/3 根。

## 设计形态（相对厂商 demo 的改动）

厂商 demo 本身跑不起来（烧 `vendor_CMOS1.sbit` 显示器判"无信号"），因此在
`hdmi1080p/` 下重建为原生 720p：

| 项 | 厂商 demo | 现在 |
|---|---|---|
| 显示光栅 | 720p30（`RATIO0=8` 配错，实际 37.125 MHz） | **1280×720@60，1650×750，74.25 MHz** |
| 像素时钟 | — | `RATIO0=16`（VCO 1188 ÷ 16） |
| 帧缓冲 | `H_NUM=1280 / V_NUM=720 / PIX16` | 不变，本来就对齐 |
| 帧切换 | 读写各自自由跑 | 读侧在自身 vsync 锁存**写侧刚写完的帧**（乒乓） |

改频点必须**同时**改 `ipcore/pll/pll.idf` 和 `ipcore/pll/pll.v`：
PDS 不会按 `.idf` 重新生成 IP，它直接分析现成的 `pll.v`，只改 idf 不生效。

## 验收证据（串口遥测，不依赖人眼）

`hdmi1080p` 内置 115200 8N1 遥测（`uart_cam_report`，引脚 C24），每约 1 s 发一帧：

```
W=0A00  L=02D0  A=FF  S=3  C=1  R=166  P=3
```

| 字段 | 含义 | 正常值 | 含义 |
|---|---|---|---|
| `W` | 每行 DE 的 pclk 数 | `0A00` = 2560 | ÷2 = **1280 像素** |
| `L` | 每帧 DE 行数 | `02D0` = 720 | **720 行** |
| `A` | 两路 vsync 活动计数 | `FF` | 两路都在出流 |
| `S` | SCCB 完成位 | `3` | 两路配置完成 |
| `C` | 通道选择 | `1` | 选中 CMOS1 |
| `R` | 已写寄存器数 | `166` = 358 | 含新增的 `0x5308` |
| `P` | `{SCL,SDA}` | `3` | 总线空闲为高 |

**供电缺失时的特征**：`W` 掉到 ~700 且逐帧在 672–736 之间乱跳，`L` 仍是 720。
这个组合是"DE 抖动"的指纹，可直接用于下次排障。

## 画质处理

1. **补 `0x5308 = 0x25`**（CIP 锐度自动使能）。厂商表里 `0x5300–0x530c` 的
   锐化/降噪参数与 OmniVision 应用笔记完全一致，唯独漏了这一条使能位，
   等于整段锐化从未生效。
2. **RGB565→RGB888 改位复制**：原 `{R[4:0],3'b0}` 白色上限只有 248 且有色阶，
   改 `{R[4:0],R[4:2]}` 后白色 255、灰阶连续。
3. **修撕裂**：写侧 `wr_buf.rd_frame_cnt` 与读侧 `rd_buf.wr_frame_cnt` 都在
   `ddr_clk` 域里各自按自己的 vsync 翻转，摄像头（24 MHz 晶振）与 FPGA（50 MHz）
   同为 ~60 Hz 但不同源，相位缓慢漂移 → 撕裂缝缓慢滚动。改为读侧在 `wr_rst`
   锁存 `~wr_frame_id[0]`，即"上一帧完整帧"，画面内帧号恒定。

摄像头寄存器已核对与帧缓冲一致：`0x3808/09=0x0500`(1280)、`0x380A/0B=0x02D0`(720)、
`0x4300=0x60`(RGB565)、`0x3814/3815=0x31`(无下采样)、`0x3821=0x00`(无 binning)。
颜色链路 `{d[4:0],d[10:5],d[15:11]}` + 输出 `[15:11]→R` 实测**颜色正确**，不要动。

## 位流

| 文件 | 用途 |
|---|---|
| `pangoriscv-verify/bitstreams/video720p_q1.sbit` | **当前工作版本**（720p60 + 画质 + 乒乓） |
| `pangoriscv-verify/bitstreams/video720p_native.sbit` | 720p60，画质修复前（对照用） |
| `pangoriscv-verify/bitstreams/video720p_ddrpat.sbit` | DDR3 自测图案，摄像头旁路（排障用） |
| `pangoriscv-verify/bitstreams/vendor_CMOS1.sbit` | 厂商原样，本板无信号（仅存档） |

烧录：

```powershell
cd pangoriscv-verify
.\capture_cam.ps1 -Sbit .\bitstreams\video720p_q1.sbit -CaptureSec 8
```

`cfg_program` 写的是 SRAM，掉电即失效，重新上电需重烧。

## 已知限制

- **只有 CMOS1 上屏**。顶层用 `sel_cmos1 = cam1_ok` 二选一，CMOS2 的数据不进
  `fram_buf`，遮住它屏幕无变化属正常。且 `cam1_act` 是饱和计数器，
  `cam1_ok` 一旦置位永久保持 → 运行中 CMOS1 掉线**不会**自动切到 CMOS2。
- 摄像头 DVP 8-bit 每像素 2 字节，有效像素率 = pclk÷2。当前 pclk 84 MHz → 42 Mpix/s
  → 1280×720@60 已用满。上到 1080p30 需 pclk 124 MHz，超过 OV5640 的 ~96 MHz 上限，
  所以本板 1080p 实际只能到 20~25 fps。
- `camera_pwnd` 在顶层悬空，PWDN 引脚无人驱动。
- `reg_config` / `i2c_com` 都不校验 ACK，`cmos_init_done` 可能假性为真
  （本次 `P=3` 说明总线正常，未触发该风险）。

## 原始记录（2026-10-28 13:23，厂商位流阶段）

| 项 | 实测 |
|---|---|
| JTAG 线缆 | `USB Cable II / fffffffffffffffe` |
| 器件识别 | `PG2L100H` |
| 编程进度 | 0% → **100%** |
| done bit（编程后） | **1** |
| UART | 空（该设计不输出串口，符合预期） |

原路径含中文会让烧录环境把路径转成 `??` 并报 `sbit file does not exist`，
**必须走 ASCII 路径**。

## 恢复 CPU 交付位流

```powershell
cd pangoriscv-verify
.\measure.ps1 -Sbit .\bitstreams\pangoriscv_v40_o3_4000_5p26.sbit -ComPort COM13 -FreqMhz 50
```

SHA256：`286e3815cb8523e3a94b32f92369db0c7f76d37fc8ab79404d91aceb3842d548`
