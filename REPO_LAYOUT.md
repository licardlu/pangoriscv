# 仓库布局与「不入库」清单

本仓库只收**代码 + 文档 + 证据文本**，约 1,030 文件 / 4.8 MB。下面说明哪些东西故意没进来、放在哪、需要时怎么拿回来。

## 入库

| 路径 | 文件数 | 体积 | 说明 |
|---|---|---|---|
| `01_code/pangoriscv_own/` | 144 | 0.71 MB | 全部作品代码（RTL / TB / sim / tools / platform / tests） |
| `06_evidence/` | 866 | 2.89 MB | 验证证据：日志、上板记录、赛题页（少量 PDF/PNG） |
| `08_contest/` | 6 | 0.94 MB | 赛题原文与要求摘录 |
| `03_plans/` | 2 | 0.20 MB | 计划书、优化文献综述 |
| `04_change_notes/` | 6 | 0.06 MB | 变更记录 |
| `05_verification/` | 4 | 0.04 MB | 验证说明与状态 |
| 根目录 | 4 | — | `README.md`、`CONTRIBUTING.md`、`REPO_LAYOUT.md`、`.gitignore` |

## 不入库（`.gitignore` 已排除）

| 路径 | 体积 | 为什么不入库 | 需要时怎么拿 |
|---|---|---|---|
| `09_validation_results/` | 458 MB | 位流（`*.sbit` 3.8 MB/份）、ModelSim 库、逐轮仿真日志；可再生成，且每次跑都会新增几百 MB | 本地保留；重要结论已摘要进 `05_verification/` 与 `03_plans/`。要共享整包用网盘，或对该目录单独走 Git LFS |
| `01_code/pangoriscv_axi4/` | 494 MB | 同一套代码的**工作树**（含 1.2 万文件的仿真/综合产物）。作品源码已清理并收进 `pangoriscv_own/` | 本地保留。**里面的 RTL/TB 与 `pangoriscv_own/` 内容一致（只差注释）**，不要两处各改一份 |
| `01_code/adv_sram_build/`、`01_code/led_sram_build/` | 184 MB | PDS 构建输出（连接、位流、报告） | 可重新综合得到，见 `platform/pango_native/README.md` |
| `02_original_backups/` | 78 MB | 改造前的历史快照，只作溯源 | 只在追溯“某个文件原来长什么样”时用，不进仓库 |
| `10_codex_chats/` | 69 MB | 会话记录导出，与作品无关 | 本地保留 |
| `07_board_references/` | 49 MB | 开发板厂商手册与例程（第三方资料，且体积大） | 本地保留；只把**结论**写进 `platform/pango_native/README.md` 与 `06_evidence/` |
| `log/`、`logbackup/` | 0.4 MB | 运行日志 | — |

## 两个目录别改重影

改 RTL/测试台时：

1. **只改 `01_code/pangoriscv_own/`**（这是作品源码，也是唯一入库的那份）；
2. 如果还要用 `01_code/pangoriscv_axi4/` 跑整机流程（它带着 `build/`、`compile/` 与全部历史位流），
   从包内同步过去，**不要反向手改**；两边不一致时以包内为准；
3. 交付位流的 sha256 与 RTL 的对应关系记录在 `05_verification/` 与
   `09_validation_results/advanced_cpu/REPORT_stageE.md`（本地归档）§6.7。

## 需要更大容量时

- 想连归档一起版本化：`git lfs install` → `git lfs track "*.sbit" "*.pdf"` → 再加 `09_validation_results/`，
  注意 GitHub 免费额度（1 GB 存储 / 1 GB 月流量）；
- 只想共享给人看：把 `09_validation_results/` 打成压缩包，放到网盘，把链接写进 `05_verification/`。
