# 基线独立构建（baseline_build）

本目录保存**与诊断报告同源、可与优化版 A/B 对比的基线**。它不从工作树就地取源，
而是从 git 提交导出，因此“源码 / 固件 / 参数 / 位流”四者的对应关系可独立复核。

## 1. 身份

| 项 | 值 |
|---|---|
| git 提交 | `613fc88565300b28ef8dfc4205cda9271344f1ba`（`provenance/git_head.txt`） |
| 源码范围 | `firmware/code`（`git archive HEAD firmware/code` 导出，非工作树） |
| 源码文件数 | 157（146 交付树 + 恢复的 CoreMark 11 个 C 源） |
| 源码聚合 sha256 | `CB262E679FF3DE570CBD8A7DC98EA671FA1545DBEF46CDA2BC2FCE921F9B3CF8` |
| 固件 app / 模式 | `coremark` / `performance` |
| 迭代次数 | 400（板测口径） |
| CPU 频率 | 27 MHz（功耗/时序口径一致） |
| 工具链 | `riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509` |
| 编译宏 | `CACHE_ENABLE` + `PREDICT_ENABLE` + `PERF_ENABLE`（全功能） |

逐文件哈希见 `provenance/baseline_src_sha256.tsv` 与 `provenance/firmware_sha256.tsv`。

## 2. 固件镜像

`src/build/native_software/coremark/performance/`

| 文件 | 大小 | sha256 |
|---|---|---|
| `program.hex` | 40,960 B | `4AD7DE6B14F6954BA3E04B93574713F4619101B3388DEC3CDE13F7B355E82EC6` |
| `data.hex` | 40,960 B | `6FFD4571DA129E86EEE388AC737C29191BF745BDEB9BB55B262EFF454CA06298` |
| `coremark.elf` | 21,364 B | `B8512B8D2017552764766C63220F44B41FE7AFCF5EE69D180510B28A7FDA474B` |
| `manifest.json` | — | `3547E5F72F20B283B49E4C69A9621D752B9AB9DE643891BEF36FC6AEEC547988` |

## 3. 位流

`src/build/pango_native/generate_bitstream/pango_native_top.sbit`

- 构建命令与两个坑见 `../results/commands.md` §3.6。
- **不覆盖**仓库里已发布的 `bitstream/pangoriscv_i400.sbit`（历史交付位流保持原样）。
- 位流自身 sha256 与 PDS 时序/资源报告记在 `results/baseline_build.md`。

### 3.1 配置开关怎么打开（实测结论）

`rtl/core/soc_config.vh:34-36` 三个宏默认被注释，而交付位流是**全功能**构建（板上 320,541,251
ticks / 400 迭代 = 801,353 拍/迭代，只有全功能配置才可能这么快）。要复现这个配置：

- ❌ **`compile -compiler_directives "+define+CACHE_ENABLE …"` 无效**。PDS 日志明确拒绝：
  `W: The "+define+CACHE_ENABLE" in compiler directives is invalid, ignore it.`（三个宏各一条）。
  用它构建出来的是**默认配置**（无 Cache / 无预测 / 无 perf），`done` 位照样为 1、也能跑，
  但会慢约 3.79×，很容易误判成“构建成功但板上无输出”。
- ✅ 本轮采用：在 `src/`（**构建副本，不是仓库工作树**）里直接把 `soc_config.vh:34-36` 三行
  取消注释。原文件备份在 `provenance/soc_config.vh.gitasis`
  （HEAD sha256 `248838404F6F8ACF49E9874A13C63293E168C02336D25CDB329B9236928FF07D`，
  改后 `BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D`）。
  仓库工作树**未改动**（`git status` 干净）。
- 判断“宏是否真的生效”的可靠办法：看 `compile/run.log` 有没有上面那条 `invalid, ignore it`
  警告；最终以板上跑分为准（全功能 ≈ 801 k 拍/迭代，默认 ≈ 3.05 M 拍/迭代）。

### 3.2 上板与串口（实测）

- 串口 = 板载 **CP2102** → `COM13`，115200 8N1（`pango_native.pcf`：`uart_tx`=C24 → CP2102 RX，
  `uart_rx`=B24 ← CP2102 TX）。
- 下载链路 = Pango USB Cable II（FT2232H）：`cdt_js.exe`（JtagServer）+ `cdt_cfg.exe`。
- `cfg_verify` **不要**作为成功判据：实测 `E: JtagServer-0607: Fail to compare …` 与
  `C: Bitstream-2001: SCBV has not been set`（官方 demo 同样有该警告）。
  判据 = `program OK` + `The done bit is 1` + **串口真实输出**。
- 一次失败的 `cfg_verify` 会让后续命令全部报
  `W: Public-4023: Error has occurred, please run command clean before running again`
  （`cfg_clean` 不存在；`cfg_reset_fpga` 在“no device in Jtag chain”时也无效）。
  恢复办法：`Stop-Process cdt_js,cdt_cfg` 后重启服务器，必要时重插下载线。
- **抓串口必须“先开串口、再下载”**：镜像只打印一次；400 迭代要跑 ~12 s，先下载后抓会错过整段输出
  （本轮前几次 0 字节就是这个原因）。`board/capture_uart.ps1` 的 `-Seconds` 要覆盖
  “下载 ~10 s + 启动 ~2 s + 跑完 ~12 s”，建议 ≥ 60 s。

## 4. 目录约定

```
baseline_build/
  src/                    导出的干净源码树（157 文件）+ 构建产物
    platform/pango_native/  构建脚本（build.tcl 带 PANGO_NATIVE_DEFINES 支持）
    build/native_software/  固件镜像
    build/pango_native/     PDS 流程目录（compile/ synthesize/ device_map/ place_route/ generate_bitstream/）
  provenance/             源码与固件哈希清单、git head
  pds_build.log           PDS 完整日志
  board_uart_baseline.txt 板上串口原始抓取（见 results/baseline_build.md）
```

> `src/` 与 `board_uart_baseline.txt` 不入库（体量大且可重建），由本 README +
> `provenance/` + `results/baseline_build.md` 记录身份与校验值。
