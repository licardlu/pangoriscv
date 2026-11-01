# VexiiRiscv 移植版的来源、归属与实测对比

**记录日期**：2026-10-28
**性质**：本赛题项目（`pangoriscv`）内的一个**外部内核评测分支**，不是自研 CPU 的替代品。

---

## 一、这份东西是什么

同学提供的 `VexiiRiscv改进版` 压缩包：板级/工程沿用本仓库（`pangoriscv`）的参数与经验，
**CPU 内核换成 VexiiRiscv**（SpinalHDL 自动生成的 Verilog），目标是 RV32IMC 双发射、
CoreMark/MHz ≥ 5.2、主频 ≥ 120 MHz。

提供方已在包内说明：名称"改进版"指集成与配置修改，**不代表 VexiiRiscv 内核由本项目原创**。

---

## 二、著作权归属（不可变更）

以下归属**原样保留**，本项目不主张、不修改、不删除：

| 组件 | 著作权 | 许可 | 固定版本 |
|---|---|---|---|
| VexiiRiscv | Copyright (c) 2023 SpinalHDL | **MIT** | `ae9060aca523e406fc6f3ba2a502414956ac495b` |
| SpinalHDL | Copyright SpinalHDL | core **LGPL** / lib MIT | `de72faf6062206a89b445e5cc07e32ed982712c8` |
| rvls 绑定 | 见上游 | 见上游 | `847ce99fd2b28a5c0ccb1ec2683311cf97a9fefc` |
| CoreMark | EEMBC | Apache-2.0 | `1f483d5b8316753a742cbf5590caf5bd0a4e4777` |

许可全文随包保留在 `upstream/` 下（`LICENSE`、`LICENSE_core`、`LICENSE_lib`），
SpinalHDL/VexiiRiscv 源码随包提供，满足 LGPL 的可重编译要求。

**本项目新增的部分**（若被采用）：板级集成、构建脚本、固件布局一致性修正、结果校验、
以及在 `ai_lab/` 下与本仓库 CPU 的对照测量记录。

---

## 三、归属关系的正确写法

本赛题项目与这份移植版的关系应记为：

> `pangoriscv`（本赛题项目）在评测分支中**引入了** VexiiRiscv（MIT）作为对照实现，
> 用于与自研 RV32IM 内核做同板对比。CPU 内核著作权属 SpinalHDL，
> 本项目不对其主张原创；对照结论见下节。

**不能写成**："本项目的 CPU 采用 VexiiRiscv 并达到 5.35 CoreMark/MHz" —— 这会让读者
误以为内核是本项目成果，与实际不符。

---

## 四、实测对比（同一块 MES2L676-100HP，2026-10-28）

两个位流都在同一块板上烧录、同一串口抓取，CRC 均通过。

| 项 | 本项目自研 RV32IM | VexiiRiscv 移植版 |
|---|---|---|
| CoreMark/MHz | **5.2599** | **5.3463** |
| 主频 | 50 MHz | 120.46 MHz |
| 绝对分数（iter/s） | 263.0 | **644.0** |
| 运行时长 | 15.21 s | 10.87 s（≥10 s 合规） |
| 迭代次数 | 4000 | 7000 |
| CRC（list/matrix/state） | `e714 / 1fd7 / 8e3a` 全对 | 同左，全对 |
| Memory location | **STATIC** | **STACK** |
| LUT | 17,020 | **8,841** |
| 时序（慢角 WNS） | **满足** | **−1.604 ns，829 端点失败** |
| 编译器选项 | `-O2` | `-O2 -funroll-all-loops -ffast-math -mtune=sifive-7-series` 等 |

原始日志：`pangoriscv-verify/runs/uart_pangoriscv_v40_o3_4000_5p26_20261028_122306.txt`、
`pangoriscv-verify/runs/cam_20261028_232412.txt`。

### 三个不可忽略的可比性问题

1. **Memory location 不同**（STACK vs STATIC）。CoreMark 官方规则下两者不可直接比较，
   STACK 通常更快。因此 5.3463 与 5.2599 的差距**不能直接归因于架构**。
2. **编译选项不同**。对方启用了 `-funroll-all-loops`、`-ffast-math`、`-mtune=sifive-7-series`
   等激进优化，本项目的成绩来自 `-O2`。要公平比较需固定同一组选项。
3. **对方时序未闭合**（−1.604 ns）。虽然本次 CRC 全对，但带违例的位流在温度/批次变化下
   不保证复现，**不能作为稳定成绩上报**。

### 结论（只写能被数据支撑的部分）

- 归一化性能两者接近（5.35 vs 5.26），扣除内存位置与编译选项差异后**差距可能消失**；
  需要同条件重测才能定论。
- 绝对吞吐的 2.45 倍差距**全部来自主频**，不来自每 MHz 效率。
- 对方面积约为本项目的一半（8,841 vs 17,020 LUT）。
- 本项目时序干净、可复现；对方 120 MHz 未闭合。

---

## 五、比赛口径上的处理建议

赛题要求"实现一个支持 RV32I 基础整数指令集的通用处理单元"。因此：

- **主线 CPU 仍用本项目自研实现**，VexiiRiscv 只作为**对照实验**出现在分析报告里。
- 报告里引用对比数据时，必须同时写出上表第三、四节的可比性限制，
  不得单独摘出 5.3463 与本项目成绩并列而不加说明。
- 不得把 VexiiRiscv 生成的 Verilog 作为本项目 CPU 源码提交。

---

## 六、构建与复现（本次实测）

```bash
# 纯 ASCII 路径，中文路径会让 PDS 解析失败
cp -r "<源包>" /e/file/pango/vexii_test
cd /e/file/pango/vexii_test && mkdir run1 && cd run1
VEXII_ROOT=/e/file/pango/vexii_test \
  "E:/donwload/PDS_2022.2-SP6.4/PDS_2022.2-SP6.1/bin/pds.exe" -file ../platform/build.tcl
```

- 包内说明称"PDS 编译遇工具内部错误、没有位流"，**实测可以编出来**：
  8 个内存初始化文件全部读入（`run1/compile/run.log` 中 "Loading memory data from file" 计 8 次），
  位流 `run1/generate_bitstream/pango_vexii_top.sbit` 生成并成功烧录。
- 但 `build.tcl` 里的内存加载校验因运行目录不同而失效（它去读 `platform/compile/run.log`），
  所以"8 路读入"是我手工核对的，不是脚本保证的。
- 时序报告：`run1/report_timing/pango_vexii_top.rtr`。
