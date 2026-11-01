"""Compile the actual lookup and learning expressions against a 10-bit oracle."""
import argparse
from pathlib import Path
import re
import shutil
from run_rtl import run, validate_result

ROOT=Path(__file__).resolve().parents[1]


def main():
    p=argparse.ArgumentParser();p.add_argument('--name',required=True);a=p.parse_args()
    out=ROOT/'build'/a.name;out.mkdir(parents=True,exist_ok=False)
    expressions=[]
    for filename,lhs,temp,pc,hist in [
        ('030_FetchL1Plugin.vh','fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH',
         '_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH','fetch_logic_ctrls_0_down_Fetch_WORD_PC','fetch_logic_ctrls_0_down_Prediction_BRANCH_HISTORY'),
        ('036_BtbPlugin.vh','GSharePlugin_logic_onLearn_hash','_zz_GSharePlugin_logic_onLearn_hash',
         'LearnPlugin_logic_learn_payload_pcOnLastSlice','LearnPlugin_logic_learn_payload_history')]:
        text=(ROOT/'rtl/core/sections'/filename).read_text()
        expr=re.search(r'assign '+lhs+r' = ([^;]+);',text)[1]
        expr=expr.replace(temp+'_1',temp+'[6]').replace(temp+'_2',temp+'[7]')
        expr=expr.replace(temp,'pc_slice').replace(pc,'pc').replace(hist,'history')
        expressions.append(expr)
    (out/'hash_extracted.sv').write_text('module extracted_hash(input [31:0] pc,input [11:0] history,output [11:0] lookup_hash,learn_hash);\nwire [11:0] pc_slice=pc[14:3];\nassign lookup_hash='+expressions[0]+';\nassign learn_hash='+expressions[1]+';\nendmodule\n')
    shutil.copy2(ROOT/'tests/tb_predictor_hash.sv',out/'tb.sv')
    ms=Path('D:/modeltech64_10.6e/win64')
    run([ms/'vlib.exe','work'],out,'vlib.log')
    run([ms/'vlog.exe','-sv','hash_extracted.sv','tb.sv'],out,'compile.log')
    log=run([ms/'vsim.exe','-c','tb_predictor_hash','-do','onbreak {quit -code 1}; run -all; quit -code 0'],out,'simulate.log')
    validate_result('hash',log);print(log[-1000:])


if __name__=='__main__':main()
