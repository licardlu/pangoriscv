# conv3x3_core standalone resource + timing probe (PDS 2022.2)
set RTL "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/pangoriscv/ai/rtl"
set CST "C:/Users/lenovo/WorkBuddy/2026-10-27-00-18-16/pangoriscv/ai/conv3x3.fdc"

add_design "$RTL/conv3x3_top.v"
add_design "$RTL/conv3x3_core.v"
add_constraint "$CST"

set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module conv3x3_top
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr
report_timing
gen_bit_stream
