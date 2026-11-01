# 参考意见修订说明

## 本轮实际修改

1. 新增 `firmware/diagnostics/start.S` 与 `trap_test.c`。异常入口保存通用寄存器，保持 16 字节栈对齐，C handler 校验 mcause/mepc，异常跳过四字节故障指令，中断回到原 PC，最后 mret。使用调用者易失寄存器哨兵检查恢复。独立于 CoreMark，不替换其启动代码或跑分镜像。
2. 新增 `tools/build_diagnostics.py`，独立编译、八 lane 镜像生成、ELF/RAM 字节核对、源哈希、异常入口对齐检查。链接禁用 relaxation，避免调用压缩改变 trap 地址对齐。CLINT 地址从本工程 Decoder 和 TilelinkClint 核实：基址 0x10010000，mtime +0xbff8/+0xbffc，mtimecmp +0x4000/+0x4004。该 CLINT 的高位在低位读取时锁存，按其实际 RTL 读取。
3. `tools/build.py` 增加显式 `--image/--elf`，可构建诊断位流且不覆盖原 CoreMark 固件。构建仍执行八 lane、完整最终 STA 检查，并新增面积结果记录。
4. 重写 `tests/tb_profile.sv` 的测量边界：从固件 ELF 反汇编定位 start_time/stop_time 的 mcycle 读指令，按退休 PC 采样，排除 UART 输出等待。结束后等待计数寄存器更新再打印。两个分支通道分别累加，避免同周期双事件少算。停顿原因只统计有效候选；各原因允许重叠，不能相加当总周期或把 dispatch 当退休 IPC。
5. `tests/run_rtl.py` 增加 traps 类型；benchmark/profile 完成后必须再核对五 CRC、64 位 ticks 一致性；profile 必须恰好一个闭合窗口且与固件 ticks 差不超过 64 周期，计数器输出 JSON。64 周期仅用于退休边界诊断，不改变官方分数取自固件 mcycle 的要求。
6. 修复根目录及独立包 `check_area_budget.py` 的 CSV schema 错误，按真实冻结预算计算增量。新增 release_gate，将当前位流、最终报告、资源 CSV、97 份 HDL、约束、实现 Tcl 和八 lane 固件用哈希绑定。重定位检查也携带必要证据，禁止读取旧工程。
7. 当前候选目录原有位流与 README 不一致，已纠正。当前交付采用先前完成的 positive020_route20；用户实测 positive014 另存 board_verified。本轮没有重新跑 PDS，也没有修改 CPU/Cache/预测器 RTL，选中候选 97 份 HDL、Tcl、约束和镜像已逐项对照冻结实现输入。

## 本轮验证结果

异常/中断 RTL 仿真，ModelSim，0 errors：

| 用例 | mcause | mepc | 结果 |
|---|---|---|---|
| 32 位非法指令 0xffffffff | 00000002 | 80000190 | 捕获、跳过故障、寄存器恢复 |
| M-mode ECALL | 0000000b | 800001ec | 捕获、返回后继续执行 |
| CLINT 定时中断 | 80000007 | 80000258 | 屏蔽时不进入；使能后触发；清源与 mret 恢复 |

证据：`evidence/records/review_20261101/review_traps_green_002/`。
入口未对齐的第一次诊断失败也保留，原因已修复；见 lessons。以上是 RTL 功能验证，不含 PLIC 外部中断完整验收、SDF 门级时序或实板异常验证。

CoreMark 20 次诊断，最终有效候选停顿过滤版本：`review_profile_002`：

| 指标 | 结果 |
|---|---:|
| 固件 ticks / 采样窗口周期 | 3799461 / 3799461 |
| 分支事件 / 误预测事件 | 932793 / 61776 |
| 分支误预测率 | 约 6.6227% |
| I-cache miss / wait | 244 / 1433 |
| D-cache load miss / LSU wait | 8 / 72 |
| 无候选周期 / 有候选无发射周期 | 192129 / 494546 |
| RAW 阻塞周期 / pairing 阻塞周期 | 494488 / 288484 |
| 五 CRC | e9f5 / e714 / 1fd7 / 8e3a / 4983 |

短跑存在官方“运行不足 10 秒”输出，预期且如实保留；仅诊断通过，不作为正式成绩。旧的 OR 合并分支通道统计 874435 次少算，现在分别累加为 932793 次。RAW/配对阻塞存在重叠，尚不能仅据此量化 load-use 的单独占比；cache miss 事件没有完整访问分母，不能称为精确 miss rate。

## 实现与实板结论

| 项目 | 用户已板测 positive014 | 当前候选 positive020 |
|---|---:|---:|
| PLL MHz | 120.461538 | 120.461538 |
| 最终 slow setup ns | +0.036 | +0.145 |
| 最差 hold ns | +0.016 | +0.012 |
| 全十项 STA | 正 | 正 |
| LUT / FF / LUTRAM | 8907 / 7237 / 72 | 相同 |
| 合计相对旧预算 | +611 | +611 |
| 实板成绩 | 5.346252494，5 次相同 | 未上板 |

setup 改善并不意味着所有余量同时改善；hold 更紧，不能声称长时间/PVT 稳定性已解决。PDS 截断时钟周期 8.301 ns 对应报告 120.4674 MHz；物理 PLL 实际由 27×58/13 决定，不能把报告显示值当实测最高频率。

**5.6 分未达到。** 7000 次目标要求 ticks ≤1250000000，且运行≥10秒、五 CRC 正确、对应同一位流的时序与板测证据完整。候选没有周期优化证据，不将时序收益写成分数收益。

参考意见提出的 BTB/GShare 扩容、Cache/调度改写及更早分支解析没有在本轮交付 RTL 实现。本地缺少可复现的生成器运行环境，改变 profile.json 不会改变 RTL；include 片段不是独立插件接口。已有尝试不足以证明安全有效，保留功能已验证的核，以新剖析数据支持后续微架构改动。memcpy/memset/编译参数收益也没有测出达到目标的证据，不能称“零风险提分”。

参考意见所称“超预算 611 LUT”更正为 LUT+FF+LUTRAM 合计 +611，LUT 单项 +32；不修改旧预算使门禁通过。建议的 115 MHz 对照未采用，当前主交付保持用户 ≥120 MHz 要求。尚未进行 30 分钟连续跑、高低温或新候选实板验证。

## 复现

ModelSim 和 GCC 默认路径在脚本参数中，可通过 --modelsim / --objdump / --prefix / --nm 指向自己的安装。

异常诊断（目录名必须全新）：

```powershell
python tools/build_diagnostics.py --out build/trap-image-new
python tests/run_rtl.py traps --image build/trap-image-new --name trap-sim-new --cycles 5000000
```

独立诊断 PDS 实现，生成后自行下载，须检查其自己的 STA，不能使用 CoreMark 位流的 STA 代替：

```powershell
python tools/build.py build --name trap-pds-new --image firmware/diagnostics/image --elf diagnostics.elf --pds D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe
```

本包提供已仿真的诊断 ELF/八 lane，**没有已实现的诊断位流**。默认构建不带 --image 时仍是原 7000 次 CoreMark。

性能剖析与短跑：

```powershell
python tests/prepare_benchmark.py --iterations 20 --out build/short-image-new
python tests/run_rtl.py profile --image build/short-image-new --name profile-new --cycles 14000000
```

原算法、CRC、port 计时代码和 ELF 的 .text 均不改，只改 volatile iteration 数据做诊断。时钟、CRC 与分数审计：

```powershell
python tools/build.py verify
python tools/release_gate.py
python tools/check_area_budget.py --from-used evidence/records/optimization/positive120/positive020_route20/multiseed_summary.csv
python -m unittest discover -s tests -p "test_*.py" -v
python tools/test_isolation.py
```

release_gate.py 与面积命令将按真实超限退出 1；verify 区分“身份/STA正确”与“面积通过”。源码有意修改后先审查差异再用 build.py manifest 重新登记；build 不会自动刷新哈希掩盖改动。新 RTL 的 PDS 构建检查新输出，交付 verify 检查选中的历史冻结输出。

## 对照参考意见

已落实：许可保留、可复现性能数据、异常/定时中断诊断、面积账修正、位流证据绑定、正裕量候选交付。
部分落实：时序收敛（先前完成的 +0.145 ns 实现，实板待测），异常覆盖（上述三项 RTL 通过，PLIC/实板待测）。
未完成：5.6 分、扩容预测器/更早解析分支、自研 Cache、面积减至旧预算、30 分钟/PVT 实测、ILA 实板波形。本修订没有将这些写成已达标。

本包保留完整上游许可和来源，后续开发应如实说明增量贡献。

