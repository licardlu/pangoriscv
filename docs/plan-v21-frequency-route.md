# v21 —— 频率攻坚：切② 的第三种做法成功 + 切⑥ 落地（2026-10-24）

工作分支 `exp/split`（从交付 `exp/pair45` 拉出，**不叠加 S1+S2**）。
本文档只记录**有实测支撑**的结论。

---

## 0. 成绩

| 项 | 结果 | 证据 |
|---|---|---|
| 切⑥ D\$ 阵列写口打拍 | **完成，零 CPI** | ticks 3,810,700 / CRC 0x4983 / ISA 20/21 |
| 切② CSR 读口解耦（第三版）| **完成，零 CPI** | ticks 3,810,700 / CRC 0x4983 / ISA 20/21 |
| 上板 | **被硬件阻断**：JTAG `No devices detected`（板子未上电/排线未接）| `bottleneck_audit/board/p50_scan_chain.log` |

两刀合计从最差路径上拿走 **② 5.30 ns + ⑥ 2.58 ns**，CPI 一分未花。

---

## 1. 切② 前两次错在哪（值得记住的机制，不是流水账）

plan v19 §11/§12 记过两次失败：读口只接 `id_csr_addr`（ISA 11/21）、
`wb_value` 取 `w_csr_old`（ISA 19/21）。本轮加探针后把机制彻底看清：

### 1.1 `serial_q` 只隔 1 拍

`serial_q` 在被串行指令**接受**时置位、在它**到达 WB** 的拍清零，所以下一条指令
会在它 WB 的**同一拍**进入 M2。而 CSR 的写在 WB 的**边沿**才落地
⇒ 相邻两条 CSR 指令里，后一条最早只能在**它自己的 WB 拍**读到前一条的结果。

### 1.2 读-改-写与 rd 必须是同一个采样

`csr_new = w_csr_old | w_csr_src` 既是写回 CSR 的新值，也决定 rd 的旧值。把读提前到 M2
后探针给出（`csrrs x3,mscratch,x0` 跟在 `csrrw x2,mscratch,x1` 后面）：

```
CSRN commit=1 addr=340 wd=ffffffff mscr=00000000 nsc=ffffffff   <- csrrw 写 mscratch
CSRN commit=1 addr=340 wd=00000000 mscr=ffffffff nsc=00000000   <- csrrs 读到旧值 0，把它写回去
```

`csrrs rd,csr,x0` 语义上**不写**，但 `commit` 只看 `w_commit && w_csr`，于是把 0 写了回去。

## 2. 切② 第三版：怎么修

三处改动，缺一不可：

1. **`csr_native` 拆三个地址端口**：`addr`（提交写）、`raddr`（取值，接 M2）、
   `iaddr`（合法性判断，接 ID）。读用的 12 路 mux 从此只喂一个寄存器。
2. **`wb_value = w_csr ? w_csr_old : w_value`**，`w_csr_old <= csr_rdata`（M2 采）。
   `w_valid` 与 12 路 CSR mux 从 RF 写口前面彻底消失。
3. **`serial_q` 早一拍置位**：`id_accept && (dec_serial || id_serial)`。
   原来是 `id_serial`（已经在 ID 里那条），会让紧随其后的指令"漏进" ID 一拍。
   改成 `dec_serial`（正在被接受那条）后，相邻 CSR 指令正好隔开 1 拍，
   M2 取值就落到了前一条提交之后的那个周期。

**为什么第 3 条是承重的**：单独做 1+2 就是 v19 的第二次失败。第 3 条把"相邻 CSR 的
取值点"从"前一条提交的同一拍"推到"下一拍"，读-改-写与 rd 才拿到同一个正确值。

实测：`Total ticks 3,810,700` **逐位不变**，五项 CRC 全对，ISA **20/21**
（case 6 `CSR read/write rules`、case 7 `mcycle/minstret` 都过，只剩基线本就红的 case 21）。

### 2.1 一条新的判据（补进 lesson）

> "CSR / 寄存器堆 / 陷阱类改动，`ticks 逐位不变 + CRC 对` 不够，必须 ISA 20/21"
> 这条仍然成立；本轮补一条**正向**经验：
> **`serial_q` 的置位条件用的是"已经在 ID 的那条"还是"正在被接受的那条"，
> 差一拍，而这一拍正好决定相邻 CSR 指令能不能读到前一条的提交。**

---

## 3. 切⑥ 的实现

`dcache_axi.v`：store 命中的阵列写从 `didx(hit_way,req_set,req_word)` 组合锥改成
`sw_we_q/sw_idx_q/sw_data_q/sw_strb_q` 寄存器，下一拍落地；读侧加
`sw_idx_q == rd_didx` 的 10 位比较 + 字节 mux 做 store→load 转发。
被删掉的是 `N4033[0]`（fanout=256，单根网线 **2.58 ns**，路径尾部）。

判定"转发是必需的"依据：CoreMark 每迭代 store 约 2e4 次，"store 后阻塞一拍读"
直接是 −0.7 分（v19 §13 已算过），所以只能转发不能阻塞。

---

## 4. 剩余路径与 120 MHz 的边界账

交付版最差路径（`p48e/report_timing.rtr`，19.563 ns）逐段，以及本轮之后的状态：

| 段 | 内容 | 段耗 | 状态 |
|---|---|---|---|
| ① | CLK→`w_valid` | 0.25 | — |
| ② | `w_valid`→CSR 读 mux→`alu_a` | **5.30** | **已消除**（§2）|
| ③ | ALU（lane 0）| 3.31 | 仍在 |
| ④ | `alu_y`→`fwd1_h`→lane1 地址加法器 | 3.16 | 仍在 |
| ⑤ | D\$ 查找 | 4.89 | 仍在 |
| ⑥ | 阵列写地址（fanout 256）| 2.58 | **已消除**（§3）|

### 4.1 新的关键结构事实

- **lane 0 自己的访存**：地址 = `fwd1 + imm`，**不经过 ALU** ⇒
  `fwd(1.19) + adder(0.68) + D$(4.89) ≈ 6.8 ns`，本来就够快。
- **lane 1 的访存**：地址 = `fwd1_h + imm_h`，而 `fwd1_h` 在**同包 RAW** 时就是
  lane 0 的 `alu_y` ⇒ 路径变成 `RF读 → fwd → ALU(③) → fwd1_h(④) → adder → D$(⑤)`，
  串联 ~14 ns。**这才是唯一让整机上不去的原因。**
- 所以：`alu_y → fwd1_h → lane1 adder` 这条链是剩下最大的一刀（③+④ ≈ 5 ns）。

### 4.2 为什么不能"干脆禁止 lane1 访存"

ISA case 18（`lane1 memory: address/store-data forwarding and load consumers`）
就是覆盖它的用例，配对覆盖率是判据的一部分 ⇒ 禁止配对会直接挂。

### 4.3 120 MHz 的代价账（未变）

若要再切一级把 ①②之间或 ALU 之前的那段独立出来，分支会晚一级解决
⇒ **每迭代 +4,945 拍**（重定向次数）；5.2 分只剩 **1,772 拍**余量
（192,307 − 190,535）。所以：
**任何再加的流水级都必须先有 3k~5k 拍/迭代的净减，否则分数掉到 5.1 以下。**

---

## 5. 下一步（按性价比排序）

1. **量本轮的真实频率收益**：`--freq 50 --mode full --place-only` 与满流程，
   看 `report_timing` 的最差路径换成了什么。预期从 19.5 ns 降到 13~15 ns（≈70~77 MHz）。
2. **`alu_y → lane1 adder` 那一刀（唯一还有价值的零拍候选）**：
   lane 0 的 ALU 若为 `add/addi/sub`，lane 1 的地址可以写成
   `alu_a + alu_b + imm_h`（三输入：CSA + 一条进位链），**绕过 ALU→mux 两级**，
   理论上省 3~4 ns 而不是花 1 拍。代价是"只有加减能走快路"，
   其它 opcode 仍走原路（那部分保持现状即可，不做新 stall）。
   这是结构性改动，需单独立项 + ISA 17/18 判据。
3. **上板**：先把 ②+⑥ 的位流跑出来，板子一上电就测；`cfg_scan_chain` 的
   正确调用方式已在本轮记录（脚本内部默认端口 51015，必须用环境变量
   `PANGO_JTAG_PORT` 覆盖，命令行 `-port` 不起作用）。
