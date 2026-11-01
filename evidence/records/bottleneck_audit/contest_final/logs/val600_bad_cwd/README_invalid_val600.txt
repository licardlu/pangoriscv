INVALID val600 attempts (2026-10-18 17:09-17:22): pds_shell was started with CWD=platform/pango_native,
so the PDS project file was created at platform/pango_native/build.pds instead of build/pango_native/build.pds.
Compile therefore ran with the wrong impl directory and could not open program.hex/data.hex:
  C: Verilog-3001: [..axi_ram.sv(line number: 118)] Cannot open specified data file "program.hex"
  C: Verilog-3001: [..axi_ram.sv(line number: 118)] Cannot open specified data file "data.hex"
  Board check: compile log not found at .../build/pango_native/compile/run.log; memory load not verified.
These bitstreams have empty program/data memory and MUST NOT be used for board runs.
cand invalid sbit sha256: F5D328F9E8848795B26DB3706735B9BAECC5611288DE1FA2E1B87AE60FCDDA08
b0 invalid sbit sha256: 4BB23C280729510DE8FE7BD6E2105B4AD50B14638254A2DB4C903B217F0E0694
Logs: contest_final/logs/pds_cand_val600.log, contest_final/logs/pds_b0_val600.log
Stray outputs moved here (cand/, b0/). Rebuilt cleanly with CWD=build/pango_native.
