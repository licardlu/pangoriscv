# 协作说明

两个人共用 `main`，两人都有推送权限。分支/PR 是可选项，但下面几条请保持，否则很容易互相覆盖。

## 1. 每次开始改之前

```powershell
git pull --rebase        # 先拿到同学的改动，再动手
```

**不要**在没 pull 的情况下长时间连续提交后一次性推送——冲突会集中在最后一起爆发。

## 2. 提交前后

```powershell
git status               # 确认没有把 work/ transcript / *.wlf / build/ 之类带进来
git add -A
git commit -m "文档: 补充 CoreMark 复验数据"
git pull --rebase        # 再拿一次最新
git push
```

## 3. 提交信息格式

`<范围>: <做了什么>`，一行说清目的，需要时下面空一行写原因。

| 范围 | 含义 |
|---|---|
| `rtl` | RTL 与测试台 |
| `sim` | 仿真脚本与清单 |
| `tools` | 固件构建/回归脚本 |
| `platform` | PDS 流程与约束 |
| `docs` | 03_plans / 04_change_notes / 05_verification / 08_contest |
| `evidence` | 06_evidence |
| `repo` | .gitignore、README、脚本等仓库设施 |

例子：

```
rtl: I-Cache 命中路径改单拍返回
docs: 计划书补写 T1+T3 复验结论
repo: 忽略 .sim_runs 与 *.wlf
```

## 4. 同一份文件怎么避免打架

- **改之前先看一眼最近谁动过**：`git log --oneline -5 -- <文件>`；
- **大段改写前先在群里说一声**，把文件“认领”下来，改完立刻推；
- 真冲突了：**不要暴力覆盖对方的版本**，用 `git diff` 看清楚两边改了什么再合并；
- 二进制/日志类证据（`06_evidence/`）**只追加，不原地重写**同名文件——重跑一次就换个带日期的文件名，这样永远不会冲突。

## 5. 不要提交的东西

`work/`、`transcript`、`*.wlf`、`*.vstf`、`build/`、`compile/`、`.sim_runs/`、`__pycache__/`、位流
（`*.sbit`、`*.bit`）、以及 `09_validation_results/` 与 `02_original_backups/`。

`.gitignore` 已经覆盖这些；`git status` 里如果还看到它们，说明规则需要补，直接在 `repo:` 范围的提交里补。

## 6. 大文件怎么办

单个文件超过 ~20 MB 时不要直接 `git add`：先问一句，走 Git LFS
（`git lfs track "*.pdf"`）或把它放进网盘、在文档里写链接。

## 7. 权限

仓库是私有的。同学需要在 GitHub 网页上被邀请：
**Settings → Collaborators → Add people**，输入对方的 GitHub 用户名（或在仓库页 **Settings → Manage access**）。
邀请发出后，对方在自己的 GitHub 通知里**接受**才能推送。
