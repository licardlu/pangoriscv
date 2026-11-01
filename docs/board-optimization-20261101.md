# 盘古100Pro+板卡资料续验与优化

## 目标与证据边界

目标仍为 120 MHz 以上稳定运行、约 5.6 CoreMark/MHz。本轮不把提高时钟频率等同于提高 CoreMark/MHz，不改变 CoreMark 算法、输入、CRC 或计时方法。正式交付固件仍为原 7000 次镜像。

用户已有的有效上板成绩是 **5.346252494 CoreMark/MHz**，7000 次、1,309,328,358 ticks、120.461538 MHz、约 10.8693 秒；对应 positive014_route12，位流 SHA256 `0d2d06667abc9065009ffe53840fbc542b927cac2e2e6993ccfe64f1c6193214`。五次独立 SRAM 配置得到相同结果。原报告在 `evidence/records/review_20261101/上板验证报告.md`。此成绩不转移到任何新位流。

## 开发板资料核对

来源为用户给出的 `G:/盘古100Pro+开发板（MES2L676-100HP）配套资料/`，原 PDF 路径、SHA256 和已读 PDF 页码保存在 `evidence/records/boardopt_20261101/materials/sources.json`。包内仅保留相关页文本摘录，不分发整套厂商工具或仿真模型。PDF 页码按文件内从 1 开始计数。

| 项目 | 已核对配置 | 资料位置 |
|---|---|---|
| 器件/板卡 | PG2L100H-6IFBG676，MES2L676-100HP V1.2 | 硬件指导及用户板测报告 |
| 主时钟 | 27 MHz，U11 到 FPGA D18 | 硬件实验指导手册 PDF 22–23 页 |
| 复位/按键 | KEY0=C22、KEY1=C23，低有效 | 同上 50–51 页 |
| UART | FPGA RX=B24、TX=C24 | 同上 43–44 页 |
| LED0–7 | A20/C18/C19/E18/A17/A18/C17/B17，高有效 | 同上 50–51 页 |
| IO 电压 | LVCMOS33，VCCIO=3.3 V | 电源与各外设接线页 |
| PPLL | FIN/PFD=27 MHz，VCO=1566 MHz，输出=120.461538 MHz | Logos2 数据手册 PDF 26 页，PPLL 表 |

数据手册 25 页是 GPLL，26 页才是本工程采用的 PPLL。PPLL 限值 FIN=19–800 MHz、PFD=19–450 MHz、VCO=1330–2133 MHz、FOUT=10.39–2133 MHz。当前 27×58/13 参数在范围内，因此没有盲目换用板上的 125 MHz DDR3 差分参考源，也没有改变 PLL 倍频或降低 CPU 频率。

新增 `configuration/board_mes2l676.json` 和 `tools/board_profile.py`，自动核对 13 个引脚、IO 标准/电压、PLL 类型及倍率范围、profile/固件 CPU_HZ、FDC 两个时钟周期。错误引脚和非法 VCO 有负向回归。此检查验证参数一致性，不测量晶振误差、电源、温度或信号完整性。

`pango_reset.sv` 原有逻辑为失锁/KEY0 异步置复位、CPU 时钟四拍后释放，本轮没有修改。UART/LED 等异步外设端口没有凭空添加外部延时数字；PDS 中有关这些端口的未约束提示仍保留。正裕量结论只按报告中实际被检查的时钟域路径及十项检查解释，不等于所有板外接口得到同步时序证明。既有最终 STA 已计入 0.150 ns clock uncertainty，并非没有任何时钟余量建模。

## CPU 改动及筛选

候选021仅修改 GShare 的两个地址函数：取指查表和学习写回均使用 `reversed_pc_slice ^ (history & 12'h3ff)`，历史参与异或的长度从 12 位变为 10 位。地址仍是 12 位，方向表仍为 4096×8 bit，初始化、学习覆盖及饱和计数算法、旁路、Cache、流水级、外设和程序存储均保持原接口。该选择来自现有分支 trace 的别名筛选，再由真实 RTL 仿真确认，不能将离线模型的 miss 数当作处理器实测。

源码注释中的“timing unchanged”仅指 RTL 接口拍数不变，不保证布局布线后的延时相同。修改地址函数后必须重新完整实现，不能沿用020的时序报告。

两侧实际 RTL 表达式的定向测试在旧代码失败，新代码通过 524,288 组向量。20 次相同机器指令的对照如下：

| 诊断指标 | 基线 | 021 GShare10 |
|---|---:|---:|
| ticks | 3,799,461 | 3,777,614 |
| 分支事件 | 932,793 | 932,793 |
| 预测 miss | 61,776 | 58,473 |
| 退休指令数 | 4,888,104 | 4,888,104 |
| 退休 PC/UOP 滚动摘要 | 9db092547147ca2e | 9db092547147ca2e |
| I-Cache miss | 244 | 242 |
| D-Cache load miss | 8 | 8 |

周期减少约 0.575%，相同退休摘要和五项 CRC 提供额外回归信号，但不构成形式 ISA 等价证明。短跑归一化值 5.294347173 只用于诊断，不是正式成绩；官方程序因不足 10 秒打印 ERROR 属于预期的短跑无效提示，不能删掉再声称正式通过。

未采用的独立实验也保留：方向表局部写使能为 3,801,279 ticks，关闭循环展开为 4,537,675 ticks，`-O3` 为 3,882,272 ticks，均没有优于既有配置。两个编译试验运行在021 RTL上；其中关闭展开与旧 RTL 基线的差异是“021+编译选项”组合，不归因成纯软件 A/B。这三项没有混入最终选中 RTL/固件。候选022的源与定向测试移到证据目录，避免其不同的设计合同污染当前回归。

100 次相同固件的较长诊断为基线 **18,776,958** ticks、候选 **18,759,368** ticks，仅减少约 **0.09368%**。两份镜像的 ELF、RAM 与 `.text` SHA 完全一致；实际 RTL 快照仅上述两个索引函数不同，见 `ab100_inputs.json`。不得只报20次的较大收益而省略100次结果。

收益随迭代数增加明显缩小，提示短跑初始训练效果不能代表稳态。若比较两个独立运行中“100次ticks减20次ticks”的差，候选后80次反而多4,257周期；这只是相同前缀下的差分推算，并非单独抓取的稳态测试。当前没有7000次新实板成绩，**没有证明长期提分，更未达到5.6**。候选以可复现的实验形式交付，原已板测位流与先前020候选均保留供回退。

异常诊断已重新验证：非法指令 cause=2、ECALL cause=11、机器定时中断 cause=0x80000007，均正常 mret 返回并输出 DIAG_DONE。

## 续验结果

最终选中 `board021_gshare10_route20`，独立实现耗时约29.3分钟，八路RAM初始化成功。最终 setup=+0.148ns，Slow/Fast hold=+0.044/+0.028ns；recovery、removal、脉宽等十项全部正、失败端点均0。报告约束周期被PDS显示截断为8.301ns（120.4674MHz），实际PLL配置仍为120.461538MHz，不把报告推算的最高频率当板测。

资源LUT9016/FF6799/LUTRAM72/DRM34/APM5，合计15887，比020少329，但相对冻结15605预算仍增加282（LUT单项+141），**面积门禁仍FAIL**。setup相对020的+0.145ns仅增3ps，hold由+0.012变为+0.028ns，不把数皮秒变化夸大成板级稳定性已解决。

位流SHA256 `a418de18369ed75e878a025d454f42622566dd5d7019c2da5485a65ad2386c24`。109个源码/约束/flow/固件输入与综合快照逐一核对，RTL包含路径仅作文本规范化后比较，原始哈希均保留。所选网表20万周期数字输出对照通过（61个UART下降沿）；厂商模型仍有131条警告，包含未使用初始化切片越界等，原日志未删改，不称无警告。

生成位流还保留 `Bitstream-2001: SCBV has not been set`。PDS用户手册PDF第150页说明SCBV为配置Bank电压设置、默认None，涉及L4/L5 Bank使用；本轮没有按猜测更改配置电压或屏蔽提示，沿用历史JTAG/SRAM路径。本包不宣称SPI Flash固化/冷启动已经验证，也不把该提示当成CPU分数或时钟频率。

原已上板014和未板测020位流分别保留在 board_verified、previous020；本轮021为待板测实验候选。没有新的有效板载CoreMark成绩，**120MHz长期稳定及5.6目标均仍需真实验证，5.6未达到**。

## 复现入口

```powershell
python tools/board_profile.py
python tests/run_hash_test.py --name fresh-hash-001
python tests/prepare_benchmark.py --iterations 100 --out build/fresh-image100
python tests/run_rtl.py profile --image build/fresh-image100 --name fresh-profile100 --cycles 40000000
python tests/run_rtl.py traps --image firmware/diagnostics/image --name fresh-traps --cycles 5000000
python tools/build.py build --name fresh-implementation-001 --pds D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe
python tests/run_gate_smoke.py --build fresh-implementation-001 --name fresh-gate-001 --cycles 200000
```

每个构建/仿真名字必须是未使用的新目录。综合网表对照现在校验综合时冻结的全部 RTL/包含文件和 source_list 的 SHA，再使用这份输入作参照。该数字检查替换 PLL、对齐时钟、无 SDF，不替代 PLL 模型验证、后布局时序仿真或真实上板。许可证和上游来源见根目录 `THIRD_PARTY_NOTICES.md`。
