#!/usr/bin/env python3
"""trace_diff.py -- 两份架构轨迹的逐条对账。

背景 (P10): 分支预测器打开后 CoreMark 跑飞, 但 smoke/pair 都过。
只比 (pc, instr) 看不出问题 —— 指令序列可以完全正确, 算出来的数却是错的。
所以 TB 现在按退休顺序落盘 (pc, instr, rd, we, wdata), 本脚本找第一条分歧。

用法:
    python tools/core_replica/trace_diff.py <ref.txt> <dut.txt> [-n 24] [--stop-pc 800037aa]

★ 必须用 --stop-pc 截断到"第一次真正碰外设"之前。
  固件里的 uart_send_char 会轮询 0x10001004 的状态寄存器, 那是**随时间变化**的
  物理量: 两遍跑得一样快慢不同, 读到的 occupancy 就不同, 于是分支方向不同、
  之后的指令流必然分叉 —— 那是时序差异, 不是逻辑错误。
  实测 (P10): 不截断时第一处分歧在 6028 条, 正好是这条轮询指令,
  而真正的 bug 在 409 条。加 --stop-pc 之后两边都只看确定性的前缀。

退出码: 0 = 完全一致; 1 = 有分歧; 2 = 文件读不了。
"""

# 固件里第一处"读外设"的指令 (uart_send_char 的 while 轮询)
DEFAULT_STOP_PC = "800037aa"

# 读周期计数器的 CSR: mcycle/mcycleh/minstret/minstreth (以及 user 版)
# 这些值**逐拍变化**, 两遍跑得不一样快就一定不同 —— 但它只是"读了个数",
# 不改变架构行为。对账时忽略它们的写回值。
CYCLE_CSRS = {0xB00, 0xB02, 0xB80, 0xB82, 0xC00, 0xC02, 0xC80, 0xC82}


def is_cycle_read(ins_hex):
    """判断这条指令是不是"读周期计数器"。只看编码, 不需要完整反汇编。"""
    try:
        iv = int(ins_hex, 16)
    except ValueError:
        return False
    if (iv & 0x7F) != 0x73:          # 不是 SYSTEM
        return False
    if ((iv >> 12) & 0x7) not in (1, 2, 3, 5, 6, 7):   # CSRRW/S/C 及其立即数形式
        return False
    return ((iv >> 20) & 0xFFF) in CYCLE_CSRS


def canon(rec):
    """把一条记录变成可比形式: 读周期计数器的写回值置 0。"""
    pc, ins, rd, we, wd = rec
    if we == "1" and is_cycle_read(ins):
        wd = "________"
    return (pc, ins, rd, we, wd)

import sys
import argparse


def load(path, limit=0, stop_pc=None):
    rows = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.split()
            if len(parts) == 6:      # 带周期号
                parts = parts[1:]
            if len(parts) != 5:
                continue
            if stop_pc and parts[0].lower() == stop_pc.lower():
                break
            rows.append(parts)
            if limit and len(rows) >= limit:
                break
    return rows


def fmt(rec):
    """把一条记录翻成人能看的样子。"""
    pc, ins, rd, we, wd = rec
    iv = int(ins, 16)
    # 粗判长度, 只为了打印对齐
    ln = 4 if (iv & 3) == 3 else 2
    return "pc=%s ins=%s(+%d) rd=x%-2d we=%s wd=%s" % (pc, ins, ln, int(rd), we, wd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("dut")
    ap.add_argument("-n", "--context", type=int, default=16,
                    help="分歧点前后各打印多少条 (默认 16)")
    ap.add_argument("--stop-pc", default=DEFAULT_STOP_PC,
                    help="遇到这个 pc 就停止比对 (默认 %s = 第一次读外设); "
                         "传 off 关闭" % DEFAULT_STOP_PC)
    a = ap.parse_args()

    stop = None if a.stop_pc.lower() in ("off", "none", "") else a.stop_pc

    try:
        ref = load(a.ref, stop_pc=stop)
        dut = load(a.dut, stop_pc=stop)
    except OSError as e:
        print("读文件失败: %s" % e)
        return 2

    n = min(len(ref), len(dut))
    for i in range(n):
        if canon(ref[i]) != canon(dut[i]):
            lo = max(0, i - a.context)
            print("=" * 78)
            print("第一条分歧: 第 %d 条退休指令 (0-based)" % i)
            print("=" * 78)
            for j in range(lo, i):
                print("  [%7d] 同   %s" % (j, fmt(ref[j])))
            print("-" * 78)
            print("  [%7d] 参考 %s" % (i, fmt(ref[i])))
            print("  [%7d] 被测 %s" % (i, fmt(dut[i])))
            # 后面几拍一起看, 判断是"漏一条"还是"内容错"
            for j in range(i + 1, min(i + 1 + 6, n)):
                mark = "同  " if canon(ref[j]) == canon(dut[j]) else "差  "
                print("  [%7d] %s 参考 %s" % (j, mark, fmt(ref[j])))
                if canon(ref[j]) != canon(dut[j]):
                    print("  [%7d] %s 被测 %s" % (j, " " * len(mark), fmt(dut[j])))
            print("=" * 78)
            print("判读提示:")
            print("  * 若被测这一条的 pc/instr 与参考相同、只是 wdata 不同 -> 数据通路/操作数错")
            print("  * 若被测这一条之后整体错位一条 -> 多提交或少提交了一条指令")
            print("  * 若 pc 开始不同 -> 控制流走了不同分支 (上一拍的分支结果错)")
            return 1

    print("前 %d 条完全一致%s" % (n, (" (已截断到 %s 之前)" % stop) if stop else ""))
    if len(ref) != len(dut):
        print("但长度不同: 参考 %d 条, 被测 %d 条 (其中一方被截断/提前结束)"
              % (len(ref), len(dut)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
