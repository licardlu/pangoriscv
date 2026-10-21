//=============================================================================
// pangoriscv - rv32 core
// Module : rv32_regfile           File : rtl/core/rv32/rv32_regfile.v
// Rev    : 1.0                    Date : 2026-10-21
// Brief  : 4-read-port, 1-write-port register file + write-through bypass
//=============================================================================

// Dual issue needs four source operands per cycle (rs1/rs2 of both slots) and
// two destinations.  Two write ports would need two copies of every read
// array (distributed RAM has one write port each), so this file keeps ONE write
// port plus a one-entry write queue in the core: when both slots write, the
// younger result is queued and written on the following cycle.  Consumers of a
// queued result are covered by the exec-stage bypass network, so the queue is
// invisible to the ISA.
//
// Reads are synchronous (distributed RAM) and land at the end of S2, which is
// exactly where S3 needs them; the write-through mux below closes the
// write-in-S2 / read-in-S2 corner without stalling.
module rv32_regfile(
    input  wire        clk,
    input  wire        rst_n,
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
    reg [31:0] rfile [0:31];
    reg [31:0] q0, q1, q2, q3;
    integer i;

    // Data arrays are not reset (mistakes-log 16: per-entry reset forces the
    // distributed RAM into flip-flops and multiplies the area).
    always @(posedge clk) begin
        if (we && wa != 5'd0) rfile[wa] <= wd;
    end

    always @(posedge clk) begin
        q0 <= rfile[ra0];
        q1 <= rfile[ra1];
        q2 <= rfile[ra2];
        q3 <= rfile[ra3];
    end

    // The data output belongs to the address that was presented one cycle
    // earlier (the instruction now in RR), so both the x0 rule and the
    // write-through mux must use that delayed address.  Using the live address
    // instead returns the *next* instruction's register -- for a read of x0 that
    // is the uninitialised entry, which is exactly the first bug the ISA
    // regression caught in this core (x1 came out as 0xXXXXXXXX).
    reg [4:0] a0_d, a1_d, a2_d, a3_d;
    always @(posedge clk) begin
        a0_d <= ra0; a1_d <= ra1; a2_d <= ra2; a3_d <= ra3;
    end

    wire hit0 = we && (wa == a0_d) && (wa != 5'd0);
    wire hit1 = we && (wa == a1_d) && (wa != 5'd0);
    wire hit2 = we && (wa == a2_d) && (wa != 5'd0);
    wire hit3 = we && (wa == a3_d) && (wa != 5'd0);

    assign rd0 = (a0_d == 5'd0) ? 32'd0 : hit0 ? wd : q0;
    assign rd1 = (a1_d == 5'd0) ? 32'd0 : hit1 ? wd : q1;
    assign rd2 = (a2_d == 5'd0) ? 32'd0 : hit2 ? wd : q2;
    assign rd3 = (a3_d == 5'd0) ? 32'd0 : hit3 ? wd : q3;
endmodule
