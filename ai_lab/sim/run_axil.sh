#!/bin/bash
# Regression for conv_engine_axil: the same three shapes as run_rt.sh, but every
# layer description now arrives as 17 AXI4-Lite register writes and the result is
# read back out of the DDR model.  This is the CPU's view of the accelerator.
set -u
cd "$(dirname "$0")" || exit 1
MODEL=/e/donwload/win64
export PATH=$MODEL:$PATH
CASES=${*:-rt1 rt2 rt3}

fail=0
for c in $CASES; do
    mkdir -p inc
    cp "../gen/tb_params_$c.vh" inc/tb_params.vh || exit 1
    rm -rf workax && vlib workax >/dev/null 2>&1
    vlog -quiet -work workax +incdir+inc \
        ../tb/tb_engine_axil.v ../rtl/conv_engine_axil.v \
        ../rtl/conv_band_rt.v ../rtl/mac_array.v >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "== $c COMPILE-FAIL"
        vlog -work workax +incdir+inc ../tb/tb_engine_axil.v ../rtl/conv_engine_axil.v \
            ../rtl/conv_band_rt.v ../rtl/mac_array.v 2>&1 | grep -i error | head -5
        fail=1; continue
    fi
    out=$(vsim -c -quiet -work workax tb_engine_axil -do "run -all; quit" 2>&1)
    line=$(echo "$out" | grep -E "AXI-AXIL-(PASS|FAIL)" | tail -1)
    if echo "$line" | grep -q PASS; then
        echo "== $c  $line"
    else
        fail=1
        echo "== $c  ${line:-NO-RESULT}"
        echo "$out" | grep -E "MISMATCH|TIMEOUT|FAIL:" | head -6
    fi
done
exit $fail
