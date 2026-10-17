# pangoriscv 优化交接报告（2026-10-17 收尾）

> **已被 `handoff-2026-10-18-ifu-done.md` 取代（本文保留作历史记录）。**
> 本文"四、下一步：IFU 取指吞吐"已经在 2026-10-18 完成并验证：
> 两笔未完成请求 + I-Cache 背靠背命中，周期 −12.97%、`if_wait` −77.3%、
> 27 MHz 下 All Constraints Met。新的交付数字见新交接文档与
> `evidence/records/optimization/P7/measurement.md`。

> 用途：新会话直接从这里接手。所有结论都有实测数据和提交号支撑，不依赖对话历史。

---

## 一、当前交付状态（一句话）

**store 路径优化把 CoreMark 周期降了 8.98%（CoreMark/MHz ≈ 1.3054 → 1.43），
时钟频率验证到 50 MHz 收敛；IFU 取指通路的改造根因已定位但未动手。**
仓库工作区干净，全部回归绿灯。

| 评分项 | 交付值 | 说明 |
|---|---|---|
| ① CoreMark/MHz | 1.3054 → **约 1.43** | 由 20 迭代 A/B 折算；400 迭代整机实测待跑 |
| ② 时钟频率 | 27 MHz 交付约束（WNS +17.920 ns）；**50 MHz 收敛实验通过**（WNS +2.372 ns，0/66,247 失败） | 板载晶振固定 27 MHz，未上板跑过更高频率 |
| ③ 资源 | **12,572 LUT**（未变） | store 改动只 +3 触发器；BTB 保持 32 项 |

---

## 二、已完成：三项有数据的优化

### 1. 周期分诊（P1）— 一切优化的依据

| 来源 | 占周期 |
|---|---|
| 访存发出后等待 | **36.5%** |
| 取指饥饿 | 18.1% |
| 访存发出前等待 | 9.0% |
| 分支预测失败 | 1.8% |
| 除法 | 0.04% |

> 记录：`evidence/records/optimization/P1/measurement.md`
> 结论：**访存是主矛盾**，不是 Cache 容量，也不是分支预测。

### 2. store 路径优化（P2'）— 采纳，最大收益

- 先测：每次写内存平均 9.16 拍，其中 **6.16 拍在等 AXI 的 B 响应**，占全部周期 15.3%
- 做法：只对片上数据 RAM 窗口（`0x1000_0000~0x1FFF_FFFF`）的写**提前释放响应**，
  总线确认在后台排空；窗口外的写仍同步等 B，保住 store 故障精确性
- 结果：**ticks 15,316,450 → 13,940,928（−8.98%）**，等 B 从 1,775,055 → 3,808 拍
- 验证：D-Cache 单元 PASS、ISA **15/15**、5 项 CRC 与基线逐项一致
- 提交 `99e8bdb`；记录 `evidence/records/optimization/P2-store/`

### 3. 时钟频率收敛实验（P5）— 完成

- 50 MHz 过约束（20 ns）跑完整流程：`All Constraints Met`，Setup WNS **+2.372 ns**，0 失败
- 位流 3,791,112 B，SHA256 `7321AB61…45A3E9`
- **口径**：这是约束收敛结果，不是板上实测最高频率；slack 推算的 56.7 MHz 只能写"推算"
- 提交 `7661e3e`；记录 `evidence/records/optimization/P5/`

---

## 三、已否决：两个方向别再做

| 方向 | 实测 | 为什么否决 |
|---|---|---|
| D-Cache 扩容 | 2→4→8 KB 只快 0.39%/0.53% | 缺失是强制性/流式，不是冲突；面积 ×4 换 0.5% |
| BTB 扩容 | 64/128 项快 1.68%/1.84%，但 LUT +15%/+32% | 指标③掉 12%/23%，三项并列评分下净亏 |

记录：`evidence/records/optimization/P2/`、`.../P4/`

---

## 四、下一步：IFU 取指吞吐（唯一剩下的优化）

### 根因（已定位，不用再分析）

`ifu_axi.v` 用"**只有一笔未完成请求**"的假设给响应配 PC：

```verilog
reg [31:0] req_pc_q, req_pred_q;      // 单份
q_pc[tail_q] <= req_pc_q;             // 响应时用唯一的 PC 配对
```

而 I-Cache `icache_axi.v` 也要 2 拍才受理一次（`req_ready = state==IC_IDLE`），
IFU 也是 2 拍才发一次（`eng_req_valid` 仅在 `S_IDLE`）。两者锁步 → **0.5 IPC 上限**。

一旦让两边背靠背，就有 2 笔请求在飞，`req_pc_q` 被覆盖 → 响应配错 PC →
`head_lost`（`ifu_axi.v:95`）清空重取 → 死循环。这就是上次"只退休 17 条"的原因。

### 改法（4 步，只动 `ifu_axi.v` 的请求登记 + 已验证的 I-Cache 背靠背）

1. **登记改 2 深**：`pcf0_q/pcf1_q`、`pdf0_q/pdf1_q` + `ocnt_q`（0..2）；
2. **入队**：`ocnt_q==0` 写 slot0，否则写 slot1，`ocnt_q+1`；
3. **出队**：响应配对 `pcf0_q`，并 `pcf0_q<=pcf1_q` 前移、`ocnt_q-1`；
   **同拍既收又发**时：配对旧 slot0 → 前移 → 新请求进 slot1（`ocnt_q` 不变）；
4. **复位与 `redirect_valid`** 清 `ocnt_q`（配合已有 `stale_q` 抑制迟到响应）。

I-Cache 侧的背靠背改动已单独验证过安全（单元测试 PASS、整机 ticks 与基线一致）：
`req_ready = rst_n && (state==IC_IDLE || rsp_leaving)`，并把 `IC_IDLE, IC_RESP`
合并到同一个受理分支，`IC_RESP` 下无新请求时走 `else if` 回 `IC_IDLE`。

### 入口门槛（缺一不可）

```powershell
python sim\run_unit_tests.py --case ifu_axi          # 必须先绿
python sim\run_icache_tests.py --modelsim "<ModelSim>"
python tools\run_isa_e2e.py --cases all --toolchain-bin "<xpack>\bin" `
  --prefix riscv-none-elf- "--extra-flag=-march=rv32im_zicsr" --modelsim "<ModelSim>"
# 再跑 20 迭代整机：ticks 应低于 13,940,928，5 项 CRC 与基线一致
```

---

## 五、收尾：全部优化做完后要跑的

1. **400 迭代有效 CoreMark**（`--iterations 400`，镜像 `score400`，`+MAX_CYCLES=420000000`）
   - 必须看到 `Correct operation validated`（测试台收尾已从 12000 改到 250000 周期，
     之前截断的问题已修）
   - 记录 ticks、5 项 CRC、≥10 s
2. **PDS 正式流程**（27 MHz 交付约束）：时序 + 资源 + 位流，三数据同一份实现
3. **证据归档**：`evidence/records/optimization/` 一个新目录 + 路线图附录更新
4. **注意迭代数随性能变化**：性能提升后 400 迭代的实际时间会缩短，
   若低于 10 s 必须提高迭代数（公式 `N ≥ ceil(10.5 × f / 每迭代周期数)`）

---

## 六、环境与工具链（踩过的坑，别重复）

| 坑 | 应对 |
|---|---|
| 工具链前缀是 `riscv-none-elf-`，不是赛题写的 `riscv32-unknown-elf-` | 构建用 `--prefix riscv-none-elf-`；`run_isa_e2e.py` 已加该参数 |
| GCC 15 不再隐含 Zicsr | 必须加 `--extra-flag=-march=rv32im_zicsr` |
| `soc_config.vh` 三个开关仓库默认**全关** | 编译前显式打开并**无条件还原**；忘记会得到无 Cache 设计（IPC 0.10 而不是 0.37） |
| ModelSim 复用陈旧 `_opt` 缓存 | 每次编译前删 `work\@_opt*` |
| PDS 把产物写到**当前工作目录**，不是 `build.tcl` 里 `cd` 的目录 | 每次实验换全新空目录，否则读到上次的 `timing_summary` |
| 用脚本 `-replace` 批量改源码 | **禁止**：曾把 `dcache_axi.v` 写成 0 字节。一律用精确编辑 |
| 测试台探针名与 RTL 信号不一致 | 会 vopt 精化失败（vopt-7063）；改 tb 不改 RTL |

---

## 七、仓库与提交

```
7abb8c0  docs: 优化路线图补执行结果汇总
99e8bdb  perf: store 路径后台排空 B 响应，总周期 -8.98%   ← 唯一采纳的性能改动
40a0d16  perf: BTB 扩容实测后判定不采纳，恢复 32 项
7661e3e  perf: 时钟频率收敛实验（P5）50 MHz 收敛
cb7773c  perf: 分支预测 BTB 32 -> 128（后被 40a0d16 否决回 32）
0243470  perf: 取指吞吐与 store 路径的实测结论
57225b8  dcache: 地址切分参数化 + 实测否决扩容
a0d4995  perf: P0/P1 测量脚手架与周期分诊
65982a0  repo: 用 .gitignore + pre-push 钩子阻止仿真跑分数据上传
```

**纪律**：任何提速改动必须同时记 LUT/寄存器，只看 ticks 会做出亏本决策（BTB 那次就是）。
每条结论都要有 A/B 数字 + 单元测试 + ISA 15/15 + CRC 一致四项证据。
