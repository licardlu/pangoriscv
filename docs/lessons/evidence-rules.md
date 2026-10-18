# 证据口径规则（引数之前先读这一页）

> 这一页是从独立复核发现的问题里总结出来的。**凡是往文档里写数字，都按这里取。**

## 1. slack / 频率：只从 `multiseed_summary.csv` 取

PDS 每次运行会在 `place_route/` 下留一份
`pangoriscv_top_timing_summary_after_hold_fix.txt`，**那是中间快照，
不是最终结果**。收尾还会有一轮优化，通常"用 setup 换 hold"：

| 实测例子 | 中间快照 | 官方收尾（multiseed） |
|---|---|---|
| P16 27 MHz | +15.404 / +0.025 | **+15.267 / +0.030** |
| P16 50 MHz | +0.862 / +0.087 | **+0.703 / +0.242** |

两者都是 `All Constraints Met`、0 失败端点，但**数字不同**。
独立复核重跑得到的是 multiseed 那一组，所以：

> **引用 slack → `multiseed_summary.csv` 的 `single` 行第 4/6 列
> （Setup(Slow) / Hold(Slow)）；并把文件名写进文档。**

## 2. LUT：必须写阶段

同一份实现三个阶段三个数（P16 27 MHz 实测）：

| 阶段 | 出处 | LUT |
|---|---|---|
| synthesis | `synthesize/run.log` 的 Mapping Summary | 13,574 |
| **device_map** | `multiseed_summary.csv` 的 `Used` 行 | **13,444** |
| post-PnR | 布线后报告 | 13,389 |

**报 ③ 时必须写"取自哪个阶段"**，且分数换算用同一个数：

- 13,444 → 2.6740 / 13.444 = **0.1989** CoreMark/kLUT
- 13,574 → 0.1970
- 13,389 → 0.1997

本项目的默认口径：**用 device_map（13,444 → 0.1989）**，
因为它是 Pango 资源报告的常规阶段、且在官方 multiseed 里可直接核对。

## 3. 仿真 ≠ 成绩

仓库有强制策略：`.gitignore` 排除 `evidence/records/coremark-sim-*/`，
`.githooks/pre-push`（已启用）拦截含该路径的提交。依据是赛题 §4：

> 分数必须来自 FPGA 上真实运行，仿真数据不能替代实测。

所以：
- 仿真 ticks / CoreMark/MHz 可以说"这是 RTL 仿真的测量结果，可精确复现"；
- **不能说"成绩"**，不能进任何成绩表而不加声明；
- 每份含仿真跑分的文档，**顶部必须有"仿真口径、非有效成绩"的声明**。

## 4. 串口输出块只贴原文

固件因为 `core_portme.h` 里 `HAS_FLOAT 0`：

- `Total time (secs)` = `floor(ticks / CPU_FREQ_MHZ / 1e6)` —— **整数截断**
- `Iterations/Sec` = `iterations / 上面那个整数` —— **被截断放大**
- `CoreMark 1.0 : <score>` 那一行**根本不打印**（包在 `#if HAS_FLOAT` 里）

因此：

| 项 | 能不能用 |
|---|---|
| `Total ticks` | ✅ **唯一可用**的分数来源：`iterations / ticks × 1e6` |
| 五项 CRC + `Correct operation validated` | ✅ 直接引用 |
| `Total time` / `Iterations/Sec` | ❌ 只作原始输出展示，**不能反推分数** |

⚠️ 用被截断的 `Iterations/Sec` 算分会**虚高**：P16 用 76 算得 2.8444，
比真值 2.6740 高 **6.4%**。

## 5. CRC 的准确说法

- `seedcrc` 决定 `known_id`；官方强制比对 **`crclist` / `crcmatrix` / `crcstate`**；
- `crcfinal` 是**跨迭代累积值，没有官方黄金表**，随迭代数变化
  （20→0x4983、400→0x25b5、512→0xdfc8、576→0x7b65、640→0x382f、768→0x3c53）；
- 所以别写"五项全部正确"，应写
  **"三项与官方已知表一致，另两项与确定性累积链一致"**。

## 6. 迭代数必须重算

每次性能变化都要按 `N ≥ ceil(10.5 × 1e6 × 频率 / 每迭代ticks)` 重算并留余量：

| 轮次 | 每迭代 ticks | 下限 | 实取 | 实际时间 |
|---|---|---|---|---|
| P9 | 479,774 | 592 | 640 | 11.37 s |
| P10 | 421,798 | 673 | 768 | 12.00 s |
| P13 | 389,504 | 728 | 768 | 11.08 s |
| P14 | 382,986 | 741 | 768 | 10.89 s |
| P16 | 373,973 | 759 | 768 | 10.64 s |

## 7. 百分比写清对象

> 反例："ticks −2.43%"。真相：ticks 降 **2.35%**，2.42% 是 **CoreMark/MHz** 的增幅。

正确写法：**"ticks 7,658,647 → 7,478,647，−2.35%；换算 CoreMark/MHz 2.6109 → 2.6740，+2.42%"**。

## 8. 一个实现 = 一个目录

跑 PDS 之前先建目录，跑完把这一整套搬进 `evidence/`：

```
pangoriscv_top.sbit          + SHA256
run.log / flow.log
multiseed_summary.csv        ← 权威 slack 与 LUT
report_timing/*.rtr          ← report_timing 原始报告
device_map/run.log           ← 资源表
compile/run.log
<镜像>/manifest.json         ← 编译命令、flags、迭代数
```

**同一个目录不要跑第二个频率/第二次实现**——会把证据覆盖掉（问题 C05 就是这么来的）。
