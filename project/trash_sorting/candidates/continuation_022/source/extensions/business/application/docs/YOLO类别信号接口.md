# YOLO 类别信号接口

`yolo/sources/049_video_ai_frontend.v` 在原 OSD/MMIO 邮箱之外导出以下 CPU 时钟域信号。下游 RTL 应在 `result_commit=1` 时采样。

| 输出 | 位宽 | 含义 |
| --- | --- | --- |
| `result_commit` | 1 | CPU 对 `0x94` 写 bit 0=1 且邮箱空闲，被接受后高一个 `cpu_clk` 周期；空快照也产生事件 |
| `result_valid` | 1 | 本次被接受快照是否存在至少一个有效框 |
| `result_class_id` | 8 | 最小有效槽号的原始类别编号；空快照为 0 |
| `result_count` | 4 | 八个槽中有效框数量，范围 0..8 |

元数据保持到下次被接受提交，忙时写提交不会产生事件或改变元数据。当前软件解码结果按分数排序，故最小有效槽为最高分的可显示结果；多框时保留计数供应用层决定是否拒绝歧义输入。修改 staging 寄存器不产生新事件。

这个接口表示推理提交，不表示持续目标在场。OSD 仍独立执行按帧保框和两秒超时；当前软件会跳过完全空结果的显示提交，因此不能用 `result_valid` 持续高电平证明目标仍在。应用若需要目标在场状态，应使用 `result_commit` 驱动独立的时间窗或同步 OSD 有效状态。

`rtl/yolo_class_to_bin.v` 为组合映射，输入 `result_valid`、`result_class_id`，输出 `bin_valid`、`bin_code[2:0]`。`bin_code=0` 表示无可用桶码；1 蓝（可回收）、2 灰（其他）、3 红（有害）、4 绿（厨余/有机）。参数 `CLASS0_BIN` 到 `CLASS5_BIN` 可独立覆盖各原始类，0 可禁用某一类映射。

当前六类模型的默认映射为：0 biodegradable→4；1 cardboard、2 glass、3 metal、4 paper、5 plastic→1。模型没有灰桶和红桶对应的训练类，代码不为它们伪造识别结果。上述映射输出和按键直控外设测试互相独立。

验证于 2026-11-03：ModelSim 编译 048_camera_snapshot、049_video_ai_frontend、yolo_class_to_bin 与三个 testbench，`tb_yolo_result_commit`、`yolo_class_to_bin_tb`、`tb_bbox_osd` 均通过。覆盖 staging 不泄漏、提交事件单周期、邮箱 busy 拒绝、空快照、首个有效槽、计数、多对象、非法类、参数覆盖、OSD 保持与超时清框。未执行布局布线、改引脚约束或烧写。
