//=============================================================================
// pangoriscv - phase1 acceptance extension test
// Module : tb_defines_probe   File : tb/unit/tb_defines_probe.sv
// Brief  : Build-configuration evidence for the phase1 test run.  This probe is
//          compiled by the SAME vlog command line that compiles the RTL for the
//          phase1 regression (including the explicit +define switches), so it
//          prints the macro state the RTL compilation saw for that invocation.
//          It deliberately does not include soc_config.vh: with the include the
//          file's own `define lines would always win and the report could not
//          distinguish the command line from the file state.
//=============================================================================
`timescale 1ns/1ps
module tb_defines_probe;

    initial begin
`ifdef CACHE_ENABLE
        $display("DEFINE CACHE_ENABLE=ON");
`else
        $display("DEFINE CACHE_ENABLE=OFF");
`endif
`ifdef PREDICT_ENABLE
        $display("DEFINE PREDICT_ENABLE=ON");
`else
        $display("DEFINE PREDICT_ENABLE=OFF");
`endif
`ifdef PERF_ENABLE
        $display("DEFINE PERF_ENABLE=ON");
`else
        $display("DEFINE PERF_ENABLE=OFF");
`endif
        $display("TEST_PASS DEFINES_PROBE");
        $finish;
    end

endmodule
