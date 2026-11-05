// dram_probe -- does PDS actually infer block RAM (DRM) for our access pattern?
//
// The previous full-layer build put 39,936 LUTs into distributed RAM and used
// zero DRM, which is what killed it (135 % LUT).  The cause was combinational
// read.  This probe puts both styles side by side in one build so the mapping
// report answers the question directly instead of relying on a code-style rule:
//
//   u_sync : address registered, data registered   -> expected DRM
//   u_comb : data available combinationally         -> expected LUTRAM
//
// Both are 1024 x 8.  Neither array has a reset: resetting a memory array
// prevents block-RAM inference in most tools.
//
// After synthesis the acceptance criterion is
//     u_sync -> DRM != 0 and LUTRAM does not grow
//     u_comb -> DRM  == 0
// and the engine will only use the u_sync template.
`timescale 1ns/1ps

module dram_probe_sync #(
    parameter integer AW = 10,
    parameter integer DW = 8
)(
    input  wire          clk,
    input  wire          we,
    input  wire [AW-1:0] waddr,
    input  wire [DW-1:0] wdata,
    input  wire [AW-1:0] raddr,
    output reg  [DW-1:0] rdata
);
    reg [DW-1:0] mem [0:(1<<AW)-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end
endmodule


module dram_probe_comb #(
    parameter integer AW = 10,
    parameter integer DW = 8
)(
    input  wire          clk,
    input  wire          we,
    input  wire [AW-1:0] waddr,
    input  wire [DW-1:0] wdata,
    input  wire [AW-1:0] raddr,
    output wire [DW-1:0] rdata
);
    reg [DW-1:0] mem [0:(1<<AW)-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];      // combinational read: LUTRAM territory
endmodule


// Top with LFSR-driven inputs so the probe has few IO pins (the device only has
// 300 and a wide memory interface would trip DRC-0018 before mapping).
module dram_probe_top(
    input  wire       clk,
    input  wire       rstn,
    output reg  [15:0] sig
);
    reg  [31:0] lfsr;
    reg  [9:0]  raddr, waddr;
    reg  [7:0]  wdata;
    reg         we;
    wire [7:0]  rs, rc;

    always @(posedge clk) begin
        if (!rstn) begin
            lfsr  <= 32'h1;
            raddr <= 0; waddr <= 0; wdata <= 0; we <= 1'b0; sig <= 0;
        end
        else begin
            lfsr  <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            raddr <= lfsr[9:0];
            waddr <= lfsr[19:10];
            wdata <= lfsr[27:20];
            we    <= lfsr[31];
            sig   <= sig ^ {8'd0, rs} ^ {rc, 8'd0};
        end
    end

    dram_probe_sync u_sync (.clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                            .raddr(raddr), .rdata(rs));
    dram_probe_comb u_comb (.clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
                            .raddr(raddr), .rdata(rc));
endmodule
