//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : branch_predictor       File : rtl/core/branch_predictor.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Branch predictor: 32-entry direct-mapped BTB with 2-bit counters, two lookup ports
//=============================================================================

// ---------------------------------------------------------------------------
// branch_predictor -- the predictor dynamic branch prediction (plan spec section 5).
//
// A 32-entry direct-mapped BTB.  Every entry holds
//     valid, full tag (PC[31:7]), target, uncond (JAL/JALR) and a 2-bit
//     saturating counter.
// Lookup uses PC[6:2] as the set index and compares the *complete* tag, so two
// PCs that share an index but differ above bit 6 never alias: a same-index
// different-tag stream simply replaces the entry instead of predicting the
// other PC's target.
//
// Direction rule (spec): counter 00/01 -> predict not taken, 10/11 -> taken.
// JAL/JALR entries are marked uncond and always predict taken.
//
// Training happens exactly once per *retired* control-flow instruction:
// train_valid is the retire pulse, so instructions killed by a redirect, a trap
// or a halt never train the table.
//
// A prediction can only ever redirect the fetch stage; the architectural
// redirect at retire plus the young-stage flush keep the architectural result
// identical to a predict-not-taken build.  That equivalence is what the
// PREDICT_ENABLE on/off regression checks.
// ---------------------------------------------------------------------------
`include "defines.v"

module branch_predictor #(
    // Measured trade-off (see evidence/records/optimization/P4/measurement.md):
    // 32 entries is the delivered default because enlarging the BTB costs far more
    // resource than it buys in speed. 64/128 remain available as knobs:
    //   ENTRIES  ticks(20it)  cycles delta  mispredict  LUT
    //      32     15,316,450        -          154,553   12,572
    //      64     15,059,217     -1.68%        116,246  ~14,500 (extrapolated)
    //     128     15,035,153     -1.84%        112,723   16,572 (measured)
    parameter integer ENTRIES = 64          // P19: 32 -> 64; the block-RAM move freed 2,797 LUT
)(
    input wire clk,
    input wire rst_n,
    // ---- lookup for the PC currently being fetched (combinational) --------
    input  wire [31:0] fetch_pc,
    output wire        predict_taken,
    output wire [31:0] predict_target,
    // ---- second lookup port: the IFU prefetch chain (T1) ------------------
    // The flop-based table makes this port nearly free: no register file read
    // port is shared, only a second index/tag compare.
    input  wire [31:0] fetch_pc2,
    output wire        predict_taken2,
    output wire [31:0] predict_target2,
    // ---- third lookup port: the second word of an 8 B fetch pair ----------
    // CoreMark pairs an ALU-class instruction with the branch that follows it
    // often enough that the pair's successor must be known in the same cycle as
    // the first word's.  A flop-based table makes a third read port only a third
    // index/tag compare (no shared RAM port).
    input  wire [31:0] fetch_pc3,
    output wire        predict_taken3,
    output wire [31:0] predict_target3,
    // ---- training at the real completion boundary (retire) ---------------
    input wire        train_valid,          // retire_fire
    input wire [31:0] train_pc,             // retired PC
    input wire        train_control,        // JAL / JALR / conditional branch
    input wire        train_uncond,         // JAL / JALR
    input wire        train_taken,          // actual direction
    input wire [31:0] train_target          // actual target
);
    localparam integer IDX_BITS = $clog2(ENTRIES);       // 5 for 32 entries
    // A BTB entry only ever describes a control transfer that lives inside the
    // execution region, so neither the tag nor the target needs a full 32-bit
    // PC.  Deriving both widths from PGM_BYTES keeps the table correct if the
    // program memory ever grows, and drops the storage from 25+32 bits to 7+14
    // bits per entry (area workstream M3: 32 entries, ~1,150 FF).
    // See docs/architecture/module-area-plan.md M3.
    parameter  integer PGM_BYTES = 32768;                    // 0x8000 = EXEC_BYTES
    localparam integer ADDR_BITS = $clog2(PGM_BYTES);        // 14
    localparam integer TAG_BITS = ADDR_BITS - IDX_BITS - 2;  // 7

    reg                  valid_q  [0:ENTRIES-1];
    reg [TAG_BITS-1:0]   tag_q    [0:ENTRIES-1];
    reg [ADDR_BITS-1:0]  target_q [0:ENTRIES-1];
    reg                  uncond_q [0:ENTRIES-1];
    reg [1:0]            count_q  [0:ENTRIES-1];

    // A PC outside [0, PGM_BYTES) must never hit: with the narrow tag it would
    // otherwise alias onto an in-range entry and invent a prediction for an
    // address that is supposed to take the normal out-of-range fault path.
    function in_range;
        input [31:0] pc;
        begin
            in_range = (pc[31:ADDR_BITS]=={(32-ADDR_BITS){1'b0}});
        end
    endfunction

    wire [IDX_BITS-1:0] fetch_idx = fetch_pc[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] fetch_tag = fetch_pc[ADDR_BITS-1:IDX_BITS+2];
    wire fetch_hit = in_range(fetch_pc) && valid_q[fetch_idx] && (tag_q[fetch_idx]==fetch_tag);

    assign predict_taken  = fetch_hit && (uncond_q[fetch_idx] || count_q[fetch_idx][1]);
    assign predict_target = {{(32-ADDR_BITS){1'b0}}, target_q[fetch_idx]};

    // Identical rule on the chain port, so the prediction an instruction is
    // delivered with is bit-identical whichever port produced it.
    wire [IDX_BITS-1:0] fetch_idx2 = fetch_pc2[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] fetch_tag2 = fetch_pc2[ADDR_BITS-1:IDX_BITS+2];
    wire fetch_hit2 = in_range(fetch_pc2) && valid_q[fetch_idx2] && (tag_q[fetch_idx2]==fetch_tag2);

    assign predict_taken2  = fetch_hit2 && (uncond_q[fetch_idx2] || count_q[fetch_idx2][1]);
    assign predict_target2 = {{(32-ADDR_BITS){1'b0}}, target_q[fetch_idx2]};

    wire [IDX_BITS-1:0] fetch_idx3 = fetch_pc3[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] fetch_tag3 = fetch_pc3[ADDR_BITS-1:IDX_BITS+2];
    wire fetch_hit3 = in_range(fetch_pc3) && valid_q[fetch_idx3] && (tag_q[fetch_idx3]==fetch_tag3);

    assign predict_taken3  = fetch_hit3 && (uncond_q[fetch_idx3] || count_q[fetch_idx3][1]);
    assign predict_target3 = {{(32-ADDR_BITS){1'b0}}, target_q[fetch_idx3]};

    wire [IDX_BITS-1:0] train_idx = train_pc[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] train_tag = train_pc[ADDR_BITS-1:IDX_BITS+2];
    wire train_hit = in_range(train_pc) && valid_q[train_idx] && (tag_q[train_idx]==train_tag);
    // A target outside the region cannot be represented in ADDR_BITS; refuse it
    // and invalidate the entry instead of storing a truncated (wrong) PC.
    wire train_target_ok = in_range(train_target);

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i=0;i<ENTRIES;i=i+1) begin
                valid_q[i]  <= 1'b0;
                tag_q[i]    <= {TAG_BITS{1'b0}};
                target_q[i] <= {ADDR_BITS{1'b0}};
                uncond_q[i] <= 1'b0;
                count_q[i]  <= 2'b00;
            end
        end else if (train_valid && train_control && in_range(train_pc)) begin
            if (train_uncond) begin
                valid_q[train_idx]  <= train_target_ok;
                tag_q[train_idx]    <= train_tag;
                target_q[train_idx] <= train_target[ADDR_BITS-1:0];
                uncond_q[train_idx] <= 1'b1;
                count_q[train_idx]  <= 2'b11;
            end else if (train_taken) begin
                valid_q[train_idx]  <= train_target_ok;
                tag_q[train_idx]    <= train_tag;
                target_q[train_idx] <= train_target[ADDR_BITS-1:0];
                uncond_q[train_idx] <= 1'b0;
                // Saturating 2-bit counter: a newly seen taken branch starts
                // weakly taken (10); a hit strengthens it and **saturates at 11**.
                // The old form `(hit && count!=11) ? count+1 : 2'b10` folded an
                // already-saturated entry (11) back to 10 on every taken outcome,
                // so an always-taken branch sat at 10 and a single not-taken
                // outcome flipped the prediction one step too early
                // (independent review R04).
                count_q[train_idx]  <= (!train_hit)                   ? 2'b10 :
                                       (count_q[train_idx]==2'b11)     ? 2'b11 :
                                                                         count_q[train_idx]+2'b01;
            end else if (train_hit) begin
                // a not-taken branch needs no entry of its own: weaken ours.
                // (tag+index is the whole PC, so an uncond entry can never be
                // trained as not taken)
                if (count_q[train_idx]!=2'b00)
                    count_q[train_idx] <= count_q[train_idx] - 2'b01;
            end
        end
    end
endmodule
