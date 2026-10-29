# 来源、修改边界与许可证

- CPU/SoC：VexiiRiscv，Copyright (c) 2023 SpinalHDL，MIT。
  https://github.com/SpinalHDL/VexiiRiscv/tree/ae9060aca523e406fc6f3ba2a502414956ac495b
  完整许可保留于 `upstream/VexiiRiscv/LICENSE`。
- SpinalHDL：`de72faf6062206a89b445e5cc07e32ed982712c8`，
  core使用LGPL，lib使用MIT；随包保留对应源码、许可证和可修改重编译的构建文件。
  https://github.com/SpinalHDL/SpinalHDL/tree/de72faf6062206a89b445e5cc07e32ed982712c8
- rvls绑定：`847ce99fd2b28a5c0ccb1ec2683311cf97a9fefc`；许可位于对应上游目录。
  https://github.com/SpinalHDL/rvls/tree/847ce99fd2b28a5c0ccb1ec2683311cf97a9fefc
- CoreMark：EEMBC官方仓库，`1f483d5b8316753a742cbf5590caf5bd0a4e4777`，Apache-2.0。
  https://github.com/eembc/coremark/tree/1f483d5b8316753a742cbf5590caf5bd0a4e4777
  `firmware/coremark` 的算法文件保持上游内容。平台修改位于 `firmware/port`。
- 板卡参数参考：licardlu/pangoriscv，固定快照
  `77141338dc9e3f3a3391ae3d19e95d195e64b37b`，仅参考板卡参数与工程使用经验。
  https://github.com/licardlu/pangoriscv
- 本次板级代码在本地独立移植基线 `pango_vexii_20261026` 上继续修改。
  新增内容包括生成配置、固件布局一致性修正、结果/镜像校验、构建及交付脚本。
  名称“改进版”指上述集成和配置修改，不表示VexiiRiscv内核由本项目原创。

`tools/runtime`包含离线运行生成器所需的Java/Scala库，不含JRE。
对应SpinalHDL/VexiiRiscv源码随包提供；第三方依赖JAR内的META-INF许可和NOTICE保持原样。
依赖坐标/版本可由JAR文件名、`tools/runtime/classpath.json`和上游build.sbt核对，
第三方库的源代码可通过 Maven Central 对应版本的 `-sources.jar` 获取。
可修改上游源码并使用sbt重新生成；离线JAR并不限制采用修改后的源码重编译。

本包不包含PDS、ModelSim、GCC、厂商仿真模型或任何商业工具许可证。
