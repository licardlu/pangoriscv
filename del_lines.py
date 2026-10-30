import re
import os
from collections import defaultdict

raw_text = """
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\control\\csr_file.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/control/csr_file.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\csr_file.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/csr_file.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\csr_file.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/csr_file.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\control\\csr_file.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/control/csr_file.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\control\\csr_file.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/control/csr_file.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\core_config.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/core_config.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\core_config.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/core_config.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\core_config.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/core_config.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\core_config.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/core_config.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\core_config.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/core_config.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/core_defs.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/core_defs.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/core_defs.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/core_defs.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/core_defs.vh:1>) L1-L9
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/core_defs.vh:28>) L28-L28
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/core_defs.vh:28>) L28-L28
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/core_defs.vh:28>) L28-L28
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/core_defs.vh:28>) L28-L28
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\core_defs.vh](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/core_defs.vh:28>) L28-L28
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\decode\\decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/decode/decoder.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/decoder.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/decoder.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\decode\\decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/decode/decoder.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\decode\\decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/decode/decoder.v:1>) L1-L12
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\decode\\rvc_decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/decode/rvc_decoder.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\rvc_decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/rvc_decoder.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\rvc_decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/rvc_decoder.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\decode\\rvc_decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/decode/rvc_decoder.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\decode\\rvc_decoder.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/decode/rvc_decoder.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\execute\\alu.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/execute/alu.v:1>) L1-L11
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\alu.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/alu.v:1>) L1-L11
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\alu.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/alu.v:1>) L1-L11
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\execute\\alu.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/execute/alu.v:1>) L1-L11
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\execute\\alu.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/execute/alu.v:1>) L1-L11
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\execute\\branch_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/execute/branch_unit.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\branch_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/branch_unit.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\branch_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/branch_unit.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\execute\\branch_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/execute/branch_unit.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\execute\\branch_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/execute/branch_unit.v:1>) L1-L10
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\execute\\operand_select.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/execute/operand_select.v:1>) L1-L16
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\operand_select.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/operand_select.v:1>) L1-L16
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\execute\\operand_select.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/execute/operand_select.v:1>) L1-L16
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\execute\\operand_select.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/execute/operand_select.v:1>) L1-L16
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\execute\\shifter.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/execute/shifter.v:1>) L1-L8
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\shifter.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/shifter.v:1>) L1-L8
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\shifter.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/shifter.v:1>) L1-L8
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\execute\\shifter.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/execute/shifter.v:1>) L1-L8
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\execute\\shifter.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/execute/shifter.v:1>) L1-L8
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\lsu\\load_store_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/lsu/load_store_unit.v:1>) L1-L21
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\load_store_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/load_store_unit.v:1>) L1-L21
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\load_store_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/load_store_unit.v:1>) L1-L21
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\lsu\\load_store_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/lsu/load_store_unit.v:1>) L1-L21
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\lsu\\load_store_unit.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/lsu/load_store_unit.v:1>) L1-L21
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\core\\regfile\\integer_regfile.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/core/regfile/integer_regfile.v:1>) L1-L13
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\integer_regfile.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/integer_regfile.v:1>) L1-L13
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core\\regfile\\integer_regfile.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core/regfile/integer_regfile.v:1>) L1-L13
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\core_0251\\regfile\\integer_regfile.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/core_0251/regfile/integer_regfile.v:1>) L1-L13
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\rtl\\pango_cpu_top.sv](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/rtl/pango_cpu_top.sv:1>) L1-L7
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\project\\core_replica\\sources\\pango_cpu_top.sv](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/project/core_replica/sources/pango_cpu_top.sv:1>) L1-L7
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\pango_cpu_top.sv](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/pango_cpu_top.sv:1>) L1-L7
- [D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v2_dual\\pango_cpu_top.sv](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v2_dual/pango_cpu_top.sv:1>) L1-L7
[D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\integer_regfile.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/integer_regfile.v:1>) L1-L14
[D:\\FPGA_Project\\zi_guang_tong_chuang\\pangoriscv\\wip\\v1_core\\operand_select.v](<D:/FPGA_Project/zi_guang_tong_chuang/pangoriscv/wip/v1_core/operand_select.v:1>) L1-L14
"""

def parse_items(text):
    pat = re.compile(r'<(D:/[^:]+):\d+>.*?L(\d+)-L(\d+)')
    items = []
    for fp, s_str, e_str in pat.findall(text):
        win_fp = fp.replace("/", "\\")
        s = int(s_str)
        e = int(e_str)
        if s > e:
            s, e = e, s
        items.append((win_fp, s, e))
    return items

def remove_line_range(filepath, start, end):
    with open(filepath, "r", encoding="utf-8", newline="") as f:
        lines = f.readlines()

    new_lines = []
    for idx, line in enumerate(lines, start=1):
        if not (start <= idx <= end):
            new_lines.append(line)

    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.writelines(new_lines)
    return True

def main():
    todo = parse_items(raw_text)
    group = defaultdict(list)
    for fp, s, e in todo:
        group[fp].append((s,e))

    print("=== 待处理列表 ===")
    for fp, ranges in sorted(group.items()):
        print(fp, " -> 区间列表:", ranges)

    confirm = input("\n⚠️  无备份！确认删除上面所有行区间？输入 YES 执行，其他退出：")
    if confirm != "YES":
        print("已取消，无修改。")
        return

    for fp, ranges in group.items():
        if not os.path.exists(fp):
            print(f"[WARN] 文件不存在：{fp}")
            continue
        # 按结束行降序，从后往前删，防止行号错位
        sorted_ranges = sorted(ranges, key=lambda x: -x[1])
        for (s,e) in sorted_ranges:
            try:
                remove_line_range(fp, s, e)
                print(f"[OK] {fp} 删除 L{s}-L{e}")
            except Exception as ex:
                print(f"[ERR] {fp} L{s}-L{e} 失败: {ex}")

    print("\n全部处理完成！⚠️ 本次没有生成任何备份文件！")

if __name__ == "__main__":
    main()