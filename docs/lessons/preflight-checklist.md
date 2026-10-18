# 动手清单（照着做，别凭记忆）

## 一、开工前

- [ ] `git status` 干净；`git log --oneline -3` 看清当前基线
- [ ] `python tools/set_switches.py status` —— 记下当前开关状态
- [ ] 读 `docs/verification/issue-register-2026-10-18.md`，确认要动的地方有没有未修的编号项
- [ ] 如果这次要动 RTL：先确认七个探针还在
      （`SCORE_WINDOW` / `EX_SPLIT` / `DCACHE_PATH` / `ICACHE_PATH` /
      `ADDR_REGION` / `MISPRED_MIX` / `LSU_REQ_SPLIT`）

## 二、动 RTL 之前

- [ ] **先量**：跑 20 迭代 A/B，把当前 `ticks` / `if_wait` / `i_miss` / `d_miss` /
      `request_store` 记下来
- [ ] 想清楚这个改动对**读和写两条路**分别意味着什么（M01 的教训）
- [ ] 想清楚它会"绕过"哪些状态，那些状态里有哪些副作用
      （LRU / 计数器 / 握手标志 / 错误码 —— M12 的教训）
- [ ] 确认改动只碰一个变量

## 三、改完立刻验证（按顺序，别跳）

- [ ] `run_unit_tests.py --case all` → 5/5
- [ ] `run_dcache_tests.py` / `run_icache_tests.py` → PASS
- [ ] `run_isa_e2e.py --cases all` → 15/15（需要开关 ON）
- [ ] `run_ram_tests.py --seeds 20` → 40/40
- [ ] `run_halt_reset_tests.py` → 5/5
- [ ] `run_ifu_engine_tests.py --seeds 20` → 20/20
- [ ] 20 迭代 A/B：**基线取改动前的提交**（不是 HEAD，M08）；**五项 CRC 必须逐项相同**
- [ ] 检查 `d_miss` / `i_miss` 有没有异常变化（M12 就是靠这个发现的）

## 四、出台交付数据

- [ ] 打开三开关，`set_switches.py status` 确认
- [ ] 按 `N ≥ ceil(10.5 × 1e6 × 27 / 每迭代ticks)` 重算迭代数并留余量
- [ ] 建**独立** PDS 目录（不要在旧目录上跑，M11）
- [ ] PDS 27 MHz（**先跑 50 MHz 再跑 27 MHz**，这样 27 MHz 的产物留在目录里）
- [ ] 归档整套：sbit + SHA + multiseed + report_timing.rtr + device_map + logs + manifest
- [ ] 从 `multiseed_summary.csv` 取 slack 和 LUT，**标明阶段**（`evidence-rules.md` §1、§2）
- [ ] 交付跑分：768 迭代、确认 `Correct operation validated`、五项 CRC 逐项记录

## 五、写文档

- [ ] 串口输出块**只贴原文**，不填自己算的数（M02）
- [ ] 百分比写清对象："A 从 x 变 y，±z%"（M03）
- [ ] 仿真数据处加"RTL 仿真、非板上实测、不得作为成绩"声明（M16）
- [ ] CRC 说法改成"三项与官方表一致 + 两项与确定性链一致"（`evidence-rules.md` §5）
- [ ] "本版/上一版"指代检查一遍，表格查重复行（M14）

## 六、提交前

- [ ] `python tools/set_switches.py off`，再 `status` 确认三关（M13）
- [ ] `git status` 只有预期文件；**RTL/TB 净改动逐个 `git diff` 看过**
- [ ] 控制字符扫描：doc/evidence 下不应有 U+0007 等（M05、M15）
- [ ] CSV 列数校验：每行都必须等于表头列数（M04）
- [ ] 位流 SHA 与文档里写的一致
- [ ] 全仓 grep 旧值残留（`1.35`、`F8254F66`、`i512`、`2.6109` 用作当前值等）
- [ ] 临时文件：项目根目录不应有 `_*.py` / `_*.txt` / `_*.sv`（M17）
- [ ] 证据文件编码是 UTF-8（不是 UTF-16LE，M18）

## 七、绝对不做的事

- ❌ 把仿真跑分当成绩报/推送
- ❌ 在"原始输出"块里填自己算的数
- ❌ 用被截断的 `Iterations/Sec` 反推分数
- ❌ 用 HEAD 当 A/B 基线
- ❌ 同一个 PDS 目录跑两次实现
- ❌ 解释不清的行为差异硬上线
- ❌ 引中间时序快照的 slack
- ❌ 报 LUT 不写阶段
