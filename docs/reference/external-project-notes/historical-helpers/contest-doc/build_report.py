from pathlib import Path
import shutil

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(r"D:\FPGA_Project\zi_guang_tong_chuang")
TEMPLATE = Path(r"C:\Users\Twinkle Nebula\Downloads\2658aa94-81d0-454c-b2ac-fc040ff2c01a.docx")
OUTPUT = ROOT / "青禾智能视觉垃圾分类系统技术文档.docx"
PHOTO_ROOT = Path(r"D:\应用\微信\xwechat_files\wxid_j0dvqgwb9th522_5cc6\temp\RWTemp\2026-11\763870349deb9a3f7555b681331613a1")

PHOTOS = {
    "whole": "bd1a1a28121c57b8ae66217747dc56f3.jpg",
    "close": "c909aa1bce4e14ee7aff6045ca9427ee.jpg",
    "watermelon": "9b1e03593f45d97c9129cb682bdd99bb.jpg",
    "board_buttons": "e89a1c4913ef4813fb4cf35ee0ce9503.jpg",
    "box_idle": "e3e32e9a365f849ee06f11097235f58b.jpg",
    "bins_display": "d6c0b8889df5076a4097b471580beee7.jpg",
    "fruit_package": "cc3e0298121cd45e1f5b14bdb2e15f6a.jpg",
    "board": "5d65dd0ceda650a66f73ccf8c209b465.jpg",
    "fruit_alt": "f75c698143ecf0a7471842c3ad4e3320.jpg",
    "idle": "4a590a88d1bab5ddcd1b88f6219f3086.jpg",
}


def set_run_font(run, size=10.5, bold=None, color="000000", name="宋体"):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), "Times New Roman" if name == "宋体" else name)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), "Times New Roman" if name == "宋体" else name)
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)
    if bold is not None:
        run.bold = bold


def shade(cell, fill):
    pr = cell._tc.get_or_add_tcPr()
    shd = pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcMar = tcPr.first_child_found_in("w:tcMar")
    if tcMar is None:
        tcMar = OxmlElement("w:tcMar")
        tcPr.append(tcMar)
    for side, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tcMar.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            tcMar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_table_borders(table, color="D9D9D9"):
    tblPr = table._tbl.tblPr
    borders = tblPr.first_child_found_in("w:tblBorders")
    if borders is None:
        borders = OxmlElement("w:tblBorders")
        tblPr.append(borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = qn(f"w:{edge}")
        element = borders.find(tag)
        if element is None:
            element = OxmlElement(f"w:{edge}")
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), "5")
        element.set(qn("w:space"), "0")
        element.set(qn("w:color"), color)


def set_repeat_table_header(row):
    trPr = row._tr.get_or_add_trPr()
    tblHeader = OxmlElement("w:tblHeader")
    tblHeader.set(qn("w:val"), "true")
    trPr.append(tblHeader)


doc = Document(TEMPLATE)
body = doc._element.body
for child in list(body):
    if child.tag != qn("w:sectPr"):
        body.remove(child)

normal = doc.styles["Normal"]
normal.font.name = "宋体"
normal._element.rPr.rFonts.set(qn("w:eastAsia"), "宋体")
normal.font.size = Pt(10.5)
normal.font.color.rgb = RGBColor(0, 0, 0)
normal.paragraph_format.line_spacing = 1.35
normal.paragraph_format.space_after = Pt(5)


def para(text="", *, align=None, first_indent=0.28, before=0, after=5, keep=False):
    p = doc.add_paragraph()
    if align is not None:
        p.alignment = align
    p.paragraph_format.first_line_indent = Inches(first_indent) if first_indent else None
    p.paragraph_format.space_before = Pt(before)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.line_spacing = 1.35
    p.paragraph_format.keep_together = True
    p.paragraph_format.keep_with_next = keep
    if text:
        run = p.add_run(text)
        set_run_font(run)
    return p


def heading(text, level=1):
    p = doc.add_paragraph()
    p.paragraph_format.first_line_indent = None
    p.paragraph_format.space_before = Pt(11 if level == 1 else 7)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(text)
    set_run_font(r, 14 if level == 1 else 11.5, True)
    return p


def table(headers, rows, widths=None, font_size=9.2):
    t = doc.add_table(rows=1, cols=len(headers))
    t.autofit = False
    set_table_borders(t)
    if widths:
        for row in t.rows:
            for i, width in enumerate(widths):
                row.cells[i].width = Inches(width)
    for i, value in enumerate(headers):
        cell = t.rows[0].cells[i]
        shade(cell, "DCE6F1")
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        set_cell_margins(cell)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(0)
        r = p.add_run(value)
        set_run_font(r, font_size, True)
    set_repeat_table_header(t.rows[0])
    for rowdata in rows:
        cells = t.add_row().cells
        for i, value in enumerate(rowdata):
            cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_margins(cells[i])
            if widths:
                cells[i].width = Inches(widths[i])
            p = cells[i].paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.15
            r = p.add_run(str(value))
            set_run_font(r, font_size)
    para("", first_indent=0, after=3)
    return t


def image(path, width, caption, *, keep=True):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(1)
    p.paragraph_format.keep_with_next = keep
    p.add_run().add_picture(str(path), width=Inches(width))
    cap = doc.add_paragraph()
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.space_after = Pt(6)
    cap.paragraph_format.keep_together = True
    r = cap.add_run(caption)
    set_run_font(r, 9, False, "444444")


def image_pair(first_key, first_caption, second_key, second_caption, width=2.60):
    t = doc.add_table(rows=1, cols=2)
    t.autofit = False
    for i, (key, cap) in enumerate(((first_key, first_caption), (second_key, second_caption))):
        cell = t.rows[0].cells[i]
        cell.width = Inches(2.8)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(2)
        p.add_run().add_picture(str(PHOTO_ROOT / PHOTOS[key]), width=Inches(width))
        q = cell.add_paragraph()
        q.alignment = WD_ALIGN_PARAGRAPH.CENTER
        q.paragraph_format.space_after = Pt(5)
        r = q.add_run(cap)
        set_run_font(r, 8.8, False, "444444")
    set_table_borders(t, "FFFFFF")


def code_block(lines):
    for line in lines.splitlines():
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.18)
        p.paragraph_format.first_line_indent = None
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.line_spacing = 1.08
        r = p.add_run(line if line else " ")
        set_run_font(r, 8.2, False, "222222", "Consolas")


def page_break():
    doc.add_page_break()


for key, name in PHOTOS.items():
    if not (PHOTO_ROOT / name).is_file():
        raise FileNotFoundError(PHOTO_ROOT / name)

# Cover and abstract
p = para("青禾智能视觉垃圾分类系统技术文档", align=WD_ALIGN_PARAGRAPH.CENTER, first_indent=0, before=2, after=14, keep=True)
for r in p.runs:
    set_run_font(r, 19, True)
heading("摘要", 2)
para("本作品以紫光同创 FPGA 开发平台为核心，构建面向生活垃圾识别与交互投放演示的嵌入式系统。CPU 子系统运行 CoreMark v1.0，板级 PLL 记录为 120.461538 MHz，完成 7000 次迭代，累计 1,309,328,358 ticks，实际运行 10.8693 s，五项 CRC 校验通过，按板测时钟换算得到 5.346252494 CoreMark/MHz。必须同时说明：同一基准实现的 PDS 时序报告估算频率为 100.9591 MHz，慢角 setup WNS 为 -1.604 ns，829 个失败端点，故该数值不是满足 120 MHz 时序门禁的完整竞赛成绩。视觉应用采用 YOLOv5n 六类垃圾模型，包含图像输入、卷积计算、软件检测框解码与屏幕叠加；实物演示还包括分类桶、舵机翻盖和开发板按键控制。现有照片展示物体检测框、软件界面、硬件连接与桶盖机构；摄像头识别率没有标准化测试数据。", after=9)

heading("第一部分 作品概述", 1)
heading("1.1 功能与特性", 2)
para("系统对输入图像中的垃圾目标执行检测，在显示界面叠加目标框和类别信息；用户可结合屏幕提示，通过开发板按键选择对应类别并驱动相应分类桶翻盖动作。样机由 FPGA 开发板、摄像头/显示链路、四格分类桶与舵机机构组成。当前实现定位为视觉识别与人工确认相结合的交互原型，不据此宣称无人值守的自动分拣。")
heading("1.2 应用领域", 2)
para("可用于智能垃圾投放宣传与教学演示、嵌入式视觉和 FPGA 加速课程实验，以及社区分类终端的原型验证。作品展示了从图像输入、目标检测、结果显示到人机交互和执行机构控制的完整技术链路；面向公共场景部署仍需进一步完成环境适应性、数据集覆盖、长期可靠性和安全评估。")
heading("1.3 主要技术特点", 2)
para("CPU 基准测试使用可综合并部署于 FPGA 的 RISC-V SoC，在硬件时钟下运行未裁剪的 CoreMark v1.0 负载，并以完整 ticks 与 CRC 作为计算依据。视觉端采用 YOLOv5n 六类模型；卷积层由可配置 FPGA 计算单元执行，图结构调度、检测头和边界框解码由 RV32 软件完成。系统同时连接显示、人机按键和舵机执行机构，以模块化数据通路完成识别与交互。")
heading("1.4 主要性能指标", 2)
table(["项目", "测试/配置", "结果", "口径说明"], [
    ["CPU PLL", "CoreMark 板测日志", "120.461538 MHz", "板级 CPU_HZ 记录；不等于 PDS 时序通过"],
    ["CoreMark v1.0", "7000 次；1,309,328,358 ticks", "5.346252494 CoreMark/MHz", "板测归一化值；对应实现时序门禁未过"],
    ["PDS 时序", "约束 8.301 ns", "估算 100.9591 MHz；WNS -1.604 ns", "慢角 setup 829 个失败端点"],
    ["运行与校验", "两次 UART 日志", "10.8693 s；CRC 五项通过", "运行时间合格，不能替代时序门禁"],
    ["YOLO 模型", "YOLOv5n，320 输入，六类别", "biodegradable/cardboard/glass/metal/paper/plastic", "类别覆盖有限，不含有害垃圾"],
    ["识别率/整机时序", "标准化精度测试/最终整机 STA", "未形成可报告的验收值", "不以样例图或独立 CPU 时序代替"],
], [0.85, 1.35, 1.8, 1.75], 8.0)
heading("1.5 主要创新点", 2)
para("（1）在国产 FPGA 上将 RISC-V CPU 基准测试与视觉应用结合，展示通用处理和专用卷积计算的协同路径。（2）采用可配置卷积计算结构复用不同网络层参数，并在软件侧完成检测解码与结果管理。（3）把识别画面、按键交互与多桶舵机机构集成为可操作演示原型。创新性表述限于现有实现，不将常规模型或器件本身作为原创成果。")
heading("1.6 设计流程", 2)
para("需求与模型类别确定 → FPGA 平台及 CPU/外设搭建 → 模型转换与算子映射 → 摄像头、显示和舵机接口联调 → CoreMark 和功能用例测试 → 板级样例演示与问题记录。CPU 跑分和视觉整机验证采用独立证据链，只有同一候选位流完成匹配测试后才可合并申报整机指标。")

heading("第二部分 系统组成及功能说明", 1)
heading("2.1 整体介绍", 2)
para("系统包含三条相互配合的数据/控制路径：图像路径由摄像头或演示图像进入预处理和 YOLO 卷积单元，检测头输出交由 CPU 解码并发送至显示叠加；交互路径由开发板按键输入类别选择，经 CPU 控制 GPIO/舵机接口驱动对应桶盖；基准路径在 CPU 上运行 CoreMark，并由 UART 输出 ticks、迭代次数和校验结果。显示用于呈现检测与状态信息，按键控制和视觉检测在演示中分别验证。")
table(["子系统", "输入", "处理", "输出/接口"], [
    ["视觉采集与显示", "摄像头图像/演示样例", "缩放、预处理、OSD 叠加", "屏幕实时画面"],
    ["CPU 与内存", "程序、图像任务、按键状态", "控制调度、检测头与结果处理", "AXI/MMIO、UART、GPIO"],
    ["YOLO 卷积计算", "层参数与特征张量", "运行时可配置卷积和量化运算", "特征图/检测头数据"],
    ["分类桶执行机构", "按键选择与类别映射", "舵机角度控制", "四个分类桶翻盖"],
    ["CPU 性能测试", "CoreMark v1.0 固件", "固定迭代并累计周期", "UART 结果及 CRC"],
], [1.1, 1.2, 2.1, 1.35], 8.5)
heading("2.2 硬件系统介绍", 2)
heading("2.2.1 硬件整体介绍", 2)
para("核心平台为紫光同创 PG2L100H 系列 FPGA 开发板（MES2L676-100HP 板卡），扩展连接显示屏、图像输入链路、按键和舵机分类桶。CPU/FPGA 负责任务调度与计算逻辑，板载/扩展存储承担程序及中间张量数据；外设通过数字接口与 FPGA 连接。最终引脚、电源和时钟配置以具体下载工程约束文件为准。")
heading("2.2.2 机械设计介绍", 2)
para("样机以四个不同颜色的独立桶格组成分类容器，每格设置可翻转上盖和舵机连杆。演示流程中，按键选择与桶格编号建立映射，控制对应舵机完成开盖/复位。机构照片可见桶体、舵机和连线；目前没有提供尺寸、公差、扭矩或循环寿命测试记录，因此不填写未经测量的机械参数。")
heading("2.2.3 电路各模块介绍", 2)
para("FPGA 开发板提供可编程逻辑、时钟、复位、用户按键和指示灯等资源；显示与图像接口连接至视频处理路径，舵机控制信号由数字输出送至执行机构，UART 用于 CPU 基准结果及调试信息。实物图可识别板载按键、扩展板和接口连线，但现有材料未附完整原理图、引脚表及电气测量结果；文中不臆造引脚编号或电平规格。")
heading("2.3 软件系统介绍", 2)
heading("2.3.1 软件整体介绍", 2)
para("软件由 CPU 启动和外设驱动、图像预处理、YOLO 图计算调度、检测框解码/NMS、显示结果管理以及 CoreMark 基准固件组成。YOLO 模型输入为 320×320，图中包含 85 个算子，其中卷积运算由 FPGA RTL 引擎承担，CPU 软件负责其余调度、头部处理及后处理。CoreMark v1.0 是独立 CPU 性能测试，不参与模型精度评估。")
heading("2.3.2 软件各模块介绍", 2)
para("视觉处理顺序为：采集或读取帧 → 缩放/填充与张量写入 → 逐层配置卷积引擎并执行模型图 → 读取三组检测头 → 置信度筛选、类别分数计算、候选框排序和 NMS → 坐标映射回原图 → 显示叠框。六类模型包括可降解物、纸板、玻璃、金属、纸张和塑料；这不是完整四分类法规映射，尤其没有有害垃圾类。按键与舵机映射由交互逻辑处理，不应将类别框直接等同于已经自动投放。")
para("核心软件实现摘录：每个算子根据张量地址读取输入，卷积层参数由运行时寄存器配置；后处理按类别保留候选框并通过 IoU 抑制重叠框。", after=2)
code_block("// extensions/yolo/rtl/conv_band_rt.v\nd_kx <= {16'd0, r_cin};\nd_ky <= wpadx * {16'd0, r_cin};\nd_col <= {{24{1'b0}}, r_stride} * {16'd0, r_cin};\n\n// extensions/yolo/sw/yolo_decode.c\nscores[c]=obj*sigmoid(raw[5+c]);\nif(overlap(&box,&work->candidates[c][j])>cfg->iou)\n    work->candidates[c][j].score=-1;")
para("以上为源码结构说明，具体综合、仿真和板测状态以对应证据记录为准。CPU 基准的板级串口核心记录如下：", before=4)
para("该次基准固件使用 GCC 15.2.0，编译目标为 RV32IMC/Zicsr/Zifencei，优化选项为 -O2，数据区位于栈；板级日志为最终运行与校验依据。")
code_block("CPU_HZ=120461538\nITERATIONS=7000\nTotal ticks      : 1309328358\nseedcrc          : 0xe9f5\ncrclist          : 0xe714\ncrcmatrix        : 0x1fd7\ncrcstate         : 0x8e3a\ncrcfinal         : 0x25b5\nCorrect operation validated.")

heading("第三部分 完成情况及性能参数", 1)
para("样机已经具备 FPGA 处理平台、屏幕识别界面、多格垃圾桶和舵机翻盖等组成部分。照片记录的是演示状态，不替代对全部类别、环境条件、识别准确率或长时间稳定性的量化验收。")
heading("3.1 整体介绍", 2)
image(PHOTO_ROOT / PHOTOS["whole"], 5.5, "图 1 作品整体连接与四格分类桶、显示屏和 FPGA 平台")
heading("3.2 工程成果", 2)
heading("3.2.1 机械成果", 2)
image_pair("close", "图 2 四格桶体和翻盖机构近景", "bins_display", "图 3 分类桶、显示界面与控制连接")
image(PHOTO_ROOT / PHOTOS["fruit_alt"], 5.1, "图 4 识别演示时显示屏与分类桶的联动展示状态")
heading("3.2.2 电路成果", 2)
image_pair("board", "图 5 FPGA 开发板及外设连接全貌", "board_buttons", "图 6 开发板用户按键和指示灯近景")
para("板卡实物可见用户按键、状态指示灯、扩展接口和连接线。基准测试日志将实际 CPU_HZ 记录为 120461538；该实测频率仅对应 CPU 跑分记录，不代表当前 YOLO 集成候选已完成同频全系统验收。")
heading("3.2.3 软件成果", 2)
image_pair("watermelon", "图 7 果蔬样例的目标框检测界面", "box_idle", "图 8 深色包装盒样例的检测界面")
page_break()
image_pair("fruit_package", "图 9 包装/果蔬样例识别显示画面", "idle", "图 10 图像等待输入的界面状态")
para("界面照片显示了检测框和类别/交互信息。照片用于说明功能演示，不足以计算准确率、召回率或混淆矩阵；正式精度评价需要固定测试集、逐类标注、统一置信度阈值和重复测量。")
heading("3.3 特性成果", 2)
para("CoreMark v1.0 跑分按完整 ticks 计算，避免使用 UART 显示的整数秒和整数 Iterations/Sec 反推。计算式为：总秒数 = 1,309,328,358 ÷ 120,461,538 = 10.869264827 s；CoreMark/MHz = 7000 × 120,461,538 ÷ 1,309,328,358 ÷ 1,000,000 = 5.346252494。两份同条件串口记录均给出相同 ticks 和五项 CRC，运行时间超过 10 s。")
table(["验收项", "现有证据", "结论"], [
    ["CoreMark 迭代/周期", "7000 次；1,309,328,358 ticks", "板测运行与计数有效"],
    ["CoreMark 校验", "seedcrc、crclist、crcmatrix、crcstate、crcfinal 均正确", "两次记录一致"],
    ["CPU PLL", "UART CPU_HZ=120461538", "板级运行时钟记录"],
    ["同版 CPU PDS STA", "约束 8.301 ns；估算 100.9591 MHz；WNS -1.604 ns", "829 个 setup 失败端点，未过门禁"],
    ["120 MHz YOLO 整机 STA", "候选 yolo120-006 慢角 setup WNS -1.540 ns；另有 DDR 违例", "未通过最终时序门禁"],
    ["视觉识别精度", "样例图片/画面，无标准标注统计", "不报告准确率"],
    ["显示与机械联动", "照片记录屏幕、按键、桶体及舵机样机", "功能演示证据；未形成完整可靠性指标"],
], [1.15, 2.85, 1.7], 8.0)
para("证据边界：CoreMark 记录中的 120.461538 MHz 是板级 PLL/CPU_HZ，不是最终时序报告给出的可收敛频率。同一基准实现的 PDS setup WNS 为 -1.604 ns，估算频率 100.9591 MHz，829 个端点失败；因此 5.346252494 是按板测时钟归一化的记录值，不可表述为达到 120 MHz 时序要求的完整竞赛成绩。另一个 CPU 候选的 STA 记录虽通过，但尚无匹配的板测成绩，不能与此跑分拼接。YOLO120 整机候选也存在 setup/DDR 失败端点，未作为可靠发布位流。")
para("竞赛波形与性能分析仍需补齐：当前材料未包含与该跑分实现匹配的 ILA 流水线波形，因此本文不推算 IPC、停顿/冲刷占比或瓶颈归因。正式提交应补充同一实现的 ILA 取证、资源报告和时序报告。", before=4)

heading("第四部分 总结", 1)
heading("4.1 可扩展之处", 2)
para("后续工作可围绕统一的四类垃圾标签体系补充并重新训练数据集，扩大不同背景、光照、遮挡和目标尺度的标注测试；完成摄像头、显示、DDR 与 YOLO 核心的整机多角 setup/hold 和跨时钟域验收；增加按键去抖、舵机限位与故障保护，并统计识别延迟、分类指标和连续运行稳定性。所有新数据应关联同一工程快照和位流哈希。")
heading("4.2 心得体会", 2)
para("本作品的实现过程说明，嵌入式视觉系统并非单一模型推理问题。模型能否部署，取决于 CPU、片上存储、外部存储访问、视频时序、量化运算和接口协同；展示画面能够出现检测框，也不能代替可重复的精度评测和时序闭合。CPU 性能测试同样需要明确基准版本、迭代数、完整周期数、硬件频率和 CRC，避免用截断后的显示字段造成偏差。\n\n在系统联调中，开发板、按键、显示屏、桶盖和连线共同构成最终可见的工程成果。实物演示有助于检查模块之间的控制关系，也暴露了可靠性、光照适应和类别覆盖等仍需完善之处。后续应继续保持证据与结论一一对应：仿真用于验证逻辑，静态时序用于验证实现约束，板级日志用于证明运行，带标注的数据集用于评价识别质量。只有这些结果在同一发布版本上闭环，才能形成完整、可信的竞赛性能报告。")

heading("第五部分 参考文献", 1)
for item in [
    "[1] Embedded Microprocessor Benchmark Consortium. CoreMark v1.0 Benchmark and Reporting Rules[EB/OL]. https://github.com/eembc/coremark.",
    "[2] Waterman A, Asanović K, eds. The RISC-V Instruction Set Manual, Volume I: Unprivileged Architecture, Version 20191213[Z]. RISC-V Foundation, 2019.",
    "[3] Ultralytics. YOLOv5 Documentation and Source Code[EB/OL]. https://github.com/ultralytics/yolov5.",
    "[4] 紫光同创. 全国大学生嵌入式芯片与系统设计竞赛 2026 FPGA 赛道选题指南[Z].",
    "[5] 紫光同创. 盘古 676 系列 100Pro+ 开发板实验指导手册[Z].",
]:
    p = para(item, first_indent=0, after=4, keep=True)
    p.paragraph_format.left_indent = Inches(0.25)

# Normalize direct font/color on preserved header/footer text while leaving logo art untouched.
for section in doc.sections:
    for part in (section.header, section.footer):
        for p in part.paragraphs:
            for run in p.runs:
                if run.text:
                    run.font.color.rgb = RGBColor(0, 0, 0)

doc.core_properties.title = "青禾智能视觉垃圾分类系统技术文档"
doc.core_properties.subject = "FPGA RISC-V CoreMark 性能与视觉垃圾分类应用"
doc.core_properties.author = ""
doc.core_properties.last_modified_by = ""
doc.core_properties.keywords = ""
doc.core_properties.comments = ""
doc.save(OUTPUT)
print(OUTPUT)
