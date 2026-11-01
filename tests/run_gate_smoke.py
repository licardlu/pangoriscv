"""Post-synthesis functional smoke test using the user's installed PDS models.

No vendor model source is copied into this package; no SDF/board verification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]

def reference_sources(directory):
    """Validate all frozen HDL, including includes, before comparing outputs."""
    directory=Path(directory).resolve()
    entries=json.loads((directory/'input_snapshot.json').read_text())['files']
    hashes={entry['path']:entry['sha256'] for entry in entries}
    for relative,digest in hashes.items():
        if relative=='source_list.tcl' or relative.startswith('sources/'):
            path=(directory/relative).resolve()
            if not path.is_relative_to(directory) or not path.is_file():
                raise ValueError('Missing frozen source: '+relative)
            if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
                raise ValueError('Frozen source changed: '+relative)
    result=[]
    for original in re.findall(r'^\s+\{([^{}\r\n]+)\}$',
                               (directory/'source_list.tcl').read_text(),re.M):
        path=Path(original).resolve()
        if not path.is_relative_to(directory/'sources') or path.relative_to(directory).as_posix() not in hashes:
            raise ValueError('Unbound frozen source: '+original)
        if path.name!='pango_pll.sv':result.append(path)
    if not result:raise ValueError('No frozen HDL sources')
    return result

def run(cmd,out,name):
    with (out/name).open('w',encoding='utf-8')as log:
        code=subprocess.call(list(map(str,cmd)),cwd=out,stdout=log,stderr=subprocess.STDOUT)
    text=(out/name).read_text(errors='replace')
    if code or re.search(r'\*\* (?:Error|Fatal)',text):raise RuntimeError(name+'\n'+text[-3500:])
    return text

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--build',required=True)
    p.add_argument('--name',required=True)
    p.add_argument('--cycles',type=int,default=200000)
    p.add_argument('--modelsim',type=Path,default=Path('D:/modeltech64_10.6e/win64'))
    p.add_argument('--pds-models',type=Path,default=Path('D:/pango/PDS_2022.2-SP6.1/arch/vendor/pango/verilog/simulation'))
    a=p.parse_args()
    out=ROOT/'build'/a.name;out.mkdir(parents=True,exist_ok=False)
    net=ROOT/'build'/a.build/'synthesize/pango_vexii_top_syn.vm'
    frozen_sources=reference_sources(ROOT/'build'/a.build)
    net_text=net.read_text()
    pll_stub='module pango_pll(input wire clk, input wire rst_n, output wire core_clk, output wire locked); assign core_clk=clk; assign locked=rst_n; endmodule'
    # PLL is deliberately excluded from this zero-delay digital functional test.
    # Both DUT clocks are forced to the same test clock in tb_gate_smoke.sv.
    stubbed,count=re.subn(r'(?ms)^module pango_pll\b.*?^endmodule\b',pll_stub,net_text,count=1)
    if count!=1:raise ValueError('Expected one identifiable PLL wrapper')
    (out/'netlist.vm').write_text(stubbed)
    (out/'pll_stub.v').write_text(pll_stub)
    shutil.copy2(ROOT/'tests/tb_gate_smoke.sv',out/'tb.sv')
    for f in (ROOT/'firmware/image').glob('*.bin'):shutil.copy2(f,out/f.name)
    models=set(re.findall(r'^\s*(GTP_\w+)\b',(out/'netlist.vm').read_text(),re.M));models.add('GTP_GRS')
    # Resolve transitive model dependencies (e.g. LUT6D -> MUX2LUT6 -> UDP).
    pending=list(models)
    while pending:
        name=pending.pop()
        f=a.pds_models/(name+'.v')
        for child in set(re.findall(r'\b((?:GTP|INT)_\w+)\b',f.read_text(errors='replace'))):
            if child not in models and (a.pds_models/(child+'.v')).is_file():
                models.add(child);pending.append(child)
    model_files=[a.pds_models/(n+'.v') for n in sorted(models)]
    # The primitive LUT/APM models instantiate these installed UDP/helpers.
    model_files = sorted(set(model_files) | set(a.pds_models.glob('INT_*.v')))
    for f in model_files:
        if not f.is_file():raise ValueError('Missing installed vendor model: '+str(f))
    record={'netlist_sha256':hashlib.sha256(net.read_bytes()).hexdigest(),
       'reference_source':'exact frozen synthesis inputs from build/input_snapshot.json',
       'reference_source_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in frozen_sources},
       'model_paths_and_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in model_files},
       'simulation_netlist_sha256':hashlib.sha256((out/'netlist.vm').read_bytes()).hexdigest(),
       'scope':'post-synthesis digital functional with PLL wrapper stubbed and aligned clock; no SDF, PLL or board validation','cycles':a.cycles}
    (out/'inputs.json').write_text(json.dumps(record,indent=2))
    ms=a.modelsim
    for lib in ['work','reference','gate','pango']:run([ms/'vlib.exe',lib],out,lib+'_vlib.log')
    run([ms/'vlog.exe','-sv','-work','pango','+incdir+'+str(a.pds_models),*model_files],out,'models_compile.log')
    files=list(frozen_sources)
    files.append(out/'pll_stub.v')
    run([ms/'vlog.exe','-sv','-work','reference',*files],out,'reference_compile.log')
    run([ms/'vlog.exe','-sv','-work','gate','netlist.vm'],out,'netlist_compile.log')
    run([ms/'vlog.exe','-sv','tb.sv'],out,'tb_compile.log')
    text=run([ms/'vsim.exe','-c','-L','pango','+notimingchecks','work.gate_smoke_config',f'+MAX_CYCLES={a.cycles}',
         '-do','onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0'],out,'simulate.log')
    if text.count('TEST_PASS gate_external_lockstep')!=1:raise RuntimeError('No positive pass marker')
    print(text[-1800:])

if __name__=='__main__':main()
