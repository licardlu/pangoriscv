# 改进版1：盘古100Pro+板卡资料优化版（2026-11-01）

依据用户提供的 MES2L676-100HP 配套资料核对引脚、IO 电压和 PPLL，加入可自动运行的板卡参数检查，并对 GShare 预测器做独立优化和完整 PDS 实现。CPU 仍为 VexiiRiscv 派生，固定上游提交 `f040ac2bdb7ab129b42b414bd6b78779b84640bb`，来源与许可证完整保留。

**本包是正裕量实验候选，未证明新位流长期稳定或达到5.6分。** 实际改动、全部对照及限制见 [板卡优化说明](docs/board-optimization-20261101.md)。

| 项目 | 本次结果 |
|---|---|
| 当前候选 | board021_gshare10_route20，bitstream/current/pango_vexii_top.sbit |
| 实际 PLL 配置 | 27×58/13 = 120.461538 MHz |
| 最终 setup / 最小 hold | +0.148 ns / +0.028 ns，Slow/Fast十项正裕量，失败端点0 |
| LUT / FF / LUTRAM | 9016 / 6799 / 72；DRM34、APM5 |
| 面积合计 | 15887，比上一候选020少329；仍超旧15605预算282，面积门禁FAIL |
| 20次诊断 | 3799461 → 3777614 ticks，减少0.575%，五CRC正确 |
| 100次诊断 | 18776958 → 18759368 ticks，减少0.09368%，五CRC正确 |
| 已有有效板测 | 旧014位流5.346252494 CoreMark/MHz，120.461538 MHz；不能归到新位流 |

20/100次均不足10秒，不能用于正式报分。收益随迭代数增加明显缩小，没有证明长期提分。7000次交付固件字节保持不变；本次没有新的板测成绩、PVT/30分钟稳测或ILA波形。

| 位流 | 用途 |
|---|---|
| bitstream/current/ | 本轮021实验候选，源码/固件/最终STA绑定，可供SRAM上板续验 |
| bitstream/board_verified/ | 用户已实测014，保留原报告与位流，作为回退 |
| bitstream/previous020/ | 上一版020正裕量候选，未上板，历史源码可从上一版ZIP取得 |

当前位流 SHA256：`a418de18369ed75e878a025d454f42622566dd5d7019c2da5485a65ad2386c24`。

## 验证与构建

解压到短的 ASCII 路径，进入工程目录。工具为 Python 标准库；PDS/ModelSim/GCC 使用本机安装，不随包分发。

```powershell
python tools/build.py verify
python -m unittest discover -s tests -p "test_*.py" -v
python tools/board_profile.py
python tools/timing_gate.py evidence/records/boardopt_20261101/board021_gshare10_route20/pango_vexii_top.rtr
python tools/check_area_budget.py --from-used evidence/records/boardopt_20261101/board021_gshare10_route20/multiseed_summary.csv
python tools/test_isolation.py
```

面积命令会如实返回1，不应修改旧预算使其变绿。verify 的 PASS 表示身份、镜像、源依赖、板卡参数与选中STA一致，不代表面积或实板验收通过。

```powershell
python tools/build.py build --name fresh-120-001 --pds D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe
```

每次用全新名字，构建必须加载八个RAM lane。改动源码后先审查、再显式运行 `python tools/build.py manifest` 登记。重建出的位流须用自己的SHA、报告和板测，不能复用历史成绩。

- [本轮优化与复现](docs/board-optimization-20261101.md)
- [第三方来源和许可证](THIRD_PARTY_NOTICES.md)
- 本轮证据：`evidence/records/boardopt_20261101/`
- 当前实现身份：`provenance/SELECTED_IMPLEMENTATION.json`
- 先前参考意见修订记录：`docs/review-revision-20261101.md`，其中020是上一版对象
