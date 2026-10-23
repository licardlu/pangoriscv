#!/usr/bin/env python
"""Apply the P20 redirect cut to rtl/core/ifu_axi.v (the frequency cut).

Why a script and not a .patch: the change was measured on 2026-10-23 (see
docs/plan-v13-120mhz-physical.md sections 6.4 and 7) but was reverted from the
tree before a clean `git diff` could be captured, so this applier is the
authority.  It is line-based on purpose -- the surrounding comment block has
been rewritten several times and a text match is fragile.

Effect (measured, sim20_O2, 20 iterations, all five CRCs correct):

    BRAM + BTB64 (delivered)      3,776,288 ticks   5.2963
    + D$ 2KB -> 4KB               3,714,882 ticks   5.3834   (see dcache-4kb.patch)
    + this cut                    3,810,700 ticks   5.2483

Routed worst path drops 25.429 ns -> 20.613 ns (build P23b), and the -7 ps hold
residual disappears.  Cost is +4,791 ticks/iteration, so it only fits the 5.2
budget together with the D$ doubling.

Usage:  python docs/patches/apply-redirect-cut.py [--check]
"""
import io
import sys

PATH = "firmware/code/rtl/core/ifu_axi.v"

OLD_FETCH = """    wire [31:0] fetch_ptr=redirect_valid?redirect_pc:
                          (transparent?fetch_pc:next_pc_q);"""

NEW_FETCH = """    // P20 redirect cut: `redirect_valid?redirect_pc:` removed.  Keeping it made
    // redirect_pc drive, in the SAME cycle, the I$ request address, local_fault
    // (-> eng_req_valid) and -- through the fetch-queue write enable -- the FIFO
    // clock enables.  The request now goes out one cycle later through
    // `transparent`; `next_pc_q` is pre-seeded from redirect_pc for the case
    // where a stale response still blocks `transparent`.
    wire [31:0] fetch_ptr=transparent?fetch_pc:next_pc_q;"""

OLD_REQ = """                         (redirect_valid ? redir_issue
                                         : ((stale_cnt_q==0)&&(reserved<=(DEPTH-2))));"""

NEW_REQ = """                         (stale_cnt_q==0)&&(reserved<=(DEPTH-2));"""

OLD_BOOK = """            if(redirect_valid&&issue) begin
                pcf0_q<=redirect_pc; pdf0_q<=chain_next; pdf0_q2<=chain2_next;
                ocnt_q<=2'd1;
                next_pc_q<=expect_pair?packet_next:chain_next;
            end"""

NEW_BOOK = """            // P20: no request is raised on the flush edge any more, so there is
            // nothing to register into pcf0_q here.  Seed the prefetch pointer
            // with the target instead.
            next_pc_q<=redirect_pc;"""


def main() -> int:
    check = "--check" in sys.argv
    text = io.open(PATH, encoding="utf-8").read()
    for old, new, name in ((OLD_FETCH, NEW_FETCH, "fetch_ptr"),
                           (OLD_REQ, NEW_REQ, "eng_req_valid"),
                           (OLD_BOOK, NEW_BOOK, "redirect bookkeeping")):
        if text.count(old) != 1:
            print("FAIL %s: found %d occurrences (already applied?)"
                  % (name, text.count(old)))
            return 1
        text = text.replace(old, new)
    if check:
        print("OK all three hunks match; nothing written")
        return 0
    io.open(PATH, "w", encoding="utf-8", newline="").write(text)
    print("applied redirect cut to %s" % PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
