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
    parameter integer ENTRIES = 128         // direct-mapped sets, index derived from ENTRIES
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
    // ---- training at the real completion boundary (retire) ---------------
    input wire        train_valid,          // retire_fire
    input wire [31:0] train_pc,             // retired PC
    input wire        train_control,        // JAL / JALR / conditional branch
    input wire        train_uncond,         // JAL / JALR
    input wire        train_taken,          // actual direction
    input wire [31:0] train_target          // actual target
);
    localparam integer IDX_BITS = $clog2(ENTRIES);       // 5 for 32 entries
    localparam integer TAG_BITS = 32 - IDX_BITS - 2;     // 25 for 32 entries

    reg                  valid_q  [0:ENTRIES-1];
    reg [TAG_BITS-1:0]   tag_q    [0:ENTRIES-1];
    reg [31:0]           target_q [0:ENTRIES-1];
    reg                  uncond_q [0:ENTRIES-1];
    reg [1:0]            count_q  [0:ENTRIES-1];

    wire [IDX_BITS-1:0] fetch_idx = fetch_pc[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] fetch_tag = fetch_pc[31:IDX_BITS+2];
    wire fetch_hit = valid_q[fetch_idx] && (tag_q[fetch_idx]==fetch_tag);

    assign predict_taken  = fetch_hit && (uncond_q[fetch_idx] || count_q[fetch_idx][1]);
    assign predict_target = target_q[fetch_idx];

    // Identical rule on the chain port, so the prediction an instruction is
    // delivered with is bit-identical whichever port produced it.
    wire [IDX_BITS-1:0] fetch_idx2 = fetch_pc2[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] fetch_tag2 = fetch_pc2[31:IDX_BITS+2];
    wire fetch_hit2 = valid_q[fetch_idx2] && (tag_q[fetch_idx2]==fetch_tag2);

    assign predict_taken2  = fetch_hit2 && (uncond_q[fetch_idx2] || count_q[fetch_idx2][1]);
    assign predict_target2 = target_q[fetch_idx2];

    wire [IDX_BITS-1:0] train_idx = train_pc[IDX_BITS+1:2];
    wire [TAG_BITS-1:0] train_tag = train_pc[31:IDX_BITS+2];
    wire train_hit = valid_q[train_idx] && (tag_q[train_idx]==train_tag);

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i=0;i<ENTRIES;i=i+1) begin
                valid_q[i]  <= 1'b0;
                tag_q[i]    <= {TAG_BITS{1'b0}};
                target_q[i] <= 32'd0;
                uncond_q[i] <= 1'b0;
                count_q[i]  <= 2'b00;
            end
        end else if (train_valid && train_control) begin
            if (train_uncond) begin
                valid_q[train_idx]  <= 1'b1;
                tag_q[train_idx]    <= train_tag;
                target_q[train_idx] <= train_target;
                uncond_q[train_idx] <= 1'b1;
                count_q[train_idx]  <= 2'b11;
            end else if (train_taken) begin
                valid_q[train_idx]  <= 1'b1;
                tag_q[train_idx]    <= train_tag;
                target_q[train_idx] <= train_target;
                uncond_q[train_idx] <= 1'b0;
                // first sighting of a taken branch starts weakly taken, a
                // matching entry is strengthened and saturates at 11
                count_q[train_idx]  <= (train_hit && count_q[train_idx]!=2'b11)
                                       ? count_q[train_idx] + 2'b01 : 2'b10;
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
