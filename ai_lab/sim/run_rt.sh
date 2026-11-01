#!/bin/bash
# Regression for conv_band_rt: three shapes, byte-exact against the Python
# integer reference.  A case only counts if it prints BAND-RT-PASS.
#
#   ./run_rt.sh            run all three
#   ./run_rt.sh rt1        run one (rt1 = k1, rt2 = deep 3x3, rt3 = first layer)
set -u
cd "$(dirname "$0")/engine" || exit 1
MODEL=/e/donwload/win64
export PATH=$MODEL:$PATH
CASES=${*:-rt1 rt2 rt3}

rm -rf workrt && vlib workrt >/dev/null 2>&1 || exit 1

fail=0
for c in $CASES; do
    cp "../../gen/tb_params_$c.vh" tb_params.vh || exit 1
    rm -rf workrt && vlib workrt >/dev/null 2>&1
    vlog -quiet -work workrt ../../tb/tb_band_rt.v ../../rtl/conv_band_rt.v ../../rtl/mac_array.v >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "== $c COMPILE-FAIL"; vlog -work workrt ../../tb/tb_band_rt.v ../../rtl/conv_band_rt.v ../../rtl/mac_array.v 2>&1 | grep -i error | head -5
        fail=1; continue
    fi
    out=$(vsim -c -quiet -work workrt tb_band_rt -do "run -all; quit" 2>&1)
    line=$(echo "$out" | grep -E "BAND-RT-(PASS|FAIL)" | tail -1)
    if echo "$line" | grep -q PASS; then
        echo "== $c  $line"
    else
        fail=1
        echo "== $c  ${line:-NO-RESULT}"
        echo "$out" | grep -E "TIMEOUT|STUCK|MISMATCH|FAIL:|FIRSTWR|WRITES|LOADED" | head -12
    fi
done
exit $fail
