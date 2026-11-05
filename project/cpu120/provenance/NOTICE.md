# 上游来源、作者与许可证

本改进包基于 https://github.com/licardlu/pangoriscv 的 main 提交 f040ac2bdb7ab129b42b414bd6b78779b84640bb（2026-10-30 下载），使用 project/pds_native_120 的独立 PDS 工程。它保留 VexiiRiscv / SpinalHDL 生成 CPU 与 SoC 逻辑，不能将重命名或源码拆分称为独立原创架构。

- VexiiRiscv：https://github.com/SpinalHDL/VexiiRiscv ，MIT，Copyright (c) 2023 SpinalHDL。许可全文：licenses/VexiiRiscv-MIT.txt。该 CPU 的插件命名、数据通路与生成式逻辑均有上游来源。
- SpinalHDL：https://github.com/SpinalHDL/SpinalHDL ，库为 MIT，生成器 core 为 LGPL-3.0；声明与两种许可均在 licenses/。生成器本体不作为本包构建依赖；不得据此断言本包每个生成 HDL 文件都属 LGPL。
- CoreMark：https://github.com/eembc/coremark ，Apache-2.0，版权与商标条件见 firmware/source/coremark/LICENSE.md，源文件内 EEMBC 版权头保留。
- licardlu/pangoriscv：板卡集成、独立 HDL 工程、提取记录与先前优化来自上述固定提交。该提交没有根 LICENSE，不替仓库作者编造额外授权；用户先前称已获作者许可，该声明不代表获得其他第三方重新许可。
- PDS 的 GTP_PPLL FPGA 原语属于工具/器件接口，PDS 与 ModelSim 需用户自行安装授权，本包不分发商业工具。

最新版上游未包含 provenance/ 目录。本轮将已知上游许可原文补回，文本复制自先前保留的上游 checkout；SHA256 记录在 license-copy-record.json。源码来源提取记录见 rtl/core/manifest.json；它是历史提取清单，不是本轮哈希验收清单。

本轮改动、测试和限制记录在改进版1说明中。新写测试/脚本和修改不抹除原作者归属。
