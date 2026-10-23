# P48b —— lane0-load → lane1 旁路（2026-10-23）

**一句话**：`pair_ok` 里那条 `!packet_load_use` 拿掉了，lane1 直接从 `load_value` 取数。
零面积、零 CPI 代价，分数 **5.2484 → 5.2850**。顺带修掉一个"中断注入边界只看 lane0"的潜伏 bug。

---

## A/B（同一镜像 `sim20_O2`，20 迭代）

| | 改前 `91d5282` | **改后 `fe8da00`** |
|---|---|---|
| `Total ticks` | 3,810,700 | **3,784,335** |
| 每迭代拍数 | 190,535 | **189,217** |
| CoreMark/MHz | 5.2484 | **5.2850** |
| `crclist/crcmatrix/crcstate/crcfinal` | 0xe714 / 0x1fd7 / 0x8e3a / 0x4983 | 同左（全对）|
| `pair` / `single` / `refused_pair` | 2,522,973 / 256,673 / 519,818 | 2,544,769 / 255,406 / 473,284 |
| 其中 `lduse` | 160,575 | 119,467 |
| ISA e2e | 20/21 | **20/21** |
| halt/reset 5 场景 | —— | **5/5 PASS** |
| 面积（`p48r50` device_map）| LUT 17,105 / FF 8,693 / LUTRAM 2,274 | LUT **17,103** / FF 8,693 / LUTRAM 2,274 |

## 实现要点（为什么不是组合环）

```
成立不了的写法：fwd1_h := lane0_ld_raw1 ? load_value : fwd1_h
   ⇒ address → op_ready/hit → mem_rsp → fwd1_h → mem_addr_h → address  （环！）
实际写法：另开一份只喂 lane1 ALU/乘法器的副本
   fwd1_h_alu = lane0_ld_raw1 ? load_value : fwd1_h      // alu_a_h / alu_b_h / u_mul_h
   mem_addr_h 仍用 fwd1_h                                 // 地址通路不碰
行为等价：lane1 只有在 lane0 不是访存时才能是访存（pair_ok 的 !(lane0_mem && lane1_mem)），
而这条旁路只在 lane0 是 load 时激活 ⇒ 地址通路在意的那一侧永远 fwd1_h_alu == fwd1_h。
```

miss 时 `mem_rsp` 为 0，`mem_wait` 冻结 RD+EX，什么都不会被采到；misaligned trap 时不发请求，
lane1 由 WB 的"只提交更老的那一半"丢弃。

## 为什么只值 1,318 拍/迭代（桶里写着 8,029）

前端供给只有 **1.65 条/拍**（`(pair×2+single+refused×2)/窗口`）。配对机会变多时，
瓶颈立刻转到"没指令可发"，省下的拍被 starve 吃掉。详见 `docs/lessons/mistakes-log.md` §77。

## 顺带修掉的潜伏 bug

`irq_trap` 用 `w_ctrl`（lane 0）做中断注入边界。放宽配对后 `lw;beq` 成对、`beq` 落到 lane1，
中断边界永远等不到 ⇒ ISA case 15（定时器中断）从 PASS 变 FAIL。
判据改为 `w_ctrl_any = w_ctrl || (w_v1 && w_ctrl_h)`。详见 §78。
