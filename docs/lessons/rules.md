# 引数口径与动手清单

> **遇到问题先查 [`mistakes-log.md`](mistakes-log.md)**（按现象组织的可复用经验），
> 再来这里核对口径与清单。目录放置/清理规矩看 skill 的
> 「仓库放置与清理约定」一节。

## 一、引数口径

### 1. slack / 频率：只从 `multiseed_summary.csv` 取

PDS 会在 `place_route/` 留 `pangoriscv_top_timing_summary_after_hold_fix.txt`，
**那是中间快照**。收尾还有一轮优化，通常"用 setup 换 hold"：

| 实测 | 中间快照 | 官方收尾（multiseed） |
|---|---|---|
| P16 27 MHz | +15.404 / +0.025 | +15.267 / +0.030 |
| P16 50 MHz | +0.862 / +0.087 | +0.703 / +0.242 |
| P17 27 MHz | 17.390 | **+14.578 / +0.115** |
| P17 50 MHz | — | **+1.262 / +0.121** |

两者都是 `All Constraints Met`、0 失败端点，但**数字不同**。
> **引 slack → `multiseed_summary.csv` 的 `single` 行第 4/6 列（Setup(Slow)/Hold(Slow)），并把文件名写进文档。**

### 2. LUT：必须写阶段

同一实现三个阶段三个数（P17 27 MHz）：

| 阶段 | 出处 | LUT |
|---|---|---|
| synthesis | `synthesize/run.log` Mapping Summary | 13,574 |
| **device_map** | `multiseed_summary.csv` 的 `Used` 行 | **13,481** |
| post-PnR | 布线后报告 | 更小 |

**默认口径：device_map**（Pango 资源报告常规阶段，且官方 multiseed 里可核对）。
换算用同一个数：`2.6757 / 13.481 = 0.1985 CoreMark/kLUT`。

### 3. 仿真 ≠ 成绩

`score = iterations / ticks × 1e6` 里的 ticks 可以来自 RTL 仿真，但：
- 可以说"RTL 仿真的测量结果，可精确复现"；
- **不能说"成绩"**，不得进成绩表而不加声明；
- 仓库有强制策略拦截（`.githooks/pre-push` 拦 `evidence/records/coremark-sim-*`），依据赛题 §4。

每份含仿真跑分的文档，**顶部必须有"仿真口径、非有效成绩"声明**。

### 4. 串口输出块只贴原文

固件 `core_portme.h` 里 `HAS_FLOAT 0`：

- `Total time (secs)` = `floor(ticks / 频率)` —— **整数截断**
- `Iterations/Sec` = `iterations / 那个整数` —— **被截断放大**
- `CoreMark 1.0 : <score>` 那行**根本不打印**

| 项 | 能不能用 |
|---|---|
| `Total ticks` | ✅ **唯一可用**的分数来源 |
| 五项 CRC + `Correct operation validated` | ✅ 直接引用 |
| `Total time` / `Iterations/Sec` | ❌ 只作原始展示，**不能反推分数** |

⚠️ 用被截断的 `Iterations/Sec` 算分会**虚高**：P16 用 76 算得 2.8444，比真值 2.6740 高 6.4%。

### 5. CRC 的准确说法

- 官方强制比对 **`crclist` / `crcmatrix` / `crcstate`**；
- `crcfinal` 是**跨迭代累积值、没有官方黄金表**，随迭代数变
  （20→0x4983、400→0x25b5、512→0xdfc8、576→0x7b65、640→0x382f、768→0x3c53）；
- 所以写 **"三项与官方已知表一致，另两项与确定性累积链一致"**，不要写"五项全部正确"。

### 6. 迭代数必须重算

`N ≥ ceil(10.5 × 1e6 × 频率 / 每迭代ticks)`，留余量：

| 轮 | 每迭代 ticks | 下限 | 实取 | 实际时间 |
|---|---|---|---|---|
| P9 | 479,774 | 592 | 640 | 11.37 s |
| P10 | 421,798 | 673 | 768 | 12.00 s |
| P13 | 389,504 | 728 | 768 | 11.08 s |
| P14 | 382,986 | 741 | 768 | 10.89 s |
| P16 | 373,973 | 759 | 768 | 10.64 s |
| P17 | 373,738 | 759 | 768 | 10.63 s |

### 7. 百分比写清对象

> 反例："ticks −2.43%"。真相：ticks 降 **2.35%**，2.42% 是 **CoreMark/MHz** 的增幅。

正确：**"ticks 7,658,647 → 7,478,647，−2.35%；CoreMark/MHz 2.6109 → 2.6740，+2.42%"**。

### 8. 一个实现 = 一个证据目录

```
pangoriscv_top.sbit          + SHA256
run.log / flow.log
multiseed_summary.csv        ← 权威 slack 与 LUT
report_timing.rtr
device_map/run.log
compile/run.log
<镜像>/manifest.json         ← 编译命令、flags、迭代数
```

同一个目录**不许跑第二次实现**（问题 C05 就是这么丢掉交付位流的证据的）。
**先跑 50 MHz，最后跑 27 MHz**，这样交付频率的产物留在目录里。

---

## 二、动手清单

### 读测试结论之前（2026-10-18 教训）

- [ ] **确认判据能变红**：runner 的 PASS 必须是"看到了 `TEST_PASS <标记>`"（白名单），
      不能是"没看到 `FAIL` 字样"（黑名单）。本项目曾有 5 个 runner 因为日志带 `# ` 前缀
      而永远匹配不到 FAIL，**所有 dcache/perf 的 PASS 都是假的**。
- [ ] 看到"全绿"时，随机把一处 RTL 改回旧版本，确认**测试真的会失败**，再相信绿灯。
- [ ] 新写的用例要覆盖**奇/偶两种次数**（饱和计数器、往返计数这类）。

### 开工前
- [ ] `git status` 干净；`git log --oneline -3` 看清基线
- [ ] `python tools/set_switches.py status` 记下开关状态
- [ ] 读 `docs/verification.md` §2 问题台账，确认要动的地方有无未修编号项
- [ ] 动 RTL 前确认七个探针还在：`SCORE_WINDOW` / `EX_SPLIT` / `DCACHE_PATH` /
      `ICACHE_PATH` / `ADDR_REGION` / `MISPRED_MIX` / `LSU_REQ_SPLIT`

### 改 RTL 之前
- [ ] **先量**：跑 20 迭代 A/B，记下 `ticks`/`if_wait`/`i_miss`/`d_miss`/`request_store`
- [ ] 想清楚对**读和写两条路**分别意味着什么
- [ ] 想清楚会"绕过"哪些状态，那些状态里有哪些副作用（LRU/计数器/握手标志/错误码）
- [ ] 确认只改一个变量

### 改完立刻验（按序，别跳）
- [ ] `run_unit_tests.py --case all` → 5/5
- [ ] `run_dcache_tests.py` / `run_icache_tests.py`
- [ ] `run_isa_e2e.py --cases all` → 15/15（开关 ON）
- [ ] `run_ram_tests.py --seeds 20` → 40/40
- [ ] `run_halt_reset_tests.py` → 5/5
- [ ] `run_ifu_engine_tests.py --seeds 20` → 20/20
- [ ] 20 迭代 A/B：基线取**改动前**的提交；**五项 CRC 逐项相同**
- [ ] 看 `d_miss`/`i_miss` 有无异常变化（R03 就是靠这个发现的）

### 出交付数据
- [ ] 三开关 ON，`status` 确认
- [ ] 按 §6 重算迭代数
- [ ] 建**独立** PDS 目录；先 50 MHz 后 27 MHz
- [ ] 归档整套（§8）
- [ ] slack/LUT 按 §1/§2 取，标明阶段
- [ ] 768 迭代跑分，确认 `Correct operation validated`，五项 CRC 逐个记录

### 写文档
- [ ] 串口块只贴原文（§4）
- [ ] 百分比写清对象（§7）
- [ ] 仿真数据处加声明（§3）
- [ ] CRC 按 §5 表述
- [ ] "本版/上一版"指代检查，表格查重复行

### 提交前
- [ ] `set_switches.py off` 并确认
- [ ] `git status` 只有预期文件；RTL/TB 净改动逐个 `git diff` 看过
- [ ] 自己写的 markdown 扫 BEL/ESC 等控制字符
- [ ] CSV 每行列数 = 表头列数
- [ ] 位流 SHA 与文档一致
- [ ] 全仓 grep 旧值残留（`1.35`、`F8254F66`、`i512`、被替换的当前值等）
- [ ] 项目根目录/仓库外没有 `_*.py`/`_*.txt` 临时件
- [ ] 证据文件是 UTF-8（不是 UTF-16LE）

### 绝对不做
- ❌ 把仿真跑分当成绩报/推送
- ❌ 在"原始输出"块里填自己算的数
- ❌ 用被截断的 `Iterations/Sec` 反推分数
- ❌ 用 HEAD 当 A/B 基线
- ❌ 同一个 PDS 目录跑两次实现
- ❌ 解释不清的行为差异硬上线
- ❌ 引中间时序快照的 slack
- ❌ 报 LUT 不写阶段
