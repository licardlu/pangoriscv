//=============================================================================
// tb_rv32i6 -- G1 oracle: run the real firmware image on the new core and dump
//              every retire (pc, inst) so it can be diffed against the golden
//              trace of the delivered core.
//=============================================================================
// The golden trace is <repo>/.sim_runs/coremark_sim/<tag>/retire_trace.txt from
// tools/run_coremark_sim.py ("<idx> <pc> <inst>" per line).  If the new core
// retires the same (pc, inst) stream for the first N instructions, decode, ALU,
// branch resolution, load/store and the interlock are all right -- no need to
// wait for the whole CoreMark run or for the UART report.
`timescale 1ns/1ps

module tb_rv32i6;
    reg clk = 1'b0;
    reg rst_n = 1'b0;

    wire [31:0] imem_addr;
    wire [63:0] imem_data;
    wire [31:0] dmem_addr;
    wire        dmem_we;
    wire [2:0]  dmem_size;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    wire        retire_fire;
    wire [31:0] retire_pc, retire_inst;
    wire [31:0] debug_data;

    always #4 clk = ~clk;          // 125 MHz nominal for a functional run

    rv32i6_top u_core(
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_we(dmem_we), .dmem_size(dmem_size),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
        .retire_fire(retire_fire), .retire_pc(retire_pc),
        .retire_inst(retire_inst),
        .debug_addr(5'd0), .debug_data(debug_data)
    );

    rv32i6_mem #(
        .PROG_HEX("program.hex"), .DATA_HEX("data.hex")
    ) u_mem(
        .clk(clk),
        .imem_addr(imem_addr), .imem_data(imem_data),
        .dmem_addr(dmem_addr), .dmem_we(dmem_we), .dmem_size(dmem_size),
        .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );

    integer fd, n_retire;
    integer cycles;
    reg [31:0] last_pc;
    integer same_pc;

    initial begin
        n_retire = 0; cycles = 0; last_pc = 32'hFFFF_FFFF; same_pc = 0;
        fd = $fopen("rv32i6_trace.txt", "w");
        if (fd == 0) begin
            $display("FATAL: cannot open rv32i6_trace.txt");
            $finish;
        end
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
    end

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (retire_fire) begin
            $fdisplay(fd, "%0d %08x %08x", n_retire, retire_pc, retire_inst);
            n_retire <= n_retire + 1;
        end
        // the firmware ends in `j .`: stop when the fetch PC stops moving
        if (retire_pc == last_pc) same_pc <= same_pc + 1;
        else same_pc <= 0;
        last_pc <= retire_pc;

        if (n_retire >= 400000 || same_pc > 2000 || cycles > 6000000) begin
            $display("TB_DONE retires=%0d cycles=%0d", n_retire, cycles);
            $fclose(fd);
            $finish;
        end
    end
endmodule
