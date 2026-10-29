"""Compile the actual top and check reset/PLL with Pango's simulation primitive."""
from pathlib import Path
from build import ROOT, TOOLS, run

output = ROOT/'build/board_rtl_checks'
output.mkdir(exist_ok=False)
ms = Path(TOOLS.get('modelsim', 'D:/modeltech64_10.6e/win64'))
pds = Path(TOOLS.get('pds', 'D:/pango/PDS_2022.2-SP6.1/bin/pds_shell.exe')).parent.parent
run([ms/'vlib.exe', 'work'], output, output/'vlib.log')
run([ms/'vlog.exe', '-sv', pds/'arch/vendor/pango/verilog/simulation/GTP_PPLL.v',
     ROOT/'rtl/pango_pll.sv', ROOT/'rtl/pango_reset.sv', ROOT/'rtl/pango_vexii_top.sv',
     ROOT/'rtl/generated/MicroSoc.v', ROOT/'tb/tb_reset.sv', ROOT/'tb/tb_pll.sv'],
    output, output/'compile.log')
for test in ['reset','pll']:
    text = run([ms/'vsim.exe','-c','work.tb_'+test,'-do',
                'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'],
               output, output/(test+'.log'))
    if 'TEST_PASS '+test not in text:
        raise RuntimeError('missing pass marker for '+test)
print('Actual top compiled; reset and vendor PLL simulation passed.')
