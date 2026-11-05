"""Check implementation pins, clock constraints and PLL against board documents."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]


def check(root=ROOT,pcf=None,pll=None):
    root=Path(root)
    board=json.loads((root/'configuration/board_mes2l676.json').read_text(encoding='utf-8'))
    profile=json.loads((root/'configuration/profile.json').read_text(encoding='utf-8'))
    pcf=pcf if pcf is not None else (root/'constraints/pango_vexii.pcf').read_text(encoding='utf-8')
    pll=pll if pll is not None else (root/'rtl/board/pango_pll.sv').read_text(encoding='utf-8')
    ports={name:dict(re.findall(r'(\w+)=([^\s]+)',settings)) for name,settings in
           re.findall(r'^def_port\s+\{([^}]+)\}\s+([^\r\n]+)',pcf,re.M)}
    if set(ports)!=set(board['pins']):raise ValueError('Missing/extra board ports')
    for name,pin in board['pins'].items():
        settings=ports[name]
        if settings.get('LOC')!=pin:raise ValueError('Wrong board pin: '+name)
        if settings.get('IOSTANDARD')!=board['io_standard'] or float(settings['VCCIO'])!=board['vccio']:
            raise ValueError('Wrong board I/O voltage/standard: '+name)
    if not re.search(r'\bGTP_PPLL\s*#',pll):raise ValueError('PPLL limits apply only to PPLL')
    def number(name):
        values=re.findall(r'\.'+name+r'\(\s*([\d.]+)\s*\)',pll)
        if len(values)!=1:raise ValueError('Missing/ambiguous PLL parameter: '+name)
        value=float(values[0])
        if value<=0:raise ValueError('Positive PLL ratios required')
        return value
    fin=number('CLKIN_FREQ');pfd=fin/number('STATIC_RATIOI')
    vco=pfd*number('STATIC_RATIOM')*number('STATIC_RATIOF')
    fout=vco/number('STATIC_RATIO0')
    values={'input_mhz':fin,'pfd_mhz':pfd,'vco_mhz':vco,'output_mhz':fout}
    for key,(low,high) in board['ppll_limits'].items():
        if not low<=values[key]<=high:raise ValueError('Out-of-spec PPLL '+key)
    if fin!=board['input_mhz'] or profile['input_hz']!=int(fin*1000000):
        raise ValueError('PLL input frequency disagrees with board oscillator')
    if abs(profile['cpu_hz']-fout*1000000)>1 or fout<120:
        raise ValueError('PLL/profile target frequency mismatch')
    port=(root/'firmware/source/port/core_portme.c').read_text(encoding='utf-8')
    if int(re.search(r'#define CPU_HZ\s+(\d+)u',port)[1])!=profile['cpu_hz']:
        raise ValueError('Firmware clock disagrees with PLL')
    fdc=(root/'constraints/pango_vexii.fdc').read_text(encoding='utf-8')
    for name,frequency in [('board_clk',fin),('core_clk',fout)]:
        value=re.search(r'create_clock -name '+name+r' -period ([\d.]+)',fdc)
        if not value or abs(float(value[1])-1000/frequency)>0.000001:
            raise ValueError('Clock constraint disagrees with physical clock: '+name)
    return {'status':'PASS','board':board['board'],'pins_checked':len(ports),
            'input_mhz':fin,'pfd_mhz':pfd,'vco_mhz':vco,'cpu_mhz':fout,
            'board_verified':False,'scope':board['scope']}


if __name__=='__main__':print(json.dumps(check(),indent=2))
