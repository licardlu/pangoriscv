# conv_int8 —— Lite-A 定点卷积核心

自包含：模型描述、整数参考、RTL、测试向量生成、逐位比对脚本都在本目录。

## 快速验证

```bash
cd ai_lab/conv_int8
python lite_a.py            # 逐层表 + DDR 地址表（带重叠/对齐自检）+ 帧率估算
python run_layer_tests.py   # 8 组用例，RTL 与整数参考逐字节比对
```

`run_layer_tests.py` 会自动寻找 iverilog：先看环境变量 `IVERILOG_BIN`，
再找 `../../toolchain/iverilog/bin` 和几处常见路径。找不到就报错退出，不会静默跳过。

## 文件

| 文件 | 作用 |
|---|---|
| `lite_a.py` | 唯一数据源：层形状、MAC、参数量、DDR 地址表 |
| `fixed_ref.py` | 逐位精确的整数参考（含自检） |
| `gen_vectors.py` | 由参考生成 RTL 测试向量，支持 rand/zero/extreme/sat/neg |
| `run_layer_tests.py` | 批量跑用例并写日志到 `logs/` |
| `rtl/conv3x3_core.v` | 单层卷积引擎，COUT×8 lane |
| `rtl/conv3x3_top.v` | 自测外壳（综合用，把全部通道 XOR 归约到 8 位） |
| `tb/tb_conv3x3.v` | 从 `vec/` 读向量、逐字节比对 |
| `impl_conv.tcl`、`conv3x3.fdc` | PDS 综合脚本与 50 MHz 约束 |

## 冻结的数值规则

以 `fixed_ref.py` 为准，RTL 必须逐位复现：

| 项 | 规则 |
|---|---|
| 权重 | per-output-channel 对称，`s_w = max|w[oc]|/127` |
| 激活 | per-tensor 对称，`s_x = max|a|/127` |
| 累加 | int32，`acc = Σ a_q·w_q + bias_q` |
| 缩放 | `y = (acc·M) >> S`，`M = round(s_x·s_w/s_y · 2^15)`，S=15 |
| 舍入 | round-half-**away-from-zero**（负数按符号加半） |
| 饱和 | clip 到 `[-128, 127]` |
| LeakyReLU | `y >> 3`，算术右移即 floor |

## 已知陷阱

1. 自测外壳必须把**全部输出通道**接到可观测输出，否则综合器删掉其余通道、资源假低。
2. 激励不能给所有输出通道同一组权重，否则累加器全相同、阵列被合并。
3. 上两条都表现为“64 路只用 251 LUT / 8 APM”，凭常识即可识别。

## 实测（64 lane，COUT=8）

| 项 | 值 |
|---|---|
| LUT | 1,688 / 66,600（2.53%） |
| FF | 346 / 133,200 |
| APM | 38 / 240（15.8%） |
| DRM | 0 |
| WNS（慢角 @20 ns） | +7.819 ns，0 失败端点，Fmax ≈ 82 MHz |

38 APM 对应 64 路乘加，说明综合器把约 1.7 个乘加打包进一个 APM。这是实测现象，
但打包后的有符号运算尚未做门级等价验证，**资源预算仍按 1 MAC : 1 APM 保守口径**。
