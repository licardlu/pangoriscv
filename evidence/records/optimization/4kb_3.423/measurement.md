# 4KB I-Cache + 双发射（最小 lane1）—— 板上实测 CoreMark/MHz **3.4194**

> 测量日期：2026-10-20 22:54（`cfg_program succeed` 22:54:22）
> 这是**第一次**拿到这个配置的有效板上数据。本目录里那些 2 字节文件是
> 抓取窗口错位的产物，**不是"跑不起来"**（见 `README.md`）。

## 1. 板上原始结果

`uart_4kb_recheck.txt`（693 B，位流见 §3）：

```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 299467030
Total time (secs): 11
Iterations/Sec   : 93
Iterations       : 1024
Compiler version : GCC15.2.0
Compiler flags   : -march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -freestanding ...
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x9ce8
Correct operation validated. See readme.txt for run and reporting rules.
```

## 2. 换算（只用 `Total ticks`，不用截断的 `Iterations/Sec`）

| 项 | 计算 | 值 |
|---|---|---|
| 运行时间 | 299,467,030 / 27e6 | **11.091 s** ≥ 10 s ✔ |
| 每迭代 ticks | 299,467,030 / 1024 | 292,448 |
| **CoreMark/MHz** | 1024 / 299,467,030 × 1e6 | **3.4194** |
| 五项 CRC | `e9f5 / e714 / 1fd7 / 8e3a / 9ce8` | 全对 ✔ |

`crcfinal` 随迭代数变化属正常（它累积了迭代次数），判定用 `Correct operation validated`
且前四项 CRC 与种子不变。

与交付版 P21 对比（同一块板、同一个串口、同一天）：

| 版本 | 迭代 | ticks | 用时 | CoreMark/MHz |
|---|---:|---:|---:|---:|
| P21（8KB 单发射，交付） | 832 | 288,558,769 | 10.687 s | 2.8833 |
| **4KB + 双发射（本目录）** | 1024 | 299,467,030 | 11.091 s | **3.4194（+18.6%）** |

## 3. 这份位流与实现

| 项 | 值 |
|---|---|
| 位流 | `firmware/code/build/code_ic4k/build/pango_native/generate_bitstream/pangoriscv_top.sbit` |
| SHA256 | `8D12C9D114C0DBE4455E0A50C0F944B7D8506273DB28ADAEBC3755205FA6A643` |
| 字节数 | 3,791,112 |
| 配置 | `CACHE_ENABLE`/`PREDICT_ENABLE`/`PERF_ENABLE` 全开，I-Cache 64 组（4 KB），双发射最小 lane1 |
| 资源（device_map） | **21,949 LUT / 14,104 FF**（DRM 4 / APM 6） |
| 镜像 | `program.hex` `F67A0299…F42C4`（**1024 迭代**）、`data.hex` `5D5F267A…CA9A0` |
| 镜像已装入位流 | ✔ 综合日志两条 `Loading memory data from file …/program.hex|data.hex`（`synthesize_run.log`） |

时序（`multiseed_summary.csv` 的 `single` 行，`All Constraints Met`）：

```
single,OK,OK,14.750,22.341,0.015,0.002,…   ← Convergence=OK，Hold(Slow)=+0.015，Hold(Fast)=+0.002
失败端点: setup 0 / hold 0
```

## 4. 风险与结论

- **结论**：3.423 这一版在**真实板卡上成立**：11.091 s、五项 CRC 全对、3.4194 CoreMark/MHz，
  比交付的 2.8833 高 **18.6%**。
- **风险（交付前必须正视）**：hold 只有 **+0.015 / +0.002 ns**（P21 是 +0.061 / +0.047），
  属于"刚好过"的量级；换种子或换温度都可能翻负。要正式交付，建议：
  1. 固定这份位流并记录 SHA（已记录），不要再重跑同一构建目录覆盖；
  2. 若还要重跑，先看 `multiseed_summary.csv` 的 hold 是否仍为正，否则换种子；
  3. 赛题 ② 的"report_timing 无失败端点"这一条本版满足，但余量要在文档里如实写。
- **待补证据**：ILA 波形（赛题文档评分项）仍未抓；适用性/应用场景章节未写。
- **口径提醒**：分数只能由 `Total ticks` 算；`Iterations/Sec` 是整数截断（这里显示 93，
  真值 1024/11.091 = 92.3）。
