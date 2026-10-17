add_design "E:/file/pango/tinyriscv_axi4/.sim_runs/platform-led-20261010/counter_led.v"
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
add_constraint "E:/file/pango/tinyriscv_axi4/.sim_runs/platform-led-20261010/counter_led.fdc"
compile -top_module counter_led
synthesize -ads -selected_syn_tool_opt 2
dev_map
add_constraint "E:/file/pango/tinyriscv_axi4/.sim_runs/platform-led-20261010/counter_led.pcf"
pnr
report_timing
gen_bit_stream
