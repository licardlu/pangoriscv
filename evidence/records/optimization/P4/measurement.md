# P4 · 分支预测优化结果（2026-10-17）

> 本轮唯一完成闭环的优化族。结论：**BTB 32 → 128 项，总周期 −1.84%，预测失败 −27.1%，
> 5 项 CRC 与基线完全一致。**
> 证据等级：仿真实测（20 迭代，同一镜像 A/B）+ 单元测试 + ISA 端到端。

---

## 1. 改动

`rtl/core/branch_predictor.v`：`ENTRIES` 32 → 128。

该模块的索引/标签位宽本来就由 `$clog2(ENTRIES)` 推导（`IDX_BITS`、`TAG_BITS`），
所以只需改一处参数，地址切分自动跟随，无需改任何逻辑：

```verilog
parameter integer ENTRIES = 128   // direct-mapped sets, index derived from ENTRIES
```

---

## 2. 实测（20 迭代，镜像 `perf_on` 不变）

| 指标 | 基线 32 项 | 128 项 | 256 项 |
|---|---|---|---|
| Total ticks | 15,316,450 | **15,035,153**（−1.84%） | 14,989,547（−2.13%） |
| cycles | 17,256,182 | 16,974,361 | 16,928,754 |
| 预测失败 | 154,553 | **112,723**（−27.1%） | 106,410（−31.1%） |
| 5 项 CRC | 0xe714 / 0x1fd7 / 0x8e3a / 0x4983 | **完全一致** | 完全一致 |

**为什么取 128 不取 256**：128→256 只再省 0.30% 周期，但 BTB 存储翻倍
（每项 valid 1 + tag 23~24 + target 32 + uncond 1 + count 2 ≈ 60 bit）。
按资源效率口径（CoreMark/LUTs）不值得，故交付值取 128。

---

## 3. 正确性证据（三重门）

| 门 | 结果 |
|---|---|
| 单元测试 `run_predictor_tests.py` | **PASS**（`tb_branch_predictor`） |
| ISA 端到端 `run_isa_e2e.py --cases all` | **15 / 15 PASS**（含分支/jal/jalr 错误路径抑制、CSR、异常、中断） |
| CoreMark 5 项 CRC | 与基线**逐项相同** → 架构等价 |

---

## 4. 顺带修好的工具链阻塞

`tools/run_isa_e2e.py` 原先把工具链前缀写死为 `riscv32-unknown-elf-`，而本机是 xpack
的 `riscv-none-elf-`，且 GCC 15 需要显式 `-march=rv32im_zicsr`。已加两个参数（默认值
保持向后兼容）：

```
--prefix riscv-none-elf-   （默认 riscv32-unknown-elf-）
--extra-flag=-march=rv32im_zicsr   （可重复）
```

实测命令：

```powershell
python tools/run_isa_e2e.py --cases all `
  --toolchain-bin "<xpack>\bin" --prefix riscv-none-elf- `
  "--extra-flag=-march=rv32im_zicsr" --modelsim "<ModelSim>"
```

> 尝试过用"改名前缀的 shim 目录"兼容旧脚本，失败：GCC 内部 `cc1` 路径按目标三元组
> 推导，改名找不到 `cc1`。所以改脚本参数是唯一干净解法。

---

## 5. 剩余三族的当前状态（不在本记录范围）

| 族 | 状态 | 原因 |
|---|---|---|
| store 路径 | **未完成** | 需 AXI 写引擎支持多笔未完成写；单笔结构下"不等 B"换不来收益 |
| IFU 取指吞吐 | **未完成** | IFU 与 I-Cache 各需 2 拍，构成 0.5 IPC 结构性上限；合并改动试过，死锁后回退 |
| 时钟频率 | **受限** | 板载 27 MHz 单端晶振，无 PLL 改造前频率不由设计决定 |
