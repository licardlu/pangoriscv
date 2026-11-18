# continuation_022：已获准上板的代码候选

**最新状态**：full002实验位流和配套stage4模型已成功下载，模型CRC与相机推理通过，板上记录见 `evidence/records/overnight-20261116/continuation-022-board-003/result.json`。此版**未通过最终时序签核**：右相机路径 slow setup -0.428 ns、29个失败端点，实验结论不等于正式交付合格。双目标定与20厘米门控仍未实测启用。以下“正在实现/未下载”文字是当时的历史状态。

本候选从已上板的 overnight_020/006 冻结源复制。用户最新明确要求“上版子吧我要测试了”，已获准重新实现及SRAM下载/模型UART验证，TF/Flash仍暂缓。full001第二相机时钟放置失败，失败证据已独立保存。移除右路冗余全局缓冲、保留区域控制时钟及专用图像bank全局MUX后，最小时钟工程完成布线；7项RTL/131文件语法和顶层接口检查再次通过。full002正在整机重新实现，当前还没有022位流下载成功结论。

## 改动

- 启动先显示待机动画；KEY0 单击开始/停止识别；350ms 内双击进入演示跑分，再双击回动画。手动操作优先，沿用4帧淡出、黑场、4帧淡入。
- 双相机快照：原320×180×16位存储拆成等容量两路字节RAM；RGB模式保留左相机RGB565，双目模式提供左右灰度。专用无毛刺时钟MUX切换第二bank写时钟，完整帧检查、模式握手、超时隔离及复位恢复。
- 标定后支持稀疏测距：5×5零均值匹配、9点、左右一致性、纹理和唯一性筛选；距离区间跨越200mm时返回UNKNOWN。连续两次近物/远物切换识别/动画；提交题目前另拍双目并检查物体变化和新鲜近物结果。测距期间手动按键取消优先。
- UART命令21抓取配对元数据、22读取冻结图像块、23查询/启停距离门控。电脑抓图与离线标定导出工具不自行连接设备。
- 缩小推理缓存及临时计算块，采用GCC Oz/LTO/newlib-nano，保留80KiB RAM和至少8KiB堆栈，不缩Top-K、类别数或识别阈值。
- 保留前夜stage4五类模型（手为内部类、四桶输出）、1280×720界面、13条语音及18–24秒/5.12–5.28模拟跑分；本轮没有追加训练。
- 跨时钟加固：页面请求改为源端注册独热码，零/多热过渡码不改变手动优先状态；帧计数Gray码源端注册并标记同步链。采集等待中继续服务界面，手动取消后等在途采集完成再退出，RGB读取拒绝忙状态和双目灰度数据。
- 待机页明确提示“单击开始识别，双击查看跑分”；保留固定大小字体/文本ROM，没有增加图像帧缓存。显式声明顶层原有时钟/锁定网络，消除隐式连线。

## 验证结果

- 7项RTL仿真：双目快照、前端寄存器、自动/手动优先、单/双击、淡入淡出、连续答题语音事件、57600像素AXI流式读与反压；全部通过。
- 实际Tcl列表131个RTL文件语法编译通过，并通过顶层接口展开：使用真实厂商基本时钟模型，DDR/PLL/读写帧缓冲四个IP使用原wrapper提取的端口/参数声明。剩余26条警告仅为已核对的FIFO/MMC未使用输出，新出现的宽度、输入遗漏或隐式网络警告会使检查失败。不是完整DDR/IP行为仿真，也不是面积/时序签核。
- 本机C测试：近/远/边界/无纹理/同步偏差/回绕；实际platform回调的配对元数据、分块读、超时、场景变化、按键取消；24轮模拟跑分；全部通过。
- 缩小缓存：36组检测头精确测试；四种构建各78组ADD/CONCAT/UPSAMPLE/POOL测试，覆盖768字节缓存边界、标量回退和输出保护字节。
- 实际stage4模型6张固定验证输入：18次Q16检测头与独立整数计算逐元素一致，25个其他CPU算子一致；卷积由整数软件oracle提供，不能称新候选已通过板测。
- 追加回归覆盖右相机无图像时RGB正常、页面零/多热码拒绝、Gray码逐拍单比特变化、等待配对期间界面服务与取消排空；7项RTL和3组本机C检查全部通过。
- 普通候选固件59340字节。隔离目录以不透明合成标定保留全部测距路径，固件66360字节、BSS末端0x80011ff0、剩8208字节堆栈空间，8KiB断言通过。合成标定构建仅作尺寸检查，禁止安装。
- 全路径固件静态调用链审计覆盖固定回调、直接调用及本地跳转表：最深估算6096字节，余量2112字节；测距→读像素→服务按键→刷新跑分页链同样纳入检查。尚未测板上堆栈高水位，不覆盖未来新增中断。
- 跑分页改用80字节单行缓冲，保持原MMIO写入及一次commit；刷新函数栈3552→144字节，无新增常驻BSS。重构前后24轮、520次提交、1830400字节画布逐字节一致，真实RTL渲染PNG也完全相同。全路径固件代码增加68字节，重新通过容量及堆栈门禁。
- 已从真实RTL渲染1280×720待机页两个动画相位及真实C画布驱动的跑分页，检查画面、动画变化与离页暂停；图片随新证据保存，不能称板上实拍。

最新证据入口：`evidence/records/optimization/continuation_022_rowstream_review/result.json`；较早的`continuation_022_code_review`和`continuation_022_hardening_review`原样保留，不作为最新源码身份。候选软件/ROM配套身份由`source/yolo/sources/firmware-source-manifest.json`记录；普通固件SHA256为`b4bcebd0932723a6f8ce70b0f09224e646292cda6a9fbcd2a404dc105802fde8`。复制ROM到候选目录不是烧录。801个历史冻结输入逐项SHA未改变；复用的算术/模型验证参与文件与旧证据逐字节匹配。

## 实物验收边界

尚无两镜头实拍标定，`stereo_calibration.h`保持verified=0，自动距离门控默认关闭；当前可交互行为采用用户允许的手动启停方案。仅知道基线约30mm不能推导真实焦距、畸变、左右外参或曝光同步。

帧起始计数来自共同CPU时钟，但不是曝光中心时间。`capture_stereo_pairs.py`明确导出frame_start_common_clock，不能修改标签冒充曝光同步。标定头导出工具最多设置CALIBRATED，不能自动设置距离/同步验证位。

待用户批准实施和下载后，才可实拍≥12对多姿态棋盘、核对重投影/极线误差、测尺验证200mm边界及曝光偏差，随后启用自动门控。无纹理、遮挡、搜索范围外（包括过近）及不可靠配对均返回UNKNOWN；不能承诺所有背景或任意近距离物品都能测出。

新全机资源、专用时钟MUX路径、最终各角STA、真实推理速度和现场声音/画面/机械均待后续验证。旧006仍有Slow hold -0.012ns，不把本次代码测试当作修复该时序问题的证明。

## 可重复的电脑检查

从仓库根目录运行。所有输出目录须为新目录；以下脚本只编译/仿真，不访问开发板：

```powershell
python project/trash_sorting/tools/check_stereo_candidate.py --source-dir project/trash_sorting/candidates/continuation_022/source --out build/recheck_stereo_rtl
python project/trash_sorting/tools/check_stereo_native.py --source-dir project/trash_sorting/candidates/continuation_022/source --out build/recheck_stereo_native --python-zig "C:/Users/Twinkle Nebula/AppData/Local/Programs/Python/Python310/python.exe"
build/trash_train_env/Scripts/python.exe project/trash_sorting/tools/test_stereo_tools.py
```

当前阶段不运行`build_pre_pnr.tcl`或`build_full.py`主程序；这些会进入FPGA实现。
