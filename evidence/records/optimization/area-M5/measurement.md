# area-M5/M6：缓存阵列"副本"与 3,070 FF 的来源 —— **仅分析，不改 RTL**

日期：2026-10-21
阶段：`module-area-plan.md` 的 **M5 / M6**（原为"条件性删副本"）
结论：**副本不是冗余，是多读端口的物理必然**。不改 RTL，预算里的 −512/−256 LUTRAM 撤销。

---

## 1. 为什么怀疑有副本

| 证据 | 数值 |
|---|---|
| `apm_drm_lutram_utilization.log` 里 I-Cache 的阵列 | `even_mem`、`even_mem_1`、`odd_mem`、`odd_mem_1` 各 **512×32** = 合计 **8 KB** |
| RTL 里声明的 I-Cache 容量 | `SETS*2*(WORDS/2)` × 32 b × 2 bank = **4 KB** |
| `icache_axi` 网表里的原语 | **1,024 个 `GTP_RAM64X1DP`**（= 8 KB）+ **3,070 个 `GTP_DFF`** |
| RTL 侧声明的寄存器 | 约 200 位（`state/addr_q/id_q/set_q/word_q/tag_q/way_q/rd_index_q/rsp_*`） |

所以"8 KB 阵列 + 3,070 FF"确实是**综合器加出来的**，不是 RTL 写的。

## 2. 查清机制（有 RTL 依据）

`rtl/core/icache_axi.v` 对**同一个 bank** 每拍要做两次异步读：

```verilog
wire [31:0] hit_even = even_mem[hit_e_index];   // 命中判定用的字
wire [31:0] rd_even  = even_mem[rd_e_index];    // 补行/配对取指的另一个字
```

即 **每 bank 2 个读地址**（命中路径 + 取指路径），而 Pango 的 `GTP_DRM36K_E1`
在 `apm_drm_lutram_utilization.log` 里报的 `Ram_Mode` 只有 `SINGLE_PORT`
（1 读 1 写）——**没有双读口**。综合器的处置方式就是：

1. **复制阵列**满足 2 个异步读口（4 KB → 8 KB，`_1` 后缀即副本）；
2. 给每个读口的输出加**寄存器**（1,024 个 1 位 RAM 原语 → 每个读口一份输出寄存器），
   这就是那 3,070 FF 的来源。

D-Cache 同理：RTL 2 KB，映射日志给了 3 个 512×32（1.5 倍），同时存在
"命中读 + 写合并读"两个口——**那 212 个 primitive 的差额也是副本**，M6 一并解释清楚。

## 3. 结论：不能删

删掉 `_1` 副本 = **砍掉一个读端口**，直接后果：

- 配对取指（同拍取 PC 与 PC+4）要么变成两拍，要么失效；
- 命中断言与补行写回无法同拍进行，命中路径要加状态；
- 属于**功能重构 + 性能回退**，不是面积裁剪。

按 `module-area-plan.md` 的纪律（"证据不足 → 只留分析结论"），本步**不改 RTL**。

## 4. 若将来一定要把缓存搬进 BRAM（记录备选，不在本专项）

| 前提 | 代价 |
|---|---|
| 把每 bank 降到 1 个读口（命中与补行串行化） | 配对取指能力下降，CoreMark 大概率变慢 |
| 用 2 片 DRM 拼双读口（同一地址复制到两片） | 面积 ×2 的 BRAM（8 DRM，仍比 8 KB LUTRAM 省），但要重写读路径与命中判定 |

两者都要 A/B + 全回归 + 上板，属于单独立项。

## 5. 证据

| 文件 | 内容 |
|---|---|
| `icache_ff_attribution.txt` | `icache_axi` 网表原语统计：3,070 DFF + 1,024 RAM64X1D，含实例名样本 |
| `icache_read_ports.txt` | RTL 里两个读地址（`hit_even` / `rd_even`）的原文 |
| `dram_mode.txt` | 映射日志里的 `SINGLE_PORT` 证据 |

（本目录由同一次会话生成；数据来源 `build/area_m4a` 与 `build/area_final`。）
