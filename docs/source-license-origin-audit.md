# PDS 代码来源与许可证位置清单

范围：`project/pds_native_120` 当前独立 PDS 包及其关联来源记录。路径均相对于 `D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv`。**CoreMark 全部排除。**

## 一、删除整文件会影响代码、综合或构建校验的文件

以下源文件含来源/提取标记；删除整文件会缺少 RTL 模块或核心源码段，影响当前设计编译、综合或运行。列出它们是为了定位来源标记，不表示建议删除。

### CPU、执行单元与 SoC RTL

- `project/pds_native_120/rtl/core/pango_replica_core.v`（L1）
- `project/pds_native_120/rtl/core/execute/replica_early0_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_early1_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_late0_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_late1_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/sections/000_FetchL1Plugin.vh`（L211-L334 中标出的移位器提取段）
- `project/pds_native_120/rtl/core/sections/010_FetchL1Plugin.vh`（L55-L267 中标出的移位器提取段）
- `project/pds_native_120/rtl/core/sections/019_AlignerPlugin.vh`（L231-L305 中标出的移位器提取段）
- `project/pds_native_120/rtl/core/sections/021_FetchL1Plugin.vh`（L63-L110 中标出的移位器提取段）
- `project/pds_native_120/rtl/core/sections/028_PrefetcherRptPlugin.vh`（L291-L295）
- `project/pds_native_120/rtl/core/sections/029_FetchL1Plugin.vh`（L115-L175 中标出的移位器提取段）
- `project/pds_native_120/rtl/core/support/DivRadix.v`
- `project/pds_native_120/rtl/core/support/RegFileMem.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter_1.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter_2.v`
- `project/pds_native_120/rtl/core/support/StreamFifo.v`
- `project/pds_native_120/rtl/soc/Arbiter.v`
- `project/pds_native_120/rtl/soc/BufferCC.v`
- `project/pds_native_120/rtl/soc/BufferCC_1.v`
- `project/pds_native_120/rtl/soc/BufferCC_2.v`
- `project/pds_native_120/rtl/soc/BufferCC_3.v`
- `project/pds_native_120/rtl/soc/BufferCC_4.v`
- `project/pds_native_120/rtl/soc/BufferCC_5.v`
- `project/pds_native_120/rtl/soc/ContextAsyncBufferFull.v`
- `project/pds_native_120/rtl/soc/Decoder.v`
- `project/pds_native_120/rtl/soc/Decoder_1.v`
- `project/pds_native_120/rtl/soc/Decoder_2.v`
- `project/pds_native_120/rtl/soc/PeripheralDemo.v`
- `project/pds_native_120/rtl/soc/Ram.v`
- `project/pds_native_120/rtl/soc/RamAsyncMwReg.v`
- `project/pds_native_120/rtl/soc/RamSyncMwMux.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_3.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_4.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_5.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_6.v`
- `project/pds_native_120/rtl/soc/StreamFifo_1.v`
- `project/pds_native_120/rtl/soc/TilelinkClint.v`
- `project/pds_native_120/rtl/soc/TilelinkPlic.v`
- `project/pds_native_120/rtl/soc/TilelinkUartCtrl.v`
- `project/pds_native_120/rtl/soc/UartCtrl.v`
- `project/pds_native_120/rtl/soc/UartCtrlRx.v`
- `project/pds_native_120/rtl/soc/UartCtrlTx.v`
- `project/pds_native_120/rtl/soc/WidthAdapter.v`
- `project/pds_native_120/rtl/soc/WidthAdapter_1.v`
- `project/pds_native_120/rtl/soc/MicroSoc.v`（L1-L2 为 SpinalHDL 生成器信息；整文件是 SoC RTL）

### 来源清单（不是 RTL）

- `project/pds_native_120/rtl/core/manifest.json`（L3-L7 记录提取阶段、参考文件名、参考 SHA256、字节数和行数）。删除不改变硬件逻辑，但该文件列入发布校验清单，删除会导致 `verify/build` 校验失败。

## 二、删除不改变 RTL 逻辑的文件或注释段落

### A. 许可证、来源说明文件

以下许可证/来源文件目前均已不存在（`project/pds_native_120/provenance/` 目录不存在）。删除不影响 RTL 逻辑、综合或运行，但会失去许可证文本、版权/来源声明或审计记录：

- `project/pds_native_120/provenance/NOTICE.md`（已删除）
- `project/pds_native_120/provenance/licenses/VexiiRiscv-MIT.txt`（已删除）
- `project/pds_native_120/provenance/licenses/SpinalHDL-notice.txt`（已删除）

当前非 CoreMark 的 RTL 文件中未检出 `Copyright`、`SPDX-License-Identifier`、`Licensed under` 或许可证条款正文。上列已删除文件是目前能确认的直接许可证/NOTICE 文件位置。

### B. 当前代码中的来源注释段落

这些段落都是注释。只删注释并保留空白/换行，不改变 RTL 运算逻辑；但改动受发布 SHA256 清单保护的文件会导致现有 `verify/build` 校验失败。此处仅列定位信息，不表示建议删除。

#### B1. 提取过程说明（相同原文）

注释原文（L1）：

```verilog
// Source-extraction compilation-unit preamble (not reference payload).
```

出现于以下文件，均为 L1：

- `project/pds_native_120/rtl/core/pango_replica_core.v`
- `project/pds_native_120/rtl/core/support/DivRadix.v`
- `project/pds_native_120/rtl/core/support/RegFileMem.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter_1.v`
- `project/pds_native_120/rtl/core/support/StreamArbiter_2.v`
- `project/pds_native_120/rtl/core/support/StreamFifo.v`
- `project/pds_native_120/rtl/soc/Arbiter.v`
- `project/pds_native_120/rtl/soc/BufferCC.v`
- `project/pds_native_120/rtl/soc/BufferCC_1.v`
- `project/pds_native_120/rtl/soc/BufferCC_2.v`
- `project/pds_native_120/rtl/soc/BufferCC_3.v`
- `project/pds_native_120/rtl/soc/BufferCC_4.v`
- `project/pds_native_120/rtl/soc/BufferCC_5.v`
- `project/pds_native_120/rtl/soc/ContextAsyncBufferFull.v`
- `project/pds_native_120/rtl/soc/Decoder.v`
- `project/pds_native_120/rtl/soc/Decoder_1.v`
- `project/pds_native_120/rtl/soc/Decoder_2.v`
- `project/pds_native_120/rtl/soc/PeripheralDemo.v`
- `project/pds_native_120/rtl/soc/Ram.v`
- `project/pds_native_120/rtl/soc/RamAsyncMwReg.v`
- `project/pds_native_120/rtl/soc/RamSyncMwMux.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_3.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_4.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_5.v`
- `project/pds_native_120/rtl/soc/StreamArbiter_6.v`
- `project/pds_native_120/rtl/soc/StreamFifo_1.v`
- `project/pds_native_120/rtl/soc/TilelinkClint.v`
- `project/pds_native_120/rtl/soc/TilelinkPlic.v`
- `project/pds_native_120/rtl/soc/TilelinkUartCtrl.v`
- `project/pds_native_120/rtl/soc/UartCtrl.v`
- `project/pds_native_120/rtl/soc/UartCtrlRx.v`
- `project/pds_native_120/rtl/soc/UartCtrlTx.v`
- `project/pds_native_120/rtl/soc/WidthAdapter.v`
- `project/pds_native_120/rtl/soc/WidthAdapter_1.v`

#### B2. 四个移位器的提取与映射说明

每个文件均有以下 L1-L2 注释：

```verilog
// Verbatim reference shifter extraction; no added pipeline state.
// Provenance and equation source lines: ../manifest.json
```

- `project/pds_native_120/rtl/core/execute/replica_early0_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_early1_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_late0_shifter.v`（L1-L2）
- `project/pds_native_120/rtl/core/execute/replica_late1_shifter.v`（L1-L2）

#### B3. 原参考行号映射注释

注释原文模板：`// Reference line <原始行号> moved verbatim to <移出后的模块名>.`。以下标注都是连续的逐行注释段落：

- `project/pds_native_120/rtl/core/sections/000_FetchL1Plugin.vh`：L211-L227、L272-L288、L295-L311、L318-L334。
- `project/pds_native_120/rtl/core/sections/010_FetchL1Plugin.vh`：L55-L58、L219-L222、L241-L244、L264-L267。
- `project/pds_native_120/rtl/core/sections/019_AlignerPlugin.vh`：L231-L235、L279-L283、L290-L294、L301-L305。
- `project/pds_native_120/rtl/core/sections/021_FetchL1Plugin.vh`：L63-L110。
- `project/pds_native_120/rtl/core/sections/028_PrefetcherRptPlugin.vh`：L291-L295。
- `project/pds_native_120/rtl/core/sections/029_FetchL1Plugin.vh`：L115-L119、L143-L147、L171-L175。

#### B4. SoC 生成器标记

`project/pds_native_120/rtl/soc/MicroSoc.v` L1-L2：

```verilog
// Generator : SpinalHDL dev    git head : de72faf6062206a89b445e5cc07e32ed982712c8
// Component : MicroSoc
```

这是生成器/组件来源信息，不是许可证条款。删除这两行注释不改变 RTL 逻辑；删除整个 `MicroSoc.v` 会影响 SoC 设计，见第一部分。

### C. 文档与板测来源记录（不是 RTL 逻辑）

- `project/pds_native_120/README.md`：L1 标题为“完整参考逻辑仿照基线”；L7 说明核心保留冻结参考原式、移植尚未全部模块化，并明确“不能把移植称为自主原创架构”；L18 说明 `provenance/` 原用于来源映射、原式提取清单和许可证。删 README 不改变硬件逻辑；但 README 受发布清单校验，删除或修改会使现有校验失败。
- `project/pds_native_120/rtl/core/manifest.json`：L3-L7 记录四个逐字提取的 shifter、参考文件路径 `rtl/generated/MicroSoc.v`、参考哈希、字节数、行数。它是来源/验证元数据，不是注释；删除不改变 RTL 逻辑，但会使发布校验失败。
- `bitstream/replica_native_120/source_manifest.json`：L3-L7 重复记录提取阶段、参考路径和 SHA256；来源/构建证据，删除不改变 RTL 逻辑。
- `bitstream/replica_native_120/measurement.json`：L4 的 `source_stage` 记载“四个 verbatim shifter modules”；板测记录，删除不改变 RTL 逻辑。

## 三、版权/许可证注释核查结果

- 当前非 CoreMark RTL 未检出版权声明或许可证正文注释。
- 当前仍存在的明确来源注释见第二部分 B1-B4；其中 B1-B3 明确说明提取或原参考行映射，B4 标明 SpinalHDL 生成器和组件。
- MIT/SpinalHDL 的许可证及 NOTICE 文件路径见第二部分 A；这些文件已缺失，不能从当前目录检查其完整条款。
