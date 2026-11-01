// tb_mac_array -- functional check of the explicit multiplier array.
//
// Everything is driven from a small LFSR so the test needs no vector files, and
// the expected value is recomputed in the testbench with plain integer
// arithmetic.  This verifies the RTL; it says nothing about the netlist.  The
// netlist is checked structurally by requiring Total APMs == C*L in PDS.
`timescale 1ns/1ps

module tb_mac_array;

    localparam integer L = 8;
    localparam integer C = 8;

    reg                clk = 0;
    reg                rstn = 0;
    reg                clear = 0;
    reg                valid = 0;
    reg  [C*32-1:0]    bias_bus = 0;
    reg  [L*8-1:0]     a_bus = 0;
    reg  [C*L*8-1:0]   w_bus = 0;
    wire [C*32-1:0]    sum_bus;

    mac_array #(.L(L), .C(C)) dut (
        .clk(clk), .rstn(rstn), .clear(clear), .valid(valid),
        .bias_bus(bias_bus), .a_bus(a_bus), .w_bus(w_bus), .sum_bus(sum_bus));

    always #5 clk = ~clk;

    // reference model
    integer exp_sum [0:C-1];
    integer errors = 0;
    integer i, j, t;
    reg [31:0] lfsr;

    function [31:0] nxt;
        input [31:0] s;
        begin
            nxt = {s[30:0], s[31] ^ s[21] ^ s[1] ^ s[0]};
        end
    endfunction

    task step_lfsr;
        begin
            lfsr = nxt(lfsr);
        end
    endtask

    integer occ, lane;
    integer av, wv;

    initial begin
        lfsr = 32'h1234_5678;
        repeat (4) @(posedge clk);
        rstn = 1;

        // bias load
        for (occ = 0; occ < C; occ = occ + 1) begin
            step_lfsr;
            bias_bus[occ*32 +: 32] = lfsr;
            exp_sum[occ] = lfsr;
        end
        @(posedge clk);
        clear = 1;
        @(posedge clk);
        clear = 0;

        // 3 K-slices of random data
        for (t = 0; t < 3; t = t + 1) begin
            step_lfsr;
            a_bus = {L{lfsr[7:0]}};
            for (lane = 0; lane < L; lane = lane + 1) begin
                step_lfsr;
                a_bus[lane*8 +: 8] = lfsr[7:0];
            end
            for (occ = 0; occ < C; occ = occ + 1) begin
                for (lane = 0; lane < L; lane = lane + 1) begin
                    step_lfsr;
                    w_bus[(occ*L + lane)*8 +: 8] = lfsr[7:0];
                    av = $signed(a_bus[lane*8 +: 8]);
                    wv = $signed(lfsr[7:0]);
                    exp_sum[occ] = exp_sum[occ] + av * wv;
                end
            end
            valid = 1;
            @(posedge clk);
            valid = 0;
            @(posedge clk);
        end

        @(posedge clk);
        for (occ = 0; occ < C; occ = occ + 1) begin
            if ($signed(sum_bus[occ*32 +: 32]) !== exp_sum[occ]) begin
                errors = errors + 1;
                $display("MISMATCH oc=%0d got=%0d exp=%0d",
                         occ, $signed(sum_bus[occ*32 +: 32]), exp_sum[occ]);
            end
        end

        if (errors == 0)
            $display("MAC-ARRAY-PASS  %0d channels x %0d lanes, 3 slices", C, L);
        else
            $display("MAC-ARRAY-FAIL  %0d mismatches", errors);
        $finish;
    end

endmodule
