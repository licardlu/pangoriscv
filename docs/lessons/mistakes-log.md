# 错误逐条记录

> 每条写三样：**发生了什么 / 根因 / 以后怎么做**。
> 只记我（AI 代理）自己造成的错误；他人/历史遗留问题在
> `docs/verification/issue-register-2026-10-18.md` 里编号登记。

---

## A. 改了代码但改错

### M01 · 同拍应答忘了读写分流 → 死锁

- **表现**：P10 首版跑 CoreMark 在 PC `0x2c0`、退休 5124 条后完全停摆。
- **根因**：`accept_hit` 没加 `!req_write`。一次**缓存写命中**被当成"读同拍应答"，
  LSU 以为完成并退休，而 dcache 同时走进 `ST_WR_REQ` 开始写事务；随后
  `ST_WR_HOLD` 等 LSU 的 `b_ready`，LSU 早已不在 `WRITE_WAIT` → B 永远没人接。
- **以后**：**任何"同拍应答/提前完成"的快捷路径，第一件事是确认它对读/写两种操作
  都成立**；把 writer 排除掉再谈优化。写完立刻用最短的 CoreMark 窗口（20 迭代）验，
  不要等全量跑分。

### M12 · 快命中路径跳过了 LRU 更新（我引入的回归，独立复核 R03 发现）

- **表现**：`d_miss` 4,655 次。文档声称"2 路 LRU"，实际大多数命中不更新替换信息。
- **根因**：P10 把"响应被当拍接走"的分支从 `ST_HIT` 改成直接回 `ST_IDLE`，
  而 LRU 更新写在 `ST_HIT` 里 → 快路径永不更新 LRU。
- **修法**：在 `ST_IDLE` 受理分支里也写 `lru_mem[req_set] <= hit_way ? 1'b0 : 1'b1`。
  修完 `d_miss` **4,655 → 4,270（−8.3%）**。
- **以后**：**把某个状态"绕过"时，必须逐个检查该状态里的所有副作用**
  （LRU、计数器、握手标志、错误码记录），不能只看主线时序。
  这类回归不会让 CRC 变，测试也很可能全绿——只有查 `d_miss`/`lru` 这类质量指标才看得见。

---

## B. 证据与数字（最严重的一类）

### M02 · 把"自己算的数"写进"串口原始输出"块

- **表现**：5 份 measurement.md 的代码块标题是"串口输出"，但里面的
  `Iterations/Sec` 是我按浮点算的（72/70/64/56），固件真实打印是
  **整数截断**值（76/76/69/58）。4 份错。
- **根因**：固件 `core_portme.h` 里 `HAS_FLOAT 0`，`Total time (secs)` 取
  `floor(ticks/27e6)`，`Iterations/Sec = iterations / 那个整数`；我按
  `iterations/精确秒数` 算并四舍五入，方向就错了。
- **修法**：全部按归档 `score*_key_lines.txt` 改成真实打印值；串口行被打断的
  （P13/P14）明确标注"由已验证模型推导"。
- **以后**：**代码块只贴原文**。想写推导值就放正文并注明算法。
  另见 [`rules.md`](rules.md)。

### M09 · 引用"中间时序报告"当最终值（独立复核 C06/D08）

- **表现**：我把 27 MHz 写成 setup +15.404 / hold +0.025，50 MHz 写成 +0.862 / +0.087；
  而同一 PDS 目录的官方 `multiseed_summary.csv` 是 **+15.267/+0.030** 和 **+0.703/+0.242**。
  独立复核重跑得到的是后者。
- **根因**：`place_route/*_timing_summary_after_hold_fix.txt` 是**中间快照**；
  收尾的最后一道优化会用 setup 换 hold（所以 setup 降、hold 升）。我抄了中间那份。
- **以后**：**slack 只从 `multiseed_summary.csv` 取**；引用时把文件名写进文档。

### M10 · LUT 阶段标错（独立复核 C07）

- **表现**：文档写"13,574 LUT，取自 device_map"。
- **真相**：13,574 是 **synthesis** Mapping Summary；**device_map 是 13,444**；
  后布线 13,389。三个阶段三个数。
- **以后**：报 LUT **必须写阶段**，并且与分数换算用同一个数
  （13,444 → 0.1989；13,574 → 0.1970）。

### M11 · 复用同一个 PDS 目录跑两个频率 → 交付位流失去实现目录（C05）

- **表现**：`F7B135AE…` 是本机生成的 27 MHz 位流，但 `build/pango_native` 里
  只剩 50 MHz 的 `112E2AE4…`；独立复核无法验证"三项同源"。
- **根因**：为省事在同一目录里先后跑 27/50 MHz，第二次覆盖第一次；只归档了
  时序摘要和 CSV，没归档 `flow.log`/`report_timing/*.rtr`。
- **以后**：见 [`rules.md`](rules.md) §8"一个实现 = 一个证据目录"，**跑之前先建目录并想好归档清单**。

### M03 · 百分比标错对象

- **表现**："ticks −2.43%" —— 实际 ticks 降 **2.35%**，2.42% 是 CoreMark/MHz 的增幅。
- **以后**：百分比一律写成"**A 从 x 变成 y，降/升 z%**"。

### M18 · 用 Set-Content 生成证据文件 → UTF-16LE

- **表现**：`verify_rerun_768.txt` 是 UTF-16LE，普通文本工具读成乱码（复核 D10）。
- **以后**：写文件用 `write` 工具或 Python（显式 UTF-8），不用
  PowerShell `Set-Content`/`Out-File` 的默认编码。

### M15 · 声称"控制字符 0 处"，可那份文件自己就有 2 个 BEL

- **表现**：`P16/VERIFICATION.md` 写"全仓复扫控制字符数为 0"，而该行本身含 U+0007。
- **根因**：写入那句话本身又经过了会产生 BEL 的路径，且**我没有在写完后再扫一次**。
- **以后**：**任何"已检查/已清零"的声明，必须在写入之后重新扫描一次再声称**。

---

## C. 工具与流程

### M04 · 手写 CSV 导致列错位

- **表现**：`ab-log.csv` 追加 4 行时少写一个逗号 → 19 列，`coremark_per_mhz`
  落进 `total_lut` 列；另有一行备注里带逗号被额外切开。
- **以后**：**CSV 只用 `csv` 模块读写**，不手拼字符串；追加后校验每行列数。

### M05 · PowerShell 双引号拼 markdown → 控制字符

- **表现**：roadmap 里 `` `axi_ram` `` 变成 `<BEL>xi_ram`（`` `a `` 被当转义）。
- **以后**：**不要用 PowerShell 双引号/here-string 生成含反引号的文本**；
  用 `write` 工具或 Python 三引号。

### M06 · 层级探针引用不存在的实例

- **表现**：`soc.core.data_cache` 在 `cache_off` 配置下不存在 →
  `vopt-7063 Failed to find 'data_cache'`（仓库里预存，我加重了它）。
- **以后**：所有**依赖配置的层级探针**必须 `ifdef CACHE_ENABLE` 包起来。

### M07 · `ifdef` 恒假：vlog 按文件编译单元

- **表现**：加完 `ifdef` 后探针全 0——宏是 RTL 文件里的，**不会跨文件带到测试台**。
- **修法**：测试台自己 `` `include "soc_config.vh" ``。
- **以后**：测试台要跟 RTL 同配置时，**自己 include 同一份配置头**。

### M08 · A/B 基线选了"已含改动"的提交

- **表现**：用 `--baseline-rev HEAD` 隔离 `axi_ram.v`，得到 **+0.00%**——
  因为 HEAD 里已经包含改动后的文件。
- **以后**：基线必须是**改动前**的提交（如 `c153039` 而不是 HEAD）；跑出 0.00% 先怀疑基线。

### M13 · 忘了还原三开关

- **表现**：为跑分打开 `CACHE/PREDICT/PERF` 后没关，后续
  `run_pipeline_tests` 因固定源码表缺 `branch_predictor.v` 展开失败；
  一次 A/B 还因为配置不对跑出 IPC 0.116 的无效结果。
- **以后**：**每次跑完立刻 `set_switches.py off` 并 `status` 确认**；提交前再确认一次。
  开关状态也要写进跑分记录。

### M19 · 标签误导（已修）

- **表现**：`under-10s-rule=False` 容易被读成"不满足 10 s"，实际含义是
  **"这次运行违反了 ≥10 s 规则"**（复核 D09）。
- **修法**：`run_fetch_ab.py` 里键名 `under_10s` → `ten_s_violated`，
  报告标签 → `10s-rule-violated=True/False`，并在代码注释写明语义。
- **以后**：布尔标签必须写成**断言能读通**的句子（`rule-violated=True`），
  不要用"规则名=False"这种双重否定式。

### M17 · 临时脚本散落在仓库外根目录

- **表现**：工作区根目录堆了 `_fix*.py`、`_peek*.py`、`_msg*.txt`、
  `_set_switches.py`、`_tb_p15_keep.sv` 等一次性文件。
- **以后**：临时脚本写到系统临时目录，或写完立即删除；**不要在项目根目录留 `_` 前缀文件**。

---

## D. 文档与口径

### M14 · 两版内容混称"本版"、留重复条目

- **表现**：`intro` 第二节把 P16 和 P14 的改动都叫"本版"；效果表里有一行
  P14 遗留的重复条目。
- **以后**：改文档时**整节重读一遍**，确认"本版/上一版"指代一致；表格改完检查有无重复行。

### M16 · 把仿真跑分写成"交付跑分/三项交付"

- **表现**：违反仓库既有策略（`.githooks/pre-push` 明确拦"仿真跑分当成绩上传"）。
- **修法**：在 `bitstream/README.md` 与 `P16/measurement.md` 顶部加显著声明。
- **以后**：**写"成绩"之前先读一遍赛题 §4 与仓库的 SCORE 策略**；
  仿真数据一律标注"RTL 仿真，非板上实测，不得作为提交成绩"。

### M20 · 轮次编号残留

- **表现**：`ab-log.csv` 里留下 `P15-*` 标签，而 P15 目录从未存在（内容已归入 P14 附录）。
- **以后**：改编号时全仓 `grep` 旧编号，一次性改完。

---

## E. RTL 缺陷（独立复核发现，2026-10-18 修复）

> 这三条都是**代码里真实存在**的缺陷，不影响 CoreMark 的 ticks（因为 CoreMark 的
> 访问模式碰不到它们），但影响 RV32I 的精确异常语义与通用性。前两条是历史遗留，
> 第三条的症状被现有单测"恰好"掩盖。

### M21 · 数据 RAM 之外的 store 吞掉了 DECERR（R01，历史遗留）

- **表现**：对 `0x1000_4000…0x1FFF_FFFF`（数据 RAM 只有 16 KiB，这段是空洞）的 store
  被**提前回答 OKAY**，从站回 DECERR 时只在 `ST_WR_DRAIN` 里作废缓存行，**不产生
  store access fault** —— 违反 RV32I 精确异常要求。
- **根因**：`dcache_axi.v` 里
  `early_q <= (addr>=0x1000_0000) && (addr<CACHED_LIMIT)`，
  `CACHED_LIMIT` 是 **256 MB** 窗口上界，而不是数据 RAM 的 16 KiB 上界。
- **修法**：新增参数 `DATA_RAM_LIMIT = 32'h1000_4000`，`early_q` 只用它做上界。
  空洞里的 store 于是走 `ST_WR_RESP`，拿到真实 B 响应 → 能报 fault。
  CoreMark 的 store 全在 16 KiB 内，**性能无影响**。
- **以后**：**"提前应答/乐观完成"的地址范围，必须按从站真实可服务范围来定，
  不能按总线窗口来定。** 写一个新 parameter 明确写出物理上界。

### M22 · MMIO 的 byte/halfword 读固定发 ARSIZE=2（R02，历史遗留）

- **表现**：非缓存的单拍读（MMIO）无论 `req_size` 是什么都发 `ARSIZE=2`（32 位字），
  `axi_reg_slave` 看到"字宽访问 + 非对齐偏移"回 SLVERR → 变成 load access fault。
- **根因**：`assign m_arsize = 3'd2;  // always full 32-bit words`。
  缓存行填充确实永远是整字，但 MMIO 单拍读不是。
- **修法**：`assign m_arsize = cached_q ? 3'd2 : i_req_size_r;`，并在受理拍锁存
  `i_req_size_r <= req_size`（原来只在写分支锁存，读路径拿到的是**上一次的值**）。
- **以后**：**一个信号同时服务两条语义不同的路径时，先问"两条路径的要求一样吗"。**
  "永远是整字"对填充成立、对 MMIO 不成立。

### M23 · 2-bit 计数器在 11 上再 taken 会被打回 10（R04，历史遗留）

- **表现**：一直 taken 的分支，计数器稳定在 10 而不是 11；随后**一次** not-taken 就
  翻到 01（预测不跳），下一次 taken 必然多一次预测失败。实测 **mispred 153,690 → 137,945（−10.2%）**。
- **根因**：`count_q <= (hit && count!=11) ? count+1 : 2'b10;` —— 已经饱和在 11 时，
  条件为假，落到 `2'b10`，**等于每次 taken 都把 11 降回 10**。
- **为什么单测没抓到**：P6 用例训了 **4 次** taken，序列是 10→11→10→11，**偶数次**
  正好停在 11，后续检查全过。**奇数次**才暴露。已补 P10 用例（训 3 次）做判别。
- **修法**：`(!hit) ? 2'b10 : (count==11) ? 2'b11 : count+1`。
- **以后**：**验证饱和/溢出行为时，奇偶两种次数都要试**；写完"看似通过"的用例，
  用**故意改回旧代码**的办法确认它会失败（本次就是这么做才敢说测试有效）。

---

## F. 测试基础设施缺陷（最危险的一类：它让上面所有缺陷都"通过"）

### M24 · 五个 runner 的 PASS 判据永远不成立（历史遗留）

- **表现**：`run_predictor/dcache/icache/perf/gpio_trace_tests.py` 都用
  `ln.strip().startswith('FAIL')` 找失败行，但日志每行都被加了 `# ` 前缀
  （`# FAIL predict ...`），**所以永远匹配不到** → 测试台打印了 FAIL，runner 仍报 PASS。
- **后果**：修好判据后**立刻暴露两个一直存在的失败**：
  `tb_dcache_axi` 在 D3 超时、`tb_perf_regs` 的 `D_R_BEAT 期望 16 实得 17`。
  也就是说此前所有"dcache/perf PASS"的结论都**不可信**。
- **修法**：新增 `sim/tb_verdict.py`（去前缀 + 找 FAIL/Fatal + **必须**出现显式成功标记），
  五个 runner 全部改用它。
- **验证**：把预测器旧逻辑临时放回，runner 现在正确报
  `FAIL branch_predictor rc=0 fails=2 first=FAIL predict pc=00000020 taken=0 want=1`；
  换回修复版报 PASS。
- **以后**：**判据必须是"看到了成功标记"（白名单），不是"没看到失败字样"（黑名单）。**
  凡"全绿"结论，先确认判据本身能变红。

### M25 · 单元测试台不等 req_ready 就撤 req_valid（历史遗留）

- **表现**：`tb_dcache_axi` 的 `rd()`/`wr()` 驱动 `req_valid` 一拍后无条件撤掉；
  若 DUT 当时不在 `ST_IDLE`（`req_ready=0`），请求被静默丢弃 → 永远等 `w_ready`。
- **修法**：加了 `while(!req_ready) @(negedge clk);` 再撤。**但 D3 超时仍未解决**
  （探针显示 DUT 停在 `ST_WR_HOLD`、内层引擎停在 `WR_HOLD`、`bvalid/bready` 握手未完成），
  这条**仍 OPEN**，需要单独排查。
- **以后**：**驱动 DUT 前必须先看 `ready`**；"发一拍就走"在带反压的接口上一定会出问题。

### M26 · 预存失败（已定位、未修，OPEN）

| 现象 | 归属 | 状态 |
|---|---|---|
| `tb_dcache_axi` D3（写命中）超时 | 与本轮三处修复无关（用 `b1541f7` 的 RTL 同样超时） | **OPEN** |
| `tb_perf_regs` `P2 D_R_BEAT` 期望 16 实得 17 | TB 只例化 `perf_regs`，与 dcache/预测器无关 | **OPEN** |
