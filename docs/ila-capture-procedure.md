# ILA 波形抓取：流程与已确认的阻塞点（2026-10-21）

> 赛题「技术实现与文档 / 分析报告」明确要求：**用 ILA 抓取 CPU 执行 CoreMark 关键算法时的波形**，
> 分析流水线效率（停顿、冲刷、退休节奏）。这份文档把"怎么抓"钉死，并记录本轮**没有抓成**的原因。

---

## 1. 现状：探针已就位，抓取未完成

- 观测网在 RTL 里：`rtl/soc/pangoriscv_top.v` 的 18 个 `obs_*` 网（`syn_keep` / `syn_preserve` 保住），
  网表里全部存活（见 `platform/pango_native/README.md` §"On-chip logic analyzer probe list"）。
- 探针清单与**建议触发条件**也在那份 README 里（含 CoreMark list/matrix 内核的 PC 区间）。
- **没有抓过一次**。平台 README 原文："Timing a capture so the window covers a meaningful slice
  of a >= 10 s run is still an open board activity; no capture has been taken."

## 2. 本轮确认的阻塞点（关键事实）

| 事实 | 证据 |
|---|---|
| **无头 `cdt_dbg -file <tcl>` 会在打开 cable 时挂死** | 本轮实测：`cdt_dbg.exe -file dbg_help.tcl` 打印 licence 与 `M_PROCESS_FINISH_STARTED` 后**永久挂住**（2 分钟无输出、进程不退），只能强杀 |
| 外部同类项目记录同一现象 | pango-mcp 的工具说明写明 "无头 `cdt_dbg` 开不了 cable(`open_cable` 死锁)"，它的做法是**驱动 GUI Fabric Debugger 自带的 Tcl Console**（cable 已由 GUI 打开） |
| 调试器命令族是 `dbg_*` | 同上：`dbg_read_device_id`、`dbg_fla_*`（抓波）、`dbg_program`、"import fic" 等 |

**结论**：这个 ILA 抓取**必须在 GUI 里做**——要么人点，要么用 UIAutomation 往 GUI 的 Tcl Console 里打字
（pango-mcp 就是后者）。纯命令行批处理这条路在本机不通。

## 3. 可执行的抓取流程（GUI 版，约 10~15 分钟）

### 3.1 出"带调试核"的位流
1. PDS 打开 `firmware/code/build/pango_native/build.pds`（或 `platform/pango_native/build.pds`）；
2. 打开 **Tools → Fabric Debugger**（或工程里 Debug 面板），把 §1 的探针加进去：
   - 采样时钟：`clk`（27 MHz，单时钟域）；
   - 探针：`obs_retire_fire / obs_retire_pc / obs_retire_inst / obs_rd_valid / obs_rd / obs_wdata /
     obs_trap_fire / obs_trap_cause / obs_protocol_fault / obs_uart_tx / obs_retire_count`；
   - 采样深度：8192（BRAM 够；不够就 4096，只抓窗口）。
3. 重新 `Generate Bitstream`，产物会带一个**调试配置（FIC）**文件；
   **注意**：这份位流与交付位流（`bitstream/pangoriscv_i1024_area.sbit`）不同源，**不能用来报分**，
   只用于抓波形，证据里必须写清。

### 3.2 触发条件（用 `obs_retire_count` 做窗口）
CoreMark 10.7 s ≈ 2.89 亿周期，而 ILA 深度只有几千点，所以**必须靠触发条件挑窗口**：

| 目标 | 触发写法 |
|---|---|
| 抓 list 内核（`0x1044`–`0x127c`） | 限定 `obs_retire_pc` 落在该区间，再等 `obs_retire_count` 到达某个阈值 |
| 抓矩阵内核（`0x17e8`–`0x18a8`） | 同上，换区间 |
| 抓"跑完打印"那一段 | 触发 `obs_uart_tx` 下降沿（第一个 start bit），窗口向前后各取一半 |
| 抓异常 | 触发 `obs_protocol_fault` 或 `obs_trap_fire` |

> 单点触发 + 深度 8192 在 27 MHz 下只覆盖 **0.3 ms**，所以**触发条件必须精确到"某个内核的某条 PC"**，
> 不能"跑起来就抓"。这也是这份文档存在的意义。

### 3.3 抓取与导出
1. 烧这份调试位流（SRAM，`cfg_program`），复位释放，等 CoreMark 跑到触发点；
2. Fabric Debugger 里 **Arm → 等待触发 → 停止**；
3. 导出波形：优先存工程原生波形文件，再**截图**（带探针名与时间轴）放入证据；
4. 分析文档里写：窗口起止周期、该窗口内的退休数、控制流数、访存停顿、每拍退休数（IPC），
   并与 `docs/architecture/module-area-plan.md` 里的探针口径对齐。

## 4. 命令骨架（GUI Tcl Console 里用；**需先在 Console 里 `help` 确认命令名**）

```tcl
# 1) 连接与器件（cable 已由 GUI 打开）
dbg_connect
dbg_read_device_id
# 2) 载入调试配置
#    （FIC 由 PDS 生成；文件名以实际为准）
# import_fic <path>.fic
# 3) 设触发与深度，然后 arm
# dbg_fla_set_trigger ...
# dbg_fla_arm
# dbg_fla_wait / dbg_fla_stop
# 4) 读回波形并导出
# dbg_fla_read ...
# dbg_fla_export <path>
```

> **本机未验证**：上面带 `#` 的行只是流程骨架，命令名/参数必须在 GUI 的 Tcl Console 里
> 用 `help` / `help dbg_*` 现场确认后替换。**不要把骨架当已跑通的脚本引用。**

## 5. 证据清单（抓成之后要归档的文件）

| 文件 | 内容 |
|---|---|
| `evidence/records/ila/<date>/waveform_<kernel>.<ext>` | 导出的波形（原生格式） |
| `.../waveform_<kernel>.png` | 波形截图（含探针名、时间轴、触发标记） |
| `.../capture.md` | 触发条件、深度、采样时钟、窗口起止周期、该窗口的退休/停顿统计与解读 |
| `.../bitstream` | 用于抓波的**调试位流** SHA256（明确标注"非交付位流"） |

## 6. 本轮结论（如实记录）

- 探针、触发方案、流程已钉死（本文 §1/§3）；
- **波形尚未抓取**：无头 `cdt_dbg` 挂死（本轮实测），而 GUI 自动化需要交互桌面 + Transcript 回读，
  本轮不具备条件；
- 下一步要么**人在板子前按 §3.3 点 3 分钟**，要么把 pango-mcp 那套 GUI Tcl Console 驱动接进来。
