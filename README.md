# 青禾 FPGA 四桶垃圾分类系统

本仓库交接分支为 **`main`**。代码、模型、构建与下载脚本、验收证据集中在本目录；PDS、编译器和安装包自行安装。

**先读 [交接说明](docs/HANDOFF.md)。当前板上为 2026-11-13 下载的 092 手部过滤实验版，093 为本次实际下载记录。** 模型CRC、手类别固定输入、相机推理和自动模式已通过；空手/掌中电池准确性仍待现场测试。不要把“模型已运行”理解成“手部问题全部解决”。

| 入口 | 内容 |
| --- | --- |
| [当前092完整源码快照](project/trash_sorting/releases/hand_trial_092/README.md) | 可从源码重编；包含配套固件，脱离临时build目录 |
| [当前092下载包](project/trash_sorting/diagnostics/hand_trial_54mhz_092/README.md) | 位流＋五内部类模型＋数值校验输入；四桶和hand类成套使用 |
| [062四桶回退包](project/trash_sorting/bitstream/full_54mhz_20261113/README.md) | 无hand类的较早版本，保留用于回退 |
| [应用开发源码](project/trash_sorting/source/) | 默认27MHz四类源码入口，不等同于当前092发布快照 |
| [训练脚本与权重](project/trash_sorting/training/README.md) | 四桶、手类训练、量化、数据来源和标签/划分记录 |
| [当前板测结果](evidence/records/trash-hand-trial-program-20261113-093/acceptance_summary.json) | JTAG、CRC、真实hand输出、数值与速度 |
| [手部试用报告](docs/verification/trash-hand-trial-deployment-20261113.md) | 当前版本身份、限制及部署过程 |
| [CPU独立工程](project/pds_native_120/) | CoreMark历史主线；与本应用54MHz性能不能混用 |
| [历史文档与仓库外辅助代码](docs/reference/external-project-notes/) | 技术文档、赛题PDF、旧辅助脚本；原位置保留 |

## 先验证文件

在仓库根目录运行，Python 3.10+，不需要开发板：

```powershell
python tools/check_handoff.py
python tools/check_package.py
```

前者检查当前/回退包和092源码闭包，后者检查当前关键交接文件的SHA256。新改代码后整包哈希失配是正常的，需重新生成清单，不能沿用旧PASS。

## 恢复当前手部版

Windows、PDS 2022.2-SP6.1、有效器件许可证，连接JTAG和模型UART；本机模型口为COM34，其他电脑按实际修改。

```powershell
python -m pip install -r project/trash_sorting/requirements-deploy.txt
$PdsBin = "C:/Pango/PDS_2022.2-SP6.1/bin" # 改成自己的PDS bin
python project/trash_sorting/tools/restore_full_board.py `
  --release-dir project/trash_sorting/diagnostics/hand_trial_54mhz_092 `
  --port COM34 --pds "$PdsBin" `
  --out evidence/records/my-hand-trial-001 `
  --fixtures project/trash_sorting/diagnostics/hand_trial_54mhz_092/fixtures `
  --verify-input --collect-profile --probe-frames 10
```

证据目录必须使用新名字。下载只写SRAM，**掉电会丢失位流和模型**，上电后需重载；没有烧Flash。正常一次恢复约5～7分钟，不需重新布线。当前实验版十帧诊断均空输出，平均 **1.742488秒**、最慢1.752200秒；统计取图/推理/解码/选择，不含语音答题和舵机，不承诺所有物品均两秒。

## 四桶与游戏规则

| 模型ID | 颜色/垃圾桶 | 答案按键/桶码 | 物品例子 |
| --- | --- | --- | --- |
| 0 | 绿色：厨余 | 1 | 果皮、剩余食物 |
| 1 | 蓝色：可回收 | 4 | 干净纸张/纸板、塑料盒、玻璃瓶、金属罐 |
| 2 | 红色：有害 | 2 | 本项目标签中的电池；药品覆盖不足 |
| 3 | 灰色：其他 | 3 | 用过的纸巾、陶瓷、砖石等已有训练标签 |
| 4 | hand内部定位类 | 无 | 只筛选主体，不展示为第五桶 |

一次仅选一个物品。识别后等待答案键，答对/错只影响语音，均开**识别结果对应桶**。舵机默认关闭，开盖到位后停5秒关闭；实物校准掩码`1111`。顶部48行状态区保留，摄像头完整视野缩放至下方672行，状态文字不覆盖画面。

## 接着开发

优先处理真实空手误报、手持小电池漏检、杂背景抢主体；补不同实物及板载摄像头的训练/验证照片。照片不能只按角度随机拆分：同一实物/场次放同一split。已用过的068电池最终测试集不能再当独立新测试调参。当前手部策略、已失败方案和具体重建命令见[交接说明](docs/HANDOFF.md)。

旧的2026-11-04整包README、哈希和检查记录保留在`docs/archive/pre-handoff-20261113/`，只作历史证据。数据集与模型来源、使用条件见[署名](project/trash_sorting/training/candidates/four_bins_20261111/ATTRIBUTION.md)。
