# VexiiRiscv改进版

目标：PG2L100H-6IFBG676开发板，RV32IMC双发射，CoreMark/MHz ≥5.2，CPU ≥120 MHz。
使用 pangoriscv 的板卡参数，CPU/SoC采用VexiiRiscv，不复用pangoriscv的CPU实现。

**这是等待完成PDS时序与用户板测的移植版本，不能宣称已经达到最终上板指标。**
当前PLL配置120.461538 MHz；新配置在PDS编译入口遭遇工具内部错误，
最小单线模块也复现同一错误。因此本包没有新位流或新配置的时序通过证据。
最终100次RTL诊断已完成：18,776,958周期，5.325676 CoreMark/MHz，
已知种子/列表/矩阵/状态CRC相符。运行仅0.155875秒，不属于正式成绩。

## 包含内容

- `project/VexiiRiscv_improved.pds`：可打开的PDS工程。
- `rtl/generated/MicroSoc.v`及8个`.bin`：已生成的整机RTL和正式7000次固件初始化数据。
- `rtl/pango_*.sv`：PLL、复位与板级顶层；`platform/`为约束和配置。
- `upstream/VexiiRiscv/`：固定版本CPU和生成器源码、SpinalHDL与rvls绑定源码。
- `tools/runtime/`：离线生成器JAR；运行需要Java 17，不需要重新联网下载sbt依赖。
- `firmware/coremark/`：官方算法；`firmware/port/`：启动、链接、UART、cycle64计时。
- `build/firmware_100/`、`build/firmware_7000/`：可核查的ELF、反汇编、编译选项与SHA256。
- `evidence/`：本次原始日志、测量和完整性清单；最终状态见 `docs/verification.md`。
- `docs/board-test.md`：用户上板步骤。代码与许可证来源见 `THIRD_PARTY_NOTICES.md`。

## 直接综合

建议将压缩包解压到纯英文工作路径，例如 `D:/fpga/vexii_improved`。
打开 `project/VexiiRiscv_improved.pds`，顶层选择 `pango_vexii_top`，
执行Compile → Synthesize → Device Map → Place & Route → Timing → Generate Bitstream。
RAM初始化文件已经放在工程目录，不需要先安装Java或重新生成RTL。
必须先确认8个初始化文件被读入、setup和hold通过，才能使用该次位流。

本版UART为约115200/8N1，27 MHz输入位于D18，KEY0复位位于C22。
完整管脚合同与架构修改见 `docs/architecture.md`。

## 重新生成与构建

Python 3.10+，Java 17，RISC-V GCC，ModelSim，PDS 2022.2-SP6.1。
工具路径保存在 `tools/local-tools.json`，可运行下列命令生成本机配置：

```powershell
./scripts/configure-tools.ps1 -Java 'C:/path/to/jdk17/bin/java.exe'
python scripts/build.py firmware --iterations 7000
python scripts/build.py generate --iterations 7000 --name my_release
python scripts/verify_image.py build/firmware_7000/coremark.elf rtl/generated
python scripts/build.py implement --name my_release
```

同名生成/实现目录禁止覆盖；每次换一个`--name`，保留对应证据。
`generate`更新`rtl/generated`；命令行`implement`直接使用这里的文件。
若重新生成后改用GUI打开已有`project`工程，还需将`rtl/generated`中的8个`.bin`
同步复制到`project`目录，再核对ELF与该目录初始化文件，避免使用旧镜像。
若修改CPU源码，需要使用上游sbt构建产生新的生成器，而不能继续使用旧JAR。
可临时移走`tools/runtime/classpath.json`并在local-tools.json中删除classpath字段，
让生成脚本改用sbt；参考上游build.sbt，重新编译修改后的SpinalHDL/VexiiRiscv。

## 仿真与单元检查

```powershell
python -m unittest discover -s tb -p 'test_*.py' -v
python scripts/check-board-rtl.py
python scripts/build.py firmware --iterations 100
python scripts/build.py generate --iterations 100 --name short_check
python scripts/build.py simulate --name short_check --cycles 60000000
python scripts/assess_result.py build/sim_short_check/simulate.log --source simulation
```

100次为短跑诊断，官方CoreMark会正确提示运行不足10秒，它不是正式成绩。
正式镜像为7000次，运行时间应由实际 `TICKS_HI/LO` 验证，不以迭代次数本身保证。
短跑后需重新生成7000次镜像或还原交付初始化文件，再综合用于正式上板。
用户若需要完整7000次RTL仿真，可使用 `--cycles 2000000000`，该运行耗时很长。

## 交付文件校验

解压后在包根目录执行以下PowerShell命令，所有文件应显示匹配：

```powershell
$bad = @(Get-Content -LiteralPath './SHA256SUMS.txt' | ForEach-Object {
  $expected, $name = $_ -split '  ', 2
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $name).Hash.ToLower() -ne $expected) { $name }
})
if ($bad.Count) { throw ($bad -join ', ') } else { 'SHA256 verified' }
```

验证完成后可用 `python scripts/package_release.py --output output/new_release` 重新打包；
新包不含ModelSim工作库、下载缓存或商业工具。

## 上板验收

本包不自动连接或操作板卡。由用户按 `docs/board-test.md` 下载并保存原始UART日志。
最终验收需同时满足：正确CRC及官方验证、实际运行≥10秒、≥5.2 CoreMark/MHz、
同一份实现的CPU≥120 MHz且STA通过。本次不把目标值、PLL模型或短仿真当作板测结果。
