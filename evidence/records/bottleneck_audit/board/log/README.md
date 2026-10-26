# JTAG 烧写/扫描原始日志（2026-10-20 13:55 → 2026-10-24 14:07）

这四个文件是 **Pango 工具链自己写的日志**，不是我们整理的摘要，因此可以作为
"上板到底能不能通" 的第一手证据。

| 文件 | 是什么 |
|---|---|
| `configuration.log` | `cdt_cfg.exe` 的完整调试日志（连接、枚举电缆、扫描链、读器件属性、烧写）|
| `jtagserver.log` | `cdt_js.exe`（JtagServer）侧的日志 |
| `cfg.log` | 单次配置会话的概要日志（`M_PROCESS_FINISH_STARTED` … `cfg_disconnect succeed`）|
| `js.log` | JtagServer 启动日志 |

## 这份日志能证明什么

统计（`grep -c`，覆盖上述时间跨度）：

| 关键字 | 次数 | 含义 |
|---|---:|---|
| `USB Cable II` | **70** | 下载线被 JtagServer **枚举到**（这条是我们需要的那根线）|
| `PG2L100H` | **59** | 扫描链上**识别到器件**（PG2L100H，正是本设计的器件）|
| `No devices detected` | **16** | 失败的会话（线没插 / 板子没电）|

关键事实两条：

1. **成功的形态长什么样**（2026-10-18 23:47 那次，见工作区 `log/configuration.log`）：
   ```
   Cable index 0:USB Cable II/fffffffffffffffe
   Log::Print : PG2L100H
   COMMAND[Get device id] execute successfully, takes 0.7 secs.
   ```
   即：`cfg_connect` → `cfg_scan_chain` 返回 `PG2L100H` → `cfg_read_device_property` 成功。

2. **失败的形态长什么样**（最近几次）：
   ```
   E: JtagServer-0306: No devices detected while scanning the JTAG chain
   The cable List :            <- 空
   ```
   `The cable List` 为空 ⇒ **连下载线都没有被枚举**，不是"板子没响应"。
   排查顺序见 `../cable-status-2026-10-24.md`。

## 为什么它此前不在仓库里（已修复）

`.gitignore` 里有一条 `log/`，本意是排除工作区根的 `log/` 目录，
但它会匹配**任意层级**叫 `log` 的目录，于是把这个证据目录也一起排除了。
2026-10-26 已把它改成 `/log/`（锚定根目录），本目录随之入库。

> 教训：`.gitignore` 里凡是**不带前导 `/` 的目录规则**，都会在所有层级生效。
> 想让规则只作用于根目录，必须写成 `/name/`。
