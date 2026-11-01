"""Exercise the actual extracted direction-table write process."""
import argparse
from pathlib import Path
import re
import shutil
from run_rtl import run,validate_result

ROOT=Path(__file__).resolve().parents[1]


def main():
    p=argparse.ArgumentParser();p.add_argument('--name',required=True);a=p.parse_args()
    out=ROOT/'build'/a.name;out.mkdir(parents=True,exist_ok=False)
    text=(ROOT/'rtl/core/sections/024_LsuL1Plugin.vh').read_text()
    # Stop at the following read process, retaining the complete write process.
    found=re.search(r'  always @\(posedge socCtrl_systemClk\) begin\s+if\(_zz_6\).*?(?=\n  always @\(posedge socCtrl_systemClk\))',text,re.S)
    if not found:raise ValueError('Missing direction table write process')
    body=found[0]
    for before,after in [('socCtrl_systemClk','clk'),('_zz_6','enable'),
       ('GSharePlugin_logic_mem_writes_0_payload_address','address'),
       ('_zz_GSharePlugin_logic_mem_banks_0_port','data'),
       ('GSharePlugin_logic_mem_banks_0','memory'),
       ('GSharePlugin_logic_initializer_busy','init_busy'),
       ('LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 1]','bank')]:body=body.replace(before,after)
    (out/'write_extracted.sv').write_text('module extracted_write(input clk,enable,init_busy,input [11:0] address,input [1:0] bank,input [7:0] data,output [7:0] value);\nreg [7:0] memory [0:4095];assign value=memory[address];\n'+body+'\nendmodule\n')
    shutil.copy2(ROOT/'tests/tb_predictor_write.sv',out/'tb.sv')
    ms=Path('D:/modeltech64_10.6e/win64');run([ms/'vlib.exe','work'],out,'vlib.log')
    run([ms/'vlog.exe','-sv','write_extracted.sv','tb.sv'],out,'compile.log')
    text=run([ms/'vsim.exe','-c','tb_predictor_write','-do','onbreak {quit -code 1};run -all;quit -code 0'],out,'simulate.log')
    validate_result('write_test',text);print(text[-700:])


if __name__=='__main__':main()
