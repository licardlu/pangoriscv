# 入库范围与体积

仓库只收**作品代码 + 设计文档 + 验证证据 + 发布位流**，全部约 9 MB。所有可再生成的产物都不入库。

## 入库内容

| 路径 | 文件数 | 体积 | 说明 |
|---|---:|---:|---|
| `firmware/code/` | 144 | 0.71 MB | 全部作品代码（RTL / TB / sim / tools / platform / tests / 说明 / LICENSE） |
| `evidence/logs/` | 775 | 1.30 MB | 仿真运行日志（按用例归档，60 个用例目录） |
| `evidence/records/` | 89 | 1.46 MB | 上板记录、时序报告、ISA 合规日志、基线证据、赛题摘页 |
| `docs/contest/` | 6 | 0.94 MB | 赛题原文与要求摘录（少量 PDF/PNG） |
| `docs/design/` | 8 | 0.26 MB | 计划书、优化文献综述、变更记录 |
| `docs/verification/` | 4 | 0.04 MB | 验证说明与状态 |
| `docs/repo/` | 3 | — | 本文件、协作约定、历史项目索引 |
| `bitstream/` | 2 | 3.8 MB | 发布版位流 + 说明（GitHub 单文件限制 100 MB，远低于上限） |
| `scripts/` | 3 | — | 仓库级辅助脚本 |

## 不入库的内容与原因

| 路径 | 体积 | 原因 | 替代方式 |
|---|---:|---|---|
| 本地验证归档 `09_validation_results/` | 458 MB | 逐轮位流、ModelSim 库、仿真日志；可再生成，且每次重跑都新增几百 MB | 本地保留；结论已摘要进 `docs/verification/` 与 `docs/design/`。要整包共享用网盘或 Git LFS |
| 历史工作树 `pangoriscv_axi4/` | 494 MB | 同一套代码的**工作树**（含 1.2 万文件的仿真/综合产物） | 本地保留。**里面的 RTL/TB 与 `firmware/code/` 只差注释，不要两处各改一份** |
| `adv_sram_build/`、`led_sram_build/` | 184 MB | PDS 构建输出（连接、位流、报告） | 可重新综合得到，见 `firmware/code/platform/pango_native/README.md` |
| `02_original_backups/` | 78 MB | 各阶段修改前的完整备份 | 本地保留；需要时打压缩包放网盘 |
| `10_codex_chats/` | 69 MB | 与 AI 协作的会话存档 | 本地保留，与作品无关 |
| `07_board_references/` | 49 MB | 开发板厂商手册与例程（第三方资料，体积大） | 本地保留；只把**结论**写进 `firmware/code/platform/pango_native/README.md` 与 `evidence/records/` |

`.gitignore` 用「任意层级」规则排除上述目录，所以本地不管是挪到哪一层，都不会被误提交。

## 改代码只改一处

1. **只改 `firmware/code/`**——这是唯一入库的那份，也是位流对应的源码；
2. 历史工作树可以本地留着跑整机流程，但**不要在里面改完就忘了同步回来**；
3. 交付位流的 sha256 与 RTL 的对应关系记在 `bitstream/README.md`。

## 真要共享大文件

- 只要结论：把关键报告摘要进 `docs/`，大件留在本地；
- 要给人看全部：把本地验证归档打成压缩包放网盘，把链接写进 `docs/verification/`；
- 非要用 git 传：`git lfs track "*.sbit"` 之后单文件走 LFS，注意 GitHub 的 LFS 配额。
