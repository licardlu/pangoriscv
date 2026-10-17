# 可信基线：独立重建 + 上板复测（v3.1）

本文记录本轮“先保存可信基线”的完整身份链：**源码 → 固件镜像 → 综合 → 位流 → 上板 UART**。
每一环都有 SHA256，构建过程**没有覆盖**任何历史位流、也没有修改仓库里的生产源码
（只用 `git archive` 展开的副本，宏开关只改副本）。

- 构建时间：2026-10-17 20:48（位流生成），同日 20:5x 上板
- 工作目录：`evidence/records/bottleneck_audit/baseline_build/`
- 复现命令：`results/commands.md` §3.6

## 1. 源码身份

| 项 | 值 |
|---|---|
| 仓库 HEAD | `613fc88565300b28ef8dfc4205cda9271344f1ba`（`provenance/git_head.txt`） |
| 展开方式 | `git archive --format=tar -o tree.tar HEAD firmware/code` 后 `tar -xf` |
| 文件数 | 146（HEAD 的 `firmware/code`） |
| 聚合 sha256 | `CB262E679FF3DE570CBD8A7DC98EA671FA1545DBEF46CDA2BC2FCE921F9B3CF8`（`provenance/baseline_src_sha256.tsv`） |
| CoreMark 源 | 11 个文件从 `E:\file\pango\backups\tinyriscv_before_advanced_cpu_20261012_212358\tests\example\coremark\` 恢复到副本的 `tests/example/coremark/`（HEAD 里不含它们） |

**唯一的源码改动**（只在副本里，仓库工作树不动）：`src/rtl/core/soc_config.vh:34-36` 取消三行注释，
打开 `CACHE_ENABLE` / `PREDICT_ENABLE` / `PERF_ENABLE`。

| 版本 | sha256 |
|---|---|
| HEAD 原样（备份 `provenance/soc_config.vh.gitasis`） | `248838404F6F8ACF49E9874A13C63293E168C02336D25CDB329B9236928FF07D` |
| 打开三个宏后 | `BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D` |

> 为什么不用 `+define+` 传给 PDS：`compile -compiler_directives "+define+CACHE_ENABLE ..."`
> 被 PDS 判为非法（`W: The "+define+CACHE_ENABLE" in compiler directives is invalid, ignore it.`），
> 构建照常完成但其实是默认配置。详见 `commands.md` §3.6 坑 3。

## 2. 固件身份（400 迭代 performance 镜像）

构建命令：`python tools\build_native_software.py coremark --iterations 400 --mode performance --cpu-mhz 27 --toolchain-bin <tc>`

编译参数（`manifest.json` 记录）：`-march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding
-fno-builtin -fno-common -ffunction-sections -fdata-sections -falign-functions=4 -falign-jumps=4
-falign-loops=4 -DCPU_FREQ_MHZ=27 -DITERATIONS=400 -DPERFORMANCE_RUN=1`

| 产物 | 大小 | sha256 |
|---|---|---|
| `program.hex` | 40,960 B | `4AD7DE6B14F6954BA3E04B93574713F4619101B3388DEC3CDE13F7B355E82EC6` |
| `data.hex` | 40,960 B | `6FFD4571DA129E86EEE388AC737C29191BF745BDEB9BB55B262EFF454CA06298` |
| `coremark.elf` | 21,364 B | `B8512B8D2017552764766C63220F44B41FE7AFCF5EE69D180510B28A7FDA474B` |
| `manifest.json` | — | `3547E5F72F20B283B49E4C69A9621D752B9AB9DE643891BEF36FC6AEEC547988` |

工具链：`riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509`。
清单：`provenance/firmware_sha256.tsv`。

## 3. 综合身份（PDS 2022.2-SP6.4）

| 项 | 值 |
|---|---|
| 位流 | `baseline_build/artifacts/pangoriscv_i400_baseline_fullfeature.sbit` |
| 大小 / sha256 | 3,791,112 B / `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77` |
| 资源 | LUT **12,441** / 66,600（19%）、FF 7,268（6%）、DRM 4.5 / 155、IO 13 / 300 |
| 时序 | Setup slow **16.440 ns**、Hold slow **0.018 ns**、Setup fast **24.232 ns**、Hold fast **0.012 ns**，48,214 端点，**All Constraints Met** |
| 内存载入 | `compile/run.log` 有两条 `Loading memory data from file …/program.hex`、`data.hex`，且 `Board check: 2 memory images loaded into the design.` |
| 构建日志 | `baseline_build/pds_build.log` |

时序与端点（48,214）与交付的 stageT 位流（16.262 / 0.024 / 24.216 / 0.014，同样 48,214 端点）
几乎一致 ⇒ 可确认**同配置**；位流 sha256 不同属正常（P&R 迭代路径不同）。

## 4. 上板复测（本轮新做）

流程：`00_scan_chain.tcl` 确认链路 → **先开串口** → `01b_program_only.tcl` 下载 → 采集 90 s。

- 链路：`PG2L100H`，ID `0x00602899`，`scan_chain OK: 1`
- 下载：`The done bit is 1`、`program OK: 1`
- 采集：COM13 @ 115200 8N1，705 chars / 705 B

| 项 | 值 |
|---|---|
| UART 文本 | `results/board_uart_baseline.txt`（sha256 `78B7D08D0C6AAB0AB7EE575182C46A21EB458136C78CCE0CF2B0C3CC241A593F`） |
| **Total ticks** | **320,725,708** |
| `CPM_TICKS hi/lo` | `0` / `320,783,213` |
| Total time (secs) | 11（该字段是整数截断，实际 11.88 s） |
| Iterations / Sec | 36（整数截断） |
| Iterations | 400 |
| CRC | seed `0xe9f5`、list `0xe714`、matrix `0x1fd7`、state `0x8e3a`、final `0x25b5` |
| 结论行 | `Correct operation validated. See readme.txt for run and reporting rules.` |
| 运行时长 | 320,725,708 / 27e6 = **11.88 s ≥ 10 s** |
| 重复性 | 连跑两次逐字节相同（`board_uart_baseline.txt` 与 `board_uart_baseline_run2.txt`，同一个 sha256） |

### 精确成绩（按 ticks 算，不用截断秒）

- 每迭代拍数：320,725,708 / 400 = **801,814 拍**
- **CoreMark/MHz = 400 × 10⁶ / 320,725,708 = 1.2472**
- 绝对分（27 MHz）：**33.67**

## 5. 与交付位流的关系

| | 交付位流（repo `bitstream/pangoriscv_i400.sbit`） | 本轮基线 |
|---|---|---|
| 位流 sha256 | `F8254F66EF9C78B53E3DD4E6516BA55BAA2F00C7C76EB2379D78FEC8962CE77C` | `747C18CA…68E6D77` |
| 板测 ticks | 320,541,251 | 320,725,708 |
| CoreMark/MHz | 1.2480 | 1.2472 |
| CRC | e9f5 / e714 / 1fd7 / 8e3a / 25b5 | 完全相同 |

两者差 **+0.058%**，来源是**固件镜像重建**（交付位流里烧的那份 `program.hex` 随误删的
`09_validation_results` 丢失，本轮镜像由备份的 CoreMark 源重新编译；CRC 全同说明算法与种子一致，
差的是 `.text` 布局带来的计数窗口差异，不是硬件行为差异）。

**口径约定**：
- 引用“交付成绩”用交付位流那一对（1.2480 CoreMark/MHz）；
- 本轮及后续 A/B **一律用本文件这一对**（源码 + 镜像 + 位流三者都有 sha256），
  优化版的对比对象就是 320,725,708 ticks；
- 因为两个位流的 P&R 不同，跨位流比较会带 ±0.1% 噪声，所以 A/B 必须同配置、同镜像、同流程重跑。

## 6. 没确认的事

1. 本轮基线镜像与交付位流里那份镜像**是否逐字节相同无法证明**（交付镜像已丢失），只有 CRC 与 +0.058% 的间接证据。
2. 板上只做了 SRAM 下载，没做 Flash 固化；掉电即失。
3. `cfg_verify` 在这套工具/板组合上不可用（固有失败），所以“位流与文件一致”靠 sha256 与功能输出，不靠 verify。
