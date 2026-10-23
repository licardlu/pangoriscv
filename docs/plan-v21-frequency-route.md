# v21 —— 切② 成功（第三种做法）+ 切⑥ 综合不可用 + 55 MHz 收官（2026-10-24）

工作分支 `exp/split`（从交付 `exp/pair45` 拉出，**不叠加 S1+S2**）。
本文档只记录**有实测支撑**的结论。

---

## 0. 本轮成绩单

| 项 | 结果 | 证据 |
|---|---|---|
| 切② CSR 读口解耦（第三次做法）| **成功，零 CPI**：ticks 3,810,700 逐位不变 / CRC 0x4983 / ISA 20/21 | `.sim_runs/coremark_sim/p50_c2b`、`isa-e2e-*` |
| 切⑥ D\$ 阵列写口打拍 | **功能全对（同上三项），但 PDS 综合吃不下**（tech-mapping 40 min 不结束）| 见 `docs/patches/cut6-deferred-dcache-write.patch` |
| 面积 | LUT **17,174 → 17,021**（−153）、FF **8,693 → 8,597**（−96）| `build/p50syn_c2only` |
| 120 MHz | **实测不可达**：120 MHz 约束下摆放仍差 **−5.77 ns**（路径 14.07 ns）| `build/po120_c2` |
| 交付目标 | 改押 **55 MHz**（PLL 27×55/27，VCO 1485；镜像 2900 迭代 = 10.05 s）| `build/p50r55` |

---

## 1. 切②：为什么前两次失败、第三次怎么成

### 1.1 前两次失败的机制（lesson 88 只记了现象，这里补机制）

`serial_q` 的置位条件是 `id_accept && id_serial`，而 `id_serial` 是**已经在 ID 里**那条
指令的标志 ⇒ 紧随串行指令之后的那条会**在屏障升起前漏进 ID 一拍**。
于是相邻两条 CSR 指令只隔 1 拍，后一条正好在**前一条提交的同一拍**进 M2。

而 CSR 的写在 WB 的**边沿**才落地 ⇒ 任何"读提前到 M2"的做法都差半拍。
更硬的一条：`csr_new = w_csr_old | w_csr_src` 既是写回 CSR 的新值、也决定 `rd`，
**两者必须是同一个采样** —— 所以"读改早、写回另取来源"也不行。

探针实证（`--cases 6`，6 秒）：

```
CSRN commit=1 addr=340 wd=ffffffff mscr=00000000 nsc=ffffffff   <- csrrw 写 mscratch
CSRN commit=1 addr=340 wd=00000000 mscr=ffffffff nsc=00000000   <- csrrs 读到旧值 0，又写回去
```

`csrrs rd,csr,x0` 语义上不写，但 `commit` 只看 `w_commit && w_csr` ⇒ 把 0 写了回去。

### 1.2 第三版的三处改动（缺一不可）

1. `csr_native` 拆**三个**地址端口：`addr`（提交写）、`raddr`（取值，接 **M2**）、
   `iaddr`（合法性判断，接 ID）。读的 12 路 mux 从此只喂一个寄存器。
2. `wb_value = w_csr ? w_csr_old : w_value` 且 `w_csr_old <= csr_rdata`（M2 采）。
   `w_valid` 与 12 路 CSR mux 从 RF 写口前面彻底消失。
3. `serial_q` **早一拍置位**：`id_accept && (dec_serial || id_serial)`。
   相邻 CSR 指令正好隔开 1 拍，M2 取值落在前一条提交之后的周期。

第 3 条是承重的：只做 1+2 就是 v19 的第二次失败（ISA 19/21）。

### 1.3 判据

```
Total ticks : 3,810,700   （逐位不变）
五项 CRC    : 0x4983 / 0xe714 / 0x1fd7 / 0x8e3a
ISA e2e     : 20/21       （case 6 CSR read/write、case 7 mcycle 全过；只剩基线红的 case 21）
```

---

## 2. 切⑥：功能正确，但工具链吃不下

实现（`docs/patches/cut6-deferred-dcache-write.patch`）：store 命中的阵列写改成
`sw_we_q/sw_idx_q/sw_data_q/sw_strb_q` 寄存器输出、下一拍落地；读侧加
`sw_idx_q == rd_didx` 的 10 位比较 + 字节 mux 做 store→load 转发。
被删掉的是 `N4033[0]`（fanout=256，单根网线 **2.58 ns**，原路径尾部）。

验证：ticks 3,810,700 / CRC 0x4983 / ISA 20/21 —— **全对**。

**但它让 PDS 的 `tech-mapping phase 2` 从 2~3 分钟变成 40+ 分钟不结束**
（CPU 97%、内存 3.0→3.2 GB 持续涨、无任何报错）。去掉该改动后 2m52s 完成，
五次复现一致；给四个阵列加 `(* syn_ramstyle = "distributed" *)` 也无效（另一次 9 min 仍不结束）。

⇒ **不进交付树**，补丁封存。这是"功能正确 ≠ 能交付"的第三种形态
（前两种：分数不够 lesson 85、ISA 挂 lesson 88）。

---

## 3. 120 MHz：本轮用硬数据关死

| 约束 | 摆放后最差路径 | 摆放 slack | 说明 |
|---|---|---|---|
| 8.301 ns（120 MHz）| **14.07 ns** | **−5.77 ns** | 摆放器已经尽力（比 60 MHz 那次还紧 1.4 ns）|
| 16.667 ns（60 MHz）| 15.50 ns | +1.165 ns | 摆放器放松了努力 |
| 20.000 ns（50 MHz，交付）| 18.32 ns | +1.683 ns | 布线后 19.355 ns（+0.645）|

**结论**：切② 之后这条网表的"摆放地板"约 **14 ns**（≈70 MHz）。到 120 MHz 还差 5.8 ns，
需要**两级流水**（每级 ≥4,945 拍的重定向代价），而 5.2 分只剩 1,772 拍余量。
⇒ **5.2 分与 120 MHz 在"2 发射 + 现微架构"下不可同时成立**，本轮有摆放实测支撑。

### 3.1 剩下唯一还有价值的零拍候选（留给下一轮）

`alu_y → fwd1_h → lane1 地址加法器`（③+④ ≈ 5 ns）。它只因为**同包内 RAW 且 lane1 是访存**
才存在，而 ISA 17/18 正是覆盖它的用例 ⇒ 不能靠"禁止配对"消除。
可行方向：lane 0 的 ALU 若为 `add/addi/sub`，lane 1 的地址写成
`alu_a + alu_b + imm_h`（三输入 CSA + 一条进位链），**绕过 ALU→mux 两级**，
理论省 3~4 ns 且不花一拍。属结构性改动，需单独立项。

---

## 4. 交付目标：55 MHz（为什么不是 60）

布线在摆放之上还要 1.0~2.4 ns（交付那次 1.04 ns；51 MHz 那次 2.4 ns）。

- 60 MHz：摆放 +1.165 → 布线后 −0.6 ~ +0.2 ns，**五五开**。
- 55 MHz（18.18 ns）：按 0.85×周期 的摆设规律，摆放 slack 约 +2.0~2.7 ns
  → 布线后 +0.3 ~ +1.3 ns，**有真实余量**。

只跑得起一次满流程（合成 2 min + 摆放 3 min + 布线 **5~6 h**），所以取 55 MHz。
镜像 `hw_i2900_55`：2900 迭代 × 190,535 拍 ÷ 55 MHz = **10.05 s**（满足 ≥10 s）。

---

## 5. 上板

- JtagServer：`cdt_js.exe -port 65420 -work_dir <dir>`；扫描要用
  `PANGO_JTAG_PORT=65420` 覆盖脚本里的默认 51015（lesson 91）。
- 本轮实测：`JtagServer-0306: No devices detected`（板子未上电 / 排线未接），
  与前三次一致。**位流一出就再试，硬件事不可为的部分如实记录。**
