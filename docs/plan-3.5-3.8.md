# 3.5 / 3.8 路线计划（先计划，后执行）

日期：2026-10-20（**22:54 更新：4KB 版已布通并上板实测**）
分支：`feat/score-3.5`（`main` 保持 P21 2.8833 交付，不动）
当前结论：3.5 的**仿真版本存在**（双发射 + 8KB I-Cache，20 迭代 A/B `3.539`），
PDS 2022.2-SP6.1 上 8KB 版仍未布通；**4KB 版（原记 3.423）已在 2026-10-20 13:54
布通并生成位流，2026-10-20 22:54 上板实测 `CoreMark/MHz = 3.4194`、11.091 s、
五项 CRC 全对**（证据：`evidence/records/optimization/4kb_3.423/`）。
8KB 的 3.539 仍无位流；交付位流在用户决定前仍是 P21 的 2.8833。

> **2026-10-20 22:54 板上实测（4KB + 最小 lane1）**
> ``` 
> Total ticks 299,467,030 / Iterations 1024 / 11.091 s / 3.4194 / Correct operation validated
> seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x9ce8
> 位流 SHA256 8D12C9D114C0DBE4455E0A50C0F944B7D8506273DB28ADAEBC3755205FA6A643
> 实现：21,949 LUT / 14,104 FF，All Constraints Met（setup +14.750，hold +0.015 / +0.002，失败端点 0）
> ```
> hold 只有 +0.015 / +0.002 ns，属"刚好过"；正式交付前要么固定这份位流不再重跑，
> 要么重跑时先确认 hold 仍为正。另：本目录此前那些 0 字节串口文件是抓取窗口错位
> （`docs/lessons/mistakes-log.md` §7.6），**不是"跑不起来"**。

## 0. 目标与验收

| 目标 | 验收（缺一不可） |
|---|---|
| 3.5 | 同一份位流：板上 1024 迭代、实测 ≥10 s、CRC 五项正确、PDS `All Constraints Met`、LUT/FF 报该位流所在阶段 |
| 3.8 | 在 3.5 的同一套证据链上再提升；不允许用仿真/估算替代板上值 |
| 高阶 AI | 只预留地址/AXI/时钟域/构建开关；本计划**不实现 AI RTL**，除非 3.5 已交付 |

铁律：一个实现 = 一个 evidence 目录；板上只认实测；hold 只认 `multiseed_summary.csv`；
LUT 必须注明阶段；`Iterations/Sec` 永远不能反推成绩。

## 1. 已知事实（不要再重复验证）

| 版本 | LUT / FF | 20 iter ticks | CM/MHz | PDS 结果 |
|---|---:|---:|---:|---|
| 8KB + 完整 lane1 | 25,266 / 16,887 | 5,651,999 | 3.539 | 约 4.3k 未布通平台 |
| 8KB + 最小 lane1 | 25,064 / 16,858 | 5,668,674 | 3.528 | 约 4.3k |
| 4KB + 最小 lane1 | 22,097 / 14,234 | 5,842,953 | 3.423 | **布通**（`code_ic4k`，21,949/14,104，hold +0.015/+0.002）；**板上 3.4194** |
| P21 单发射 | 16,782 / 12,509 | — | 2.8833（板上） | 0，成功 |

已排除的假路（不要再走）：

- seed 7 / 11 / 41、`-plc_decongestion 1/2`、路由后修 hold、4 seed 并行：8KB 都在 4.3k；
- 4KB 默认：3.3k；面积降到 22k 仍不够 —— **但 2026-10-20 13:54 的 `code_ic4k`
  这一跑布通了（`p35_ic4k_decon2.log`）**，说明"4KB 布不通"依赖种子/去拥塞选项，
  不是结构性结论；能否稳定复现要先看 `multiseed_summary.csv` 的 `Convergence` 与 hold；
- RVC（`rv32imc`）：静态 55.4% 是 C 指令、代码 9.9KB，但 C 主要是 1:1 替换，动态 N
  不按比例下降；单发射上限仍是 `1e6/289,125 = 3.459`，到不了 3.5；
- SP6.4：机器上只有 SP6.1，`E:\donwload\PDS_2022.2-SP6.4` 不存在。

## 2. 决策门（Gate）

- **G1**：25k/3.539 能否布通？
  - 能 → 直接进 Phase 2（板上 3.5）。
  - 不能 → 进 1C 或停；**不允许**用仿真值冒充交付。
- **G2**：如果 1A/1B/1C 都失败，3.5 在当前板/工具下判定为**不可达**；交付 2.8833，
  并把双发射 3.539 作为“布线受限”实验归档。
- **G3**：3.8 只有在 3.5 板上证据齐全后才启动；否则不做。

## 3. 阶段

### Phase 0 — 冻结基线（半天内，低风险）

1. 确认 `main` 仍指向 P21 2.8833，tag `score-2.8833-832` 可回退；
2. 把当前 `feat/score-3.5` 的 RTL/回归/证据整理成一次提交（不合并 main）；
3. 保留 `build/code_s41`（8KB 完整 lane1）作为 3.539 的可复现源；原工作树当前是 4KB，
   需要时用 `SETS=128` + 完整 `id/ex` 恢复；
4. 清理 `build/` 下误放的 `flow.log`/`run.log`/`impl.tcl`/`multiseed_summary.csv`
   （已清过一次，PDS 再次误写要继续清）。

### Phase 1 — 解开布线（当前主战场）

#### 1A. PDS 工程模式 region/floorplan（首选，不改 RTL）

- 目的：把 8KB I-Cache（LUTRAM 热点）和 4R2W 寄存器堆分散，破解 4.3k 平台；
- 只读检查：加载 `build.pds` 后 `help`，确认是否有 `create_region`/`place_region`/
  `assign_region` 等命令；没有就放弃 1A，不硬试；
- 有命令：给 `instruction_cache`、`u_regs` 各建 region，先只动这两个，跑 8KB 默认种子；
- 验收：`Unrouted nets 0` + `All Constraints Met`；否则回到 G1。

**1A 结果（2026-10-20，已执行）**：

- `pds_shell` 工程模式没有 `create_region`/`place_region`；
- `create_partition_def` 是**部分重配置（PR）**，不是普通 floorplan；
- PCE 指南里的 `region -create`/`constraint -def_inst_region` 是 **PCE GUI 的 Tcl Console** 命令；
  把它们写进 `pango_native.pcf`，PDS `add_constraint` 直接报
  `ConstraintEditor-0046: invalid command name "region"/"constraint"`；
- 因此 **1A 的 CLI/PCF 脚本化路径不可用**；只剩 **PCE GUI 手工 floorplan**（`pds.exe` → Tools →
  Physical Constraint Editor → Region Mode → Assign to Region → 导出 PCF），或 1B/1C。

**1A-2（PCE GUI floorplan，2026-10-20 已推进到 PCE 打开）**：

- 关键：PCE 必须打开**一次完整 dev_map 的新鲜 ADF**；被杀的 P&R 残留 ADF 会让 PCE 卡在 0×0；
- 新鲜 ADF：`build/code_s41/build/res_8k/device_map/pangoriscv_top_map.adf`（`RESOURCE_CHECK_DONE`，25,266 LUT）；
- 绕过 “Open Map DB” 文件对话框：`pce.exe "<adf>"`；PCE 主窗口标题正确，已打开（PID 10344）；
- PCE 窗口用 `MoveWindow(0,0,1430,950)` 移到屏幕内；工具栏有 **TCL** 按钮；
- 建 region：PCE Tcl Console（`region -create` / `constraint -def_inst_region`）或 Region Mode 手画；
  I-Cache `soc/core/cpu/instruction_cache`、regfile `soc/core/cpu/u_regs` 各一块，分开不重叠；
- 保存 map DB（File → Save / Export PCF），把路径给我；我跑 `pnr` + `generate_bitstream`，验 3.539；
- 这一步需要 GUI 交互；我负责开 PCE、跑 P&R、验报告和上板。

**PCF 原生 region（2026-10-20，重大进展）**：

- `def_region <name> <xmin> <xmax> <ymin> <ymax>` 是 PCF 指令，PDS `add_constraint` **接受**；
- `def_inst_region <inst> <region>` 语法也被接受，但 `<inst>` 必须是 PCE Design Browser 的完整路径；
- 已试并失败：`soc/core/instruction_cache`、`soc/core/cpu/u_regs`、`pangoriscv_top/soc/...`、
  叶子名 `instruction_cache`/`u_regs`、前导 `/pangoriscv_top/...`、反斜杠 `soc\core\...`
  （反斜杠被 Tcl 当转义吃掉，变成 `soccore...`）；
- **只差这一个实例名字符串**；PCE 已用新鲜 ADF 打开在 0,0，Design Browser 里就是正确写法。
  拿到后改 PCF 两行，重跑 PDS 即可验证 floorplan 是否让 25k 脱离 4.3k 平台。

#### 1B. 新 PDS（SP6.4 或更新）

- 需要你提供安装包/可用路径；当前机器没有；
- 有则用同一份 8KB RTL + 同一镜像重跑，不动 RTL；
- 只有新布线器确实把 25k 布通，才继续；否则回到 G1。

#### 1C. 面积再降（最后手段，且大概率到不了 3.5）

- 2KB I-Cache（约 20.6k LUT）或 3R2W 寄存器堆（约 −0.7~1k）；
- 预期成绩：2KB 约 3.30；3R2W 约 3.42；**都低于 3.5**；
- 只有在“必须上板、接受低于 3.5”时才做；否则不做，避免浪费。

### Phase 2 — 3.5 板上验证（G1 通过后）

1. 用 **1024 迭代**镜像（`score1024`）跑完整 PDS；`program.hex`/`data.hex` 必须在
   PDS 进程 cwd（从 `build/pango_native` 启动，第一铁律）；
2. 检查 `Loading memory data from file` 两条、`All Constraints Met`、hold 从
   `multiseed_summary.csv` 取；
3. 生成 `.sbit`，SRAM 下载（`run_flash.ps1` + `01_program_sram.tcl`），串口 COM34
   115200 8N1 抓 ≥10 s；
4. 证据目录：位流 SHA、PDS 报告、UART 原文、CRC 五项、迭代数、板上 CM/MHz；
5. 只有五项 CRC 全对且 ≥10 s 才算 3.5；否则回 Phase 1。

### Phase 3 — 3.8（G3 通过后）

- 当前 3.539 到 3.8 需约 +7.4%（IPC 1.023→1.099，f 约 26%→35% 或等价）；
- 候选：D4（load 进 slot1）、RAS/返回地址栈、更好的分支预测、I-Cache 预取；
- 每个候选先做 20 迭代 A/B（CRC 必须同），再评估面积；面积一超 25k 就会重演布线问题，
  所以 3.8 很可能需要**更大器件**；如果 G1 已经靠 floorplan 勉强通过，3.8 先不做。

### Phase 4 — AI 高阶任务（仅在 3.5 交付后）

- 只做地址/AXI/时钟域/构建开关预留；不写 AI RTL；
- 未来 YOLOv3-tiny 320×320 INT8、OV5640+HDMI+DDR3、16×16 MAC、135 MHz AI 域，
  单独 `ai` 位流；当前不占逻辑。

## 4. 错误经验（本次必须记住）

1. **PDS 的 cwd**：`pds_shell` 必须从 `build/pango_native` 启动，否则 `$readmemh` 找不到
   `program.hex`/`data.hex`；`PANGO_NATIVE_REPO` 是 `firmware/code`，不是仓库根。
2. **`id_ex.in_ready` 是 output**：不能当 input 驱动，否则多驱动；用模块输出的 slot ready。
3. **`retire_ctrl.retire_fire` 是 output**：核心又 `assign` 同一网会多驱动；核心自己的
   `retire_fire` 单独用，`retire_ctrl` 接独立观测网，且 `ex_done` 喂“真退休或真 trap”。
4. **`regs.v` 函数读端口**：ModelSim `always @(*)` 对函数内动态索引 `rfile` 不敏感；
   改成四个显式 `always @(*)`。
5. **IF/ID 的 `pop_one`/`take1`**：`load_into1 = take1 && (free_after == 1)`，否则覆盖。
6. **Verilog 的 `?`**：`32'd8?chain2_next` 会被当成 based number；加空格/括号。
7. **`tempfile.mkdtemp` 在 Windows 沙箱**：0700 目录会让下一个进程 PermissionError；
   用显式 `mkdir` + uuid。
8. **RVC/`-O3` 不是 3.5 的解**：先量动态 N，不要用“代码小了”推成绩；单发射上限 3.459。
9. **种子/去拥塞/多 seed 不是面积问题的解**：25k/22k 的 4.3k/3.3k 平台是结构性的；
   先解决面积/floorplan，再谈种子。
10. **D-Cache 单元测试 D3 超时**：posted store buffer 改了 `b_valid` 时序，TB 还没跟上；
    在最终交付前必须修或明确记录。
11. **旧 `impl.tcl`/`flow.log` 会误导**：PDS 误写到 `firmware/code/` 的产物要及时清；
    不要拿旧 seed 命令当当前流。
12. **4KB I-Cache 几何迁移**：tag 21 位、set 6 位、`rd_index_q` 10 位、bank 索引 9 位；
    漏一位就会静默错。
13. **PCE Tcl ≠ PCF 指令**：`region -create`/`constraint -def_inst_region` 只在 PCE GUI 的
    Tcl Console 里有效；写进 `.pcf` 会被 PDS `add_constraint` 拒绝（ConstraintEditor-0046）。
    floorplan 只能走 PCE GUI 导出 PCF，或换 PDS；不要再用文本 PCF 试 PCE 命令。
14. **PCE 的 map DB 必须是完整 dev_map 的 ADF**：被杀的 P&R 残留 ADF 会让 `pce.exe` 卡在
    0×0；先跑 `resource_check.tcl` 到 `RESOURCE_CHECK_DONE`，再用 `pce.exe "<adf>"`。
15. **不要用文件对话框开 map DB**：PCE 的 “Open Map DB” 对话框在 720×480 下文件名/Open
    不可见，`Ctrl+L`/`Alt+N` 都不可靠；直接 `pce.exe "<adf>"` 绕过。
16. **PCE 窗口可能开在屏幕外/被浏览器盖住**：用 `EnumWindows` 拿真实句柄 +
    `MoveWindow` 移到屏幕内；前台截图前先最小化浏览器，不要盲点坐标。
17. **PCF `def_inst_region` 的实例名必须取 PCE Design Browser 的原始路径**：网表/elaboration
    的 `soc/core/...`、加 `pangoriscv_top/`、前导 `/`、叶子名都不行；反斜杠会被 Tcl 当转义
    吃掉（`soc\core\...` → `soccore...`）。不要再猜路径，直接看 PCE Design Browser。
18. **PCE Qt 的 Design Browser 树项不暴露给 UIA/MSAA**：UIA 只看到 Design Browser 工具栏/
    复选框（100 个元素，树项为空）；MSAA 根有 14 个子项，但 `accName`/`accChild` 全部报错；
    `pip install pywinauto` 被本机 SSL 阻断。`def_inst_region` 的实例名只能人眼看 PCE GUI，
    当前会话无法程序化获取；不要再在 UIA/MSAA/ADF 字符串上耗时间。

## 5. 证据与回退

- 安全交付：`main` + P21 `bitstream/pangoriscv_i768.sbit`（2.8833，板上已验证）；
- 实验：`feat/score-3.5`（双发射、4KB/8KB、3.539/3.423 仿真）；
- 任何新成绩必须有独立 evidence 目录；没有位流就不写板上成绩。

## 6. 现在要你定的第一件事

1A 的只读检查结果出来后：
- 有 region 命令 → 我按 1A 做，先只给 I-Cache/regfile 两个 region，跑一次 8KB；
- 没有 region 命令 → 1A 放弃，等你提供 SP6.4（1B）；否则走 G2，保 2.8833。

**在得到你的确认或 1A 结果之前，不启动新的综合/布线。**
