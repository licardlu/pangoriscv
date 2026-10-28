# M0：单路 OV5640 + HDMI 显示验证（原始记录）

**日期**：2026-10-28 13:23
**位流**：厂商 `HDMI_DDR3_OV5640_100H/generate_bitstream/CMOS1.sbit`（3,791,112 B）。
已复制为 `pangoriscv-verify/bitstreams/vendor_CMOS1.sbit`——原路径含中文，
烧录执行环境会把它转成 `??` 并报 `sbit file does not exist`，**必须走 ASCII 路径**。
**脚本**：`pangoriscv-verify/measure.ps1 -Sbit .\bitstreams\vendor_CMOS1.sbit -ComPort COM13`

## 烧录结果（软件侧可确认部分）

| 项 | 实测 |
|---|---|
| JTAG 线缆 | `USB Cable II / fffffffffffffffe` |
| 器件识别 | `PG2L100H` |
| 编程进度 | 0% → **100%** |
| done bit（编程后） | **1** |
| `cfg_program` | successfully，`program OK: 1` |
| UART | 空（该设计不输出串口，符合预期） |

原始日志：`pangoriscv-verify/runs/cfg_vendor_CMOS1_*.log`

## 待人工确认（软件无法判定）

- [ ] HDMI 显示器是否出图
- [ ] DDR3 初始化是否完成（出图即代表通过）
- [ ] 图像是否稳定（无花屏、无撕裂、无闪烁）
- [ ] 实际接的是哪一路摄像头（CMOS1 位流；CMOS2 作为备用）

## 恢复 CPU 交付位流

```powershell
cd pangoriscv-verify
.\measure.ps1 -Sbit .\bitstreams\pangoriscv_v40_o3_4000_5p26.sbit -ComPort COM13 -FreqMhz 50
```

SHA256 已核对：`286e3815cb8523e3a94b32f92369db0c7f76d37fc8ab79404d91aceb3842d548`

**注意**：`cfg_program` 写的是 SRAM，掉电即失效，重新上电需重烧。
