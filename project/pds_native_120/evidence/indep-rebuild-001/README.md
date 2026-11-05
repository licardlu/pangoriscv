# 独立重建复现记录（2026-11-04）

## 做了什么

把 `project/pds_native_120` **整目录复制到仓库外面**（`%TEMP%/indep_cpu/pds_native_120`，删掉其中的 `evidence/`），然后只跑：

```
python tools/build.py build --name indep-001 --pds <PDS>/bin/pds_shell.exe
```

目的不是造交付位流，是回答一个问题：**评委只有这个目录时，能不能真的重建出一份位流。**
构建过程没有读仓库里任何其它目录（`build.py` 会把 `sources.f` 里的 43 个文件复制进构建目录，路径全部相对本目录）。

## 结果

| 项 | 独立重建 indep-001 | 交付 standalone-001 | 参考基线 |
| --- | --- | --- | --- |
| 状态 | `build_complete`，20 分 52 秒 | `build_complete`，15 分 13 秒 | — |
| ROM 加载 | 8/8 路 | 8/8 路 | 8/8 路 |
| LUT | **8867** | 8875 | 8841 |
| FF | 6658 | 6658 | 6658 |
| DRM / APM / Dist RAM | 34 / 5 / 72 | 34 / 5 / 72 | 34 / 5 / 72 |
| Setup(Slow) | **−1.532 ns** | −1.426 ns | −1.604 ns |
| 失败端点 | 1171 | 619 | 829 |
| Design Summary | Some Constraints Violated | 同 | 同 |
| 位流 SHA256 | `f544b61e…3b61d` | `2e38db1c…1f9cb` | — |

## 怎么读这张表

- **资源复现**：FF/DRM/APM/Dist RAM 逐位相同，LUT 差 8（0.09%）。说明 43 个源文件进去，造出来的是同一个设计。
- **时序不逐位复现，是正常的**：同一份网表两次布局布线，setup 在 −1.43 ~ −1.53 ns 之间摆动，失败端点数从 619 到 1171。这个规模的设计每跑一次就是一次抽样，**不能拿单次 WNS 判设计优劣**，要看拍数这种不受摆放影响的量。
- **位流字节不同**：布局布线带随机种子，两份位流本来就不会一样。所以"重建出来的位流 SHA 对不上交付件"不是问题，"8 路镜像加载数"和"资源数"才是该对的东西。
- **120 MHz 仍然不收敛**：两次都一样。这是设计的真实状态，不是这一轮引入的。

## 没有做的事

这份重建出来的位流**没有上板**，`result.json` 里 `board_verified: false`。上板数据用的是 `evidence/standalone-board-001/` 和 `-002/` 那两次。

## 文件

| 文件 | 内容 |
| --- | --- |
| `result.json` | 本次构建的资源、时序、位流 SHA、与交付版的差值 |
| `multiseed_summary.csv` | PDS 自己写的单种子汇总（放置/布线时间、DRC、资源） |
| `image_verification.json` | 构建时对 8 路 lane 的复核结果 |
