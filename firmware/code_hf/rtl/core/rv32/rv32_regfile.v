//=============================================================================
// pangoriscv - rv32 core (5.2 CoreMark/MHz @126 MHz rewrite)
// Module : rv32_regfile           File : rtl/core/rv32/rv32_regfile.v
// Rev    : 2.0                    Date : 2026-10-21
// Brief  : 4-read-port, 1-write-port register file, asynchronous read
//=============================================================================

// Rev 2.0 changes the read from synchronous to asynchronous and that is the
// whole point of the module: the old synchronous version needed the read data
// to be latched into the next stage together with the instruction, so the
// operand/instruction pairing silently depended on "ID advances every cycle".
// The first load-use stall broke it -- the read pointer drifted to the *next*
// instruction while the pipeline register held the current one, and the ALU
// then executed with a stranger's operand (rs2 read as x0's zero, or as an
// uninitialised entry: `sub x19,x17,x11` produced x17-0, `add x18` produced X).
//
// With an asynchronous read the address is driven by the instruction that is
// actually in the execute stage.  A frozen stage freezes its address, so the
// data follows for free -- there is no alignment left to get wrong, and the
// whole class of bug disappears instead of being patched a third time
// (mistakes-log 21).
//
// Area: four 32x32 arrays (one copy per read port, because distributed RAM has
// one read port per copy) is 4*32 = 128 LUTs for the P2 dual-issue core and
// 64 LUTs for the single-issue P1 build (unused ports are pruned by
// synthesis).  The synchronous version spent 4*32 + 4*5 = 148 flip-flops on
// the same job, so this is smaller as well as correct.
//
// x0 is not a register: reads of it are forced to zero and writes to it are
// dropped, which keeps rfile[0] out of the write path entirely.
module rv32_regfile(
    input  wire        clk,
    input  wire [4:0]  ra0,
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    input  wire [4:0]  ra3,
    output wire [31:0] rd0,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    output wire [31:0] rd3,
    input  wire        we,
    input  wire [4:0]  wa,
    input  wire [31:0] wd
);
    // One array per read port.  Not reset: per-entry reset would force these
    // into flip-flops and multiply the area (mistakes-log 16).
    // The port-0 copy keeps the name `rfile` on purpose: the ISA testbench
    // snapshots the architectural register file through that hierarchical name,
    // and all four copies are written with identical data, so it *is* the
    // architectural state.
    reg [31:0] rfile [0:31];
    reg [31:0] m1 [0:31];
    reg [31:0] m2 [0:31];
    reg [31:0] m3 [0:31];

    wire wr = we && (wa != 5'd0);

    always @(posedge clk) begin
        if (wr) begin
            rfile[wa] <= wd;
            m1[wa] <= wd;
            m2[wa] <= wd;
            m3[wa] <= wd;
        end
    end

    // Write-through: a value written on this edge is visible to a read issued in
    // the same cycle.  Without it a consumer one instruction behind the producer
    // would read the stale entry (the write lands at the end of the cycle).
    wire hit0 = wr && (wa == ra0);
    wire hit1 = wr && (wa == ra1);
    wire hit2 = wr && (wa == ra2);
    wire hit3 = wr && (wa == ra3);

    assign rd0 = (ra0 == 5'd0) ? 32'd0 : hit0 ? wd : rfile[ra0];
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : hit1 ? wd : m1[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : hit2 ? wd : m2[ra2];
    assign rd3 = (ra3 == 5'd0) ? 32'd0 : hit3 ? wd : m3[ra3];
endmodule
