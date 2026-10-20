# area-M1：交付构建关闭 `PERF_ENABLE` —— 实测 LUT −1,527 / FF −1,769

日期：2026-10-21
阶段：`module-area-plan.md` 的 **M1**（仪表去化）
性质：**构建 profile 变更**（不改 RTL 功能），交付位流不再包含性能计数器

---

## 1. 做了什么

| 项 | 内容 |
|---|---|
| 手段 | `tools/set_switches.py PERF_ENABLE=off`（新增的按名开关，只动这一个宏） |
| 影响面 | `perf_regs` + 它的 AXI 寄存器从机 + `pangoriscv_axi_top` 的 `perf_*` 端口 + SoC 从机 8→7 |
| 不动 | `CACHE_ENABLE` / `PREDICT_ENABLE` 保持 ON（教训 §4.10：缓存开关不同 = 不同设计，不能混比） |
| 测量方式 | `tools/run_area_check.ps1`：`compile → synthesize -ads → dev_map`，**不做 P&R**（约 4 分钟） |

## 2. 为什么这个测量可信（控制组）

先在同一 RTL、同一镜像（`score1024`）、同一流程下跑**控制组**（PERF on）：

```
LUT 21,949 | FF 14,104 | LUTRAM 3,628 | DRM 4 | APM 6
```

与冻结基线（tag `score-3.4194-1024`，`device_map` 真值）**逐项完全一致** →
说明 `resource_check`（综合+映射）可以作为面积 A/B 的可靠代理，省去每次 25 分钟的 P&R。

## 3. 结果

| 指标 | 控制组（PERF on） | M1（PERF off） | Δ |
|---|---:|---:|---:|
| LUT | 21,949 | **20,422** | **−1,527（−6.96%）** |
| FF | 14,104 | **12,335** | **−1,769（−12.54%）** |
| LUTRAM | 3,628 | 3,628 | 0 |
| DRM | 4 | 4 | 0 |
| APM | 6 | 6 | 0 |
| **站点 S = LUT+FF+LUTRAM** | **39,681** | **36,385** | **−3,296（−8.30%）** |

对照预算：M1 原估 LUT −1,000~1,444 / FF −1,665，**实测两项都优于上界**。

## 4. 门禁输出（`check_area_budget.py --mode delta`）

```
metric     previous     actual      delta
LUT          21,949     20,422      -1527
FF           14,104     12,335      -1769
LUTRAM        3,628      3,628         +0
DRM               4          4         +0
APM               6          6         +0
S            39,681     36,385      -3296
PASS
```

反向自检（把 on 当实际、off 当参考）会报
`FAIL: lut increased by 1527` / `ff increased by 1769` / `S increased by 3296` ——
证明门禁不是"永远绿"。

## 5. 记忆镜像与证据链

| 项 | 值 |
|---|---|
| 镜像目录 | `build/native_software/coremark/performance/score1024`（`program.hex` `F67A0299…`） |
| 镜像装载 | `compile/run.log` 有 **2** 条 `Loading memory data from file`（工具已复核） |
| 控制组构建目录 | `firmware/code/build/area_m1_on` |
| M1 构建目录 | `firmware/code/build/area_m1_off` |
| 本目录证据 | 两组 `device_map/run.log`、两组 `apm_drm_lutram_utilization.log`、两组利用率纯文本表 |

## 6. 交付口径（必须写进交付说明）

交付位流用 **PERF off** 构建；分析/波形用的构建保持 PERF on。
开关状态必须写进证据目录，且**仓库默认仍是三开**（`soc_config.vh` 不改死）。

## 7. 未做（下一步）

- M2 数据 RAM → BRAM（LUTRAM −2,048）：本阶段最大一块；
- M3 BTB 缩位宽（FF −1,152）、M4b/M4a 取指队列（FF −1,832）；
- M5/M6 缓存副本归属分析；
- 定版：`place_route` + 双种子收敛 + 上板复验（M1 只改 profile，功能应无变化，但定版时必须重抓 CRC）。
