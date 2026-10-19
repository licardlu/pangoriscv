# P21 · I-Cache 扩到 8 KB（128 组）——板上实测 2.8833（有效，10.687 s）

> ## ✅ 成绩有效性
> 板上串口直读：`Iterations 832`、`Total ticks 288558769`、`Total time (secs): 10`、
> `Correct operation validated`。**满足赛题 ≥10 s 硬性规则。**
> 位流带固件镜像（综合日志 `Board check: 2 memory images loaded into the design`）。

---

## 1. 做了什么

I-Cache 从 **64 组（4 KB）→ 128 组（8 KB）**，仍然只改组数、不动行宽。
迁移点与上一轮相同（tag 20 位、set 7 位、`hit_index`/`rd_index_q` 11 位、`set_q` 7 位）。

## 2. 迭代数必须跟着改（这一轮踩了一次）

第一次用 **768 迭代**的镜像出位流，板上结果：

```
Total ticks      : 266363415
Total time (secs): 9
ERROR! Must execute for at least 10 secs for a valid result!
Errors detected
```

性能变快后 768 次只要 **9.865 s < 10 s** → **成绩作废**。
按 `N ≥ ceil(10.5 × 27e6 / 每迭代 ticks)` 重算：每迭代 346,827 ticks →
`ceil(283,500,000 / 346,827) = 818` → 取 **832**（10.687 s）。

> **规矩：每提升一次性能，必须重算迭代数并重新出镜像；否则成绩会被判无效。**

## 3. 跑分（832 迭代，板上实测）

| 项 | P18（起点） | P19 | P20（4 KB） | **P21（8 KB）** |
|---|---|---|---|---|
| 迭代数 | 768 | 768 | 768 | **832** |
| ticks | 284,997,892 | 280,487,382 | 273,172,370 | **288,558,769** |
| 用时 | 10.555 s | 10.388 s | 10.117 s | **10.687 s** ✓ |
| **CoreMark/MHz** | 2.6948 | 2.7381 | 2.8115 | **2.8833** |
| 五项 CRC | e9f5/e714/1fd7/8e3a/**3c53** | 相同 | 相同 | e9f5/e714/1fd7/8e3a/**f745** |

> `crcfinal` 会随迭代数变化（它累积了迭代次数的状态），这是正常的；
> 判定仍是 `Correct operation validated`，且 `seedcrc/crclist/crcmatrix/crcstate` 四项不变。

相对起点 **+7.0%**。

## 4. 实现（PDS 27 MHz，seed 41）

| 项 | P18 | P19 | P20 | **P21** |
|---|---|---|---|---|
| All Constraints Met | ✅ | ✅ | ✅ | ✅ |
| Setup(Slow) | +15.201 | +15.289 | +15.398 | **+11.109** |
| Hold(Slow) | +0.024 | +0.097 | +0.030 | **+0.061** |
| Hold(Fast) | +0.011 | +0.066 | +0.018 | **+0.047** |
| 失败端点 | 0 | 0 | 0 | **0** |
| LUT | 13,503 | 13,555 | 14,622 | **16,782** |
| FF | 8,507 | 8,508 | 9,885 | 12,509 |
| **CoreMark/kLUT** | 0.1994 | 0.2020 | 0.1923 | **0.1718** |
| 位流 | — | — | — | 3,791,112 B，SHA256 `1FAC6F435BA34641BB8D16285CFFFA7811D2F787AEAF08805B4F5369A2B41F23` |

## 5. 三项指标（并列，必须如实报告）

| 指标 | P18 | **P21** | 变化 |
|---|---|---|---|
| ① CoreMark/MHz | 2.6948 | **2.8833** | **+7.0%** |
| ② 时序 | +0.024 / +0.011 | +0.061 / +0.047 | 全过，余量变大 |
| ③ CoreMark/kLUT | 0.1994 | **0.1718** | **−13.8%** |

**用 3,279 个 LUT 换 7.0% 的性能。** 若更看重 ③，应回退到 P19（2.7381 / 0.2020）。

## 6. 已知债务

`tb/unit/tb_icache_axi.sv` 的 T4（两路冲突）用例地址是按 32/64 组选的，
128 组下同组步长变成 0x1000 就不再同组，**该用例在 8 KB 几何下报
`T4 B miss again burst count 0 expected 1`**。
功能性判据（ISA 15/15、halt-reset 5/5、RAM 20/20、CoreMark CRC）全部通过，
但这个单元测试需要把地址映射改成跟随 `dut.SETS`。**记为待修。**

## 7. 证据文件

| 文件 | 内容 |
|---|---|
| `board_uart_score.txt` | 板测原始串口 691 B |
| `board_program_tcl.log` | `cfg_program succeed, 3.8` |
| `firmware_manifest.json` | 832 迭代镜像的清单（`iterations: 832`） |
| `pds_27mhz_full/` | 位流 + `multiseed_summary.csv` + `report_timing.rtr` + 各阶段 log |
