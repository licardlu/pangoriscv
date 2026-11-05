# `extensions/yolo/tb/` —— 仿真资产与可复现性说明

本目录有 29 个 SystemVerilog/Verilog testbench。**其中大部分当前不可运行**：它们依赖的
激励文件（`tb_params.vh`、`cpu_boot_params.vh`、`post_params.vh`、`frame.hex`、
`ddr_model.hex`、`cpu_oracle.*`、`parameters.npz` 等）是当初在另一台机器上生成的中间产物，
**没有随本快照一起交付**；`gen/` 下只剩 `packed/`、`vexii_camera/`、`vexii_firmware/`、
`vexii_soc/` 四组文件。`sim/` 目录在执行前不存在，由脚本现建。

因此下文分两类：**能跑的**（只缺 ModelSim）与 **跑不了的**（缺生成物，且部分缺生成链）。
“能跑”只表示可以在 ModelSim 里编译并通过，**不代表**已经跑过、也不构成位流或板级结论。

运行方式统一为 `scripts/run_rtl_checks.py`（ModelSim 路径见该脚本 `--modelsim` 或
`MODELSIM_BIN`），本目录不单独提供 run 脚本。

## 一、总表

| testbench | 顶层模块 | 需要的外部文件 | 由谁生成 | 现状 |
|---|---|---|---|---|
| `tb_engine_axil.v` (rt*) | `tb_engine_axil` | `gen/tb_params_rt{1,2,3}.vh` + 其引用的 `gen/ddr_*.hex`、`gen/expected_*.hex` | `scripts/gen_band_vectors.py --tag rt1/rt2/rt3` | **缺** |
| `tb_engine_axil.v` (deploy*) | `tb_engine_axil` | `gen/integration/rtl_vectors/deploy{0,1,22,81}/{tb_params.vh,ddr.hex,expected.hex}` | `scripts/gen_deployment_vectors.py` | **缺**，且其依赖 `cpu_oracle.npz`、`deployment/bundle.json` 也缺 |
| `tb_band_engine.v` | `tb_band_engine` | 同 rt* 的 `tb_params.vh` | `scripts/gen_band_vectors.py` | **缺**，且无 runner |
| `tb_band_rt.v` | `tb_band_rt` | 同 rt* 的 `tb_params.vh` | `scripts/gen_band_vectors.py` | **缺**，且无 runner |
| `tb_engine_axi.v` | `tb_engine_axi` | 同 rt* 的 `tb_params.vh` | `scripts/gen_band_vectors.py` | **缺**，且无 runner |
| `tb_postop.v` | `tb_postop` | `gen/post_params.vh` + `gen/post_ddr_<tag>.hex`、`gen/post_exp_<tag>.hex` | `scripts/gen_postop.py --op N --tag <tag>` | **缺**，且无 runner |
| `tb_cpu_ai_boot.v` | `tb_cpu_ai_boot` | `cpu_boot_params.vh`（脚本现生成）+ `gen/integration/firmware/program.hex` + `pds/flow_soc.tcl` + CPU 源码树 | `run_rtl_checks.py boot` 生成 vh；其余需另行构建 | **缺**：`gen/integration/firmware/` 与 `pds/` 整个目录都不在本包 |
| `tb_vexii_acc_smoke.v` | `tb_vexii_acc_smoke` | `request.hex`、`request_frames.hex`、`reply.hex` | `run_vexii_smoke.py --accelerator`（现生成） | 文件可现生成 |
| `tb_vexii_cpu_smoke.v` | `tb_vexii_cpu_smoke` | 只读 CPU RAM 的 8 个 lane `.bin` | `run_vexii_smoke.py`（现生成） | 文件可现生成 |
| `tb_vexii_client.v` | `tb_vexii_client` | `yolo_ai_client.v`（视频模板派生） | `run_vexii_client.py` → `generate_vexii_camera.py` | **跑不了**：需要 `hdmi1080p` 视频模板，本包未附带 |
| `tb_vexii_yolo.v` | `tb_vexii_yolo` | `frame.hex`、`cmd_preloaded.hex`/`cmd_full.hex`、`ddr_model.hex`、`ddr_input.hex` | `scripts/gen_vexii_yolo_sim.py` | **缺**，且依赖 `parameters.npz` 与测试图片 |
| `tb_vexii_mmio.v` | `tb_vexii_mmio` | 无 | — | 无 runner，需手工编译 |
| `tb_acc_bulk.v` | `tb_acc_bulk` | 无 | — | **能跑** |
| `tb_acc_mmio.v` | `tb_acc_mmio` | 无 | — | **能跑** |
| `tb_requant_q15.v` | `tb_requant_q15` | 无 | — | **能跑** |
| `tb_tlul_axil.v` | `tb_tlul_axil` | 无 | — | **能跑** |
| `tb_ddr_bridge.v` | `tb_ddr_bridge` | 无 | — | **能跑** |
| `tb_cdc_path.v` | `tb_cdc_path` | 无 | — | **能跑** |
| `tb_axil_adapter.v` | `tb_axil_adapter` | 无 | — | **能跑** |
| `tb_camera_snapshot.v` | `tb_camera_snapshot` | 无 | — | **能跑** |
| `tb_video_frontend.v` | `tb_video_frontend` | 无 | — | **能跑** |
| `tb_native_arbiter.v` | `tb_native_arbiter` | 无 | — | **能跑** |
| `tb_axi_cdc.v` | `tb_axi_cdc` | 无 | — | 无 runner，需手工编译 |
| `tb_axi_wr_tracker.v` | `tb_axi_wr_tracker` | 无 | — | 无 runner，需手工编译 |
| `tb_mac_array.v` | `tb_mac_array` | 无 | — | 无 runner，需手工编译 |
| `tb_uart_rx_rate.v` | `tb_uart_rx_rate` | 无 | — | 无 runner，需手工编译 |
| `tb_tilelink_uart_rx.v` | `tb_tilelink_uart_rx` | 无 | — | 无 runner，需手工编译 |
| `tb_acc_shell.v` | `tb_acc_shell` | `layer/{in,w,bias,m,gold}.hex` | **无生成脚本**（`conv_int8/` 遗留） | **跑不了** |
| `tb_real_layer.v` | `tb_real_layer` | `layer10/{in,w,bias,m,gold}.hex` + `cfg.txt` | `scripts/gen_real_layer.py --out conv_int8/layer10`（需 torch 与前一层数据） | **缺** |
| `tb_conv3x3_tile.sv` | `tb_conv3x3_tile` | `expected.hex` | **无生成脚本** | **跑不了** |

> `tb_engine_axil.v` 一个文件对应两套用例（`rt*` 与 `deploy*`），所以表格 30 行
> 对应 29 个 testbench 文件。

## 二、能跑的（只缺 ModelSim）

`tb_acc_bulk`、`tb_acc_mmio`、`tb_requant_q15`、`tb_tlul_axil`、`tb_ddr_bridge`、
`tb_cdc_path`、`tb_axil_adapter`、`tb_camera_snapshot`、`tb_video_frontend`、
`tb_native_arbiter` 自包含，用 `run_rtl_checks.py` 的 `bulk / mmio / requant / tlul /
bridge / cdc / adapter / snapshot / video / arbiter` 用例即可。它们验证的是
**加速器与总线边界的功能行为**（寄存器读写、burst 等价、CDC 握手、像素搬运），
不是整网精度，也不是时序/资源结论。

`tb_axi_cdc`、`tb_axi_wr_tracker`、`tb_mac_array`、`tb_uart_rx_rate`、
`tb_tilelink_uart_rx`、`tb_vexii_mmio` 同样自包含，但本包内没有调用它们的脚本，
需要自己写 `vlib/vlog/vsim` 三行。以上合计 16 个。

`tb_vexii_cpu_smoke` / `tb_vexii_acc_smoke` 的激励由 `run_vexii_smoke.py` 现生成，
但要能编译还需要 `project/cpu120`（CPU 源码）与 RISC-V GCC。

## 三、跑不了的（逐项说明缺口）

1. **所有依赖 `tb_params.vh` / `post_params.vh` 的卷积用例**——向量文件不在包里。
   `gen_band_vectors.py` 能重新生成，但 `run_rtl_checks.py` 期待
   `gen/tb_params_rt1.vh`…`rt3.vh` 三个固定 tag，而当年的具体 `--shape/--layer/--tr`
   命令行没有记录，重新生成的形状不可能与历史一致。
   **结论：历史上的“逐层逐字节通过”无法原样复跑，只能重新生成一套自洽向量重跑。**
2. **`deploy0/1/22/81`（四个真实部署卷积层对 RTL）**——`gen_deployment_vectors.py`
   先读 `gen/integration/cpu_oracle.npz` 与 `gen/integration/deployment/bundle.json`，
   两者都不在包里。
3. **`parameters.npz`**——缺。它由 `scripts/deployment_bundle.py` 的 `calibrate()`
   写出（默认输出 `gen/integration/deployment/parameters.npz`），该函数还需要
   `gen/integration/graph.json` 与 `data/layer_table/layers.csv`，二者也不在包里；
   而 `gen/graph.json` 的可再生版本由 `export_graph.py` 产生，它同样依赖
   `data/layer_table/layers.csv`。**本包内没有可直接重跑的导出链**，
   `quant_yolov5n.py` 只做 INT8 精度评估，不产出 `parameters.npz`。
4. **`cpu_oracle.*`**——由 `scripts/test_deployment_cpu.py --export` 生成，
   同样依赖 `parameters.npz`，因此同样缺失。
5. **`tb_cpu_ai_boot`**——除向量外还要 `gen/integration/firmware/program.hex`
   （27 MHz 遗留固件）与 `pds/flow_soc.tcl`；本包两者都没有。
6. **`tb_vexii_yolo`（整机仿真）**——要 `frame.hex`/`ddr_model.hex` 等，
   由 `gen_vexii_yolo_sim.py` 生成，而它需要测试图片与 `Deployment(parameters.npz)`。
7. **`tb_acc_shell` / `tb_conv3x3_tile`**——`layer/*.hex`、`expected.hex` 由
   早期 `conv_int8/` 流程产生，脚本已不在本快照中。

## 四、一句话总结

**29 个 testbench 里，16 个自包含用例装好 ModelSim 就能编译通过，另 2 个的激励由
`run_vexii_smoke.py` 现生成；剩下 11 个（含全部“整网 / 逐层逐字节”类结论）因激励文件
与生成链缺失而无法复跑。历史仿真结论只能作为记录引用，不能作为评审核验手段。**
