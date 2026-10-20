# area-M2：数据 RAM 改 BRAM —— **三次尝试均未生效（否定结果，已回退）**

日期：2026-10-21
阶段：`module-area-plan.md` 的 **M2**
结论：**映射器不接受这个阵列的 BRAM 推断**。RTL 已完整回退，工作树恢复冻结 RTL。

---

## 1. 目标

把 `soc/data_ram`（16 KB，0x1000_0000）从 **2,048 个 LUTRAM**（占全设计 LUTRAM 的 56%）
改成 **BRAM**。同模块的只读实例（`soc/program_ram`）已经是 `4 × GTP_DRM36K_E1`，
说明这条流程的 BRAM + `$readmemh` 是可用的。

## 2. 三次尝试与结果

| 尝试 | 改动 | LUT | FF | LUTRAM | DRM | 结论 |
|---|---|---:|---:|---:|---:|---|
| 基线（M1 后） | — | 20,422 | 12,335 | 3,628 | 4 | 参照 |
| 1 | `syn_ramstyle = "block_ram"` | 20,422 | 12,335 | 3,628 | 4 | 无变化 |
| 2 | 追加：`for` 字节循环改成 4 条显式字节写 | 20,421 | 12,335 | 3,628 | 4 | −1 LUT（噪声），仍无 BRAM |
| 3 | 属性值改 `"block_ram,no_rw_check"` | 20,421 | 12,335 | 3,628 | 4 | 仍无 BRAM |

每次都确认：`compile/run.log` 有 2 条 `Loading memory data from file`（镜像正常装载），
说明"没生效"不是镜像问题。

## 3. 诊断（有日志依据）

1. 综合日志明确打印了属性翻译：
   ```
   I: [...] Convert attribute name from syn_ramstyle to PAP_RAM_STYLE
   ```
   → **属性被识别、被改名，但没有产生效果**（不是属性名写错）。
2. `syn_ramstyle="block_ram"` 与 `"block_ram,no_rw_check"` 都是 Pango 自带参考模型的写法
   （`syn/lib/syncore/models/memories/ram/syncore_ram.v` 里就有这两行），排除了"值不合法"。
3. 推理阶段仍是 4 个字节通道各自成表：
   ```
   Found Ram mem, depth=4096, width=8.   (×4，来自 axi_ram.v)
   ```
   而只读实例同样 4 KB 结构却成了 ROM（`4 K x 8 ... GTP_DRM36K_E1`）。
4. 因此瓶颈在**读端口形态**：`read_data <= mem[read_index]` 是"寄存器地址 + 当拍组合读"，
   映射器不认为它是 BRAM 能接受的同步读；同拍可写又让它默认保留读写旁路。
   `no_rw_check` 也没能改变判断。

## 4. 下一步可试（未做，留给后续）

| 方案 | 代价 | 说明 |
|---|---|---|
| A. 把读改成显式同步形态：单独一个 `always @(posedge clk) if (read_en) read_data <= mem[rd_addr_q];`，`read_en/rd_addr_q` 与状态机解耦 | 可能多 1 拍读延迟（D-cache 缺失才走，实测 0.1% 周期） | 最可能让映射器接受 |
| B. 查 Pango `PAP_RAM_STYLE` 的合法取值（`syn/examples/.../Memory/syn_ramstyle.xml` 有 GUI 帮助） | 低 | 若属枚举值不同（如 `block`/`bram`），一行就能解决 |
| C. 放弃 M2，把数据 RAM 留在 LUTRAM | 0 | 换来的是 LUTRAM 3,628 与相应的布线压力 |

## 5. 为什么现在不继续

按 `module-area-plan.md` 的停机规则（"两次尝试失败即跳过"）已用满三次。
继续需要改读路径的时序（方案 A），那属于"动访存语义边缘"，必须先有 20 迭代 A/B 与
`RAM 20/20` 回归，不该在面积专项里顺手做。

## 6. 证据

| 文件 | 内容 |
|---|---|
| `attempt1_attribute_only_used.txt` | 尝试 1 的利用率表 |
| `attempt2_byte_lanes_used.txt` | 尝试 2 |
| `attempt3_block_ram_no_rw_check_used.txt` | 尝试 3 |
| `attribute_translated_then_ignored.txt` | 属性被翻译的日志原文 |

构建目录（未入库）：`firmware/code/build/area_m2`、`area_m2b`、`area_m2c`。
