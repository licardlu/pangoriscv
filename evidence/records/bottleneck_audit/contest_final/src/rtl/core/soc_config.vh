//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : soc_config             File : rtl/core/soc_config.vh
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Build-time configuration switches: CACHE_ENABLE, PREDICT_ENABLE, PERF_ENABLE
//=============================================================================

`ifndef PANGO_SOC_CONFIG_VH
`define PANGO_SOC_CONFIG_VH
// ---------------------------------------------------------------------------
// Compile-time feature switches (contest plan sections 13/15/16/31).
//
// default default: every switch is OFF, so the delivered reference behaviour is what
// these sources produce unless this file (or the tool command line) enables a
// feature. Enabling a feature therefore always requires a rebuild - never a
// runtime register write - which is what makes the "switch off == default" and
// "switch on/off architectural result identical" comparisons meaningful.
//
//   CACHE_ENABLE   : the caches two-way set-associative I/D caches + AXI4 INCR bursts
//   PREDICT_ENABLE : the predictor dynamic branch prediction (BTB + 2-bit counters)
//   PERF_ENABLE    : the caches and predictor performance counters at 0x60002000
//
// This file lives in rtl/core, which is on the compiler include path for both
// ModelSim runs and the PDS `compile` step, so every module sees one state.
//
// Repository default = default (all three switches off): a plain rebuild of this tree
// reproduces the default reference of the project report.  The delivered
// bitstream (full-feature) is built explicitly with all three switches on, and every A/B
// comparison in the report is produced the same way:
// a build wrapper that passes -Defines CACHE,PERF,PREDICT and the performance
// image directory to the synthesis tool
// ---------------------------------------------------------------------------
`define CACHE_ENABLE
`define PREDICT_ENABLE
`define PERF_ENABLE
`endif
