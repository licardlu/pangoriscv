# 092 手部过滤实验版源码交接

本目录`source/`为092综合前冻结的应用输入，含摄像头/DDR/HDMI、CPU/AI、按键、语音/ROM、舵机、界面和配套五类模型。`firmware/`保存实际编译固件、ELF、ROM lanes、链接图和源身份。`manifest.json`绑定这里的文件；原始实现输入哈希另存`implementation_inputs_original.json`。参考graph已改为054对应的正确五类图，硬件实际编译依赖的头文件/模型未改。

模型类序为kitchen/recyclable/hazardous/other/hand，hand仅内部定位。源码为54MHz/O2/packed ADD关闭、大小物体接触筛选。下载包位于`../../diagnostics/hand_trial_54mhz_092/`；模型checkpoint位于`../../training/candidates/hand_trial_045/best.pt`。

从仓库根目录重编固件，先把GCC前缀改成自己的路径：

```powershell
$GccPrefix = "C:/toolchains/riscv/bin/riscv-none-elf"
python project/trash_sorting/tools/rebuild_firmware.py `
  --source-dir project/trash_sorting/releases/hand_trial_092/source `
  --classes 5 --cpu-hz 54000000 --linear-o2 `
  --gcc-prefix "$GccPrefix" --out build/my-hand-fw-001
```

若只复现，下一步可直接使用本目录的冻结固件；若改了C源码，下一步必须传刚编译的`build/my-hand-fw-001`。未改动复编应为44432字节，SHA256 `f81e9720b64262e057aeec56fc2ed513cbf1c55643f360cc35ec8ff7c3a97101`。094交接验证已实际复编得到该SHA。

重新实现，PDS路径按本机安装修改：

```powershell
$PdsBin = "C:/Pango/PDS_2022.2-SP6.1/bin"
python project/trash_sorting/tools/build_full.py `
  --source-dir project/trash_sorting/releases/hand_trial_092/source `
  --firmware-dir project/trash_sorting/releases/hand_trial_092/firmware `
  --ai-clock-mode 2 --optimize-multi-corner-timing `
  --name my-hand-implementation-001 --pds "$PdsBin" `
  --release-dir project/trash_sorting/diagnostics/my-hand-001
```

每轮使用新name，不覆盖实现和证据。092完整综合/布局布线约38分钟，位流生成另约2分钟，只作时间参考。构建必须通过镜像加载、资源及最终快慢角STA才出位流。重建不保证位流逐位相同。构建器冻结输入进build后运行PDS，自动处理ROM相对路径；不直接在本源码目录启动PDS。

下载无需重新实现，按仓库根README恢复已发布下载包。实际当前板为092，证据093；手部准确性未验收，不用历史062指标声称本模型效果。
