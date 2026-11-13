# Launch from a NEW build directory. Sources are frozen there by the runner.
add_design servo_key_test_top.sv
add_design key_debounce4.sv
add_design servo_key_controller.sv
add_design servo_pwm4.sv
add_constraint servo_keys.fdc
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG676
compile -top_module servo_key_test_top -system_verilog
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr -gplace_seed 2 -groute_seed 2 -fix_hold_violation_iterations 50
report_timing
gen_bit_stream
puts "SERVO_KEY_DIAGNOSTIC_BITSTREAM_COMPLETE"
