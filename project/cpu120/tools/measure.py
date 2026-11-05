"""Assess UART output; simulation never constitutes a board result."""
import argparse
import json
from pathlib import Path
import re


def assess(text):
    lines=[]
    for line in text.splitlines():
        if line.startswith('# UART: '):line=line[8:]
        elif line.startswith('UART: '):line=line[6:]
        lines.append(line.rstrip('\r'))
    text='\n'.join(lines)
    if len(re.findall(r'^BENCH_DONE$',text,re.M))!=1:
        raise ValueError('Exactly one completed run required')
    def number(pattern,base=10):
        values=re.findall(pattern,text,re.M)
        if len(values)!=1:raise ValueError('Missing/duplicate field: '+pattern)
        return int(values[0],base)
    hz=number(r'^CPU_HZ=(\d+)$'); iterations=number(r'^Iterations\s*:\s*(\d+)$')
    ticks=number(r'^Total ticks\s*:\s*(\d+)$')
    if hz<=0 or iterations<=0 or ticks<=0:raise ValueError('Positive counts required')
    if number(r'^ITERATIONS=(\d+)$')!=iterations:raise ValueError('Iteration fields disagree')
    if number(r'^TICKS_HI=(\d+)$')*(1<<32)+number(r'^TICKS_LO=(\d+)$')!=ticks:
        raise ValueError('Full tick counters disagree')
    actual={name:number(r'^(?:\[0\])?'+name+r'\s*:\s*0x([0-9a-fA-F]+)$',16)
            for name in ['seedcrc','crclist','crcmatrix','crcstate','crcfinal']}
    expected={'seedcrc':0xe9f5,'crclist':0xe714,'crcmatrix':0x1fd7,'crcstate':0x8e3a}
    final={20:0x4983,100:0x988c,7000:0x25b5}.get(iterations)
    crc_valid=final is not None and actual['crcfinal']==final and all(actual[k]==v for k,v in expected.items())
    seconds=ticks/hz;score=iterations*1000000/ticks
    official=bool(crc_valid and seconds>=10 and 'Correct operation validated.' in text
                  and not re.search(r'ERROR!|Errors detected|TRAP cause=',text,re.I))
    return {'iterations':iterations,'cpu_hz':hz,'ticks':ticks,'seconds':seconds,
            'coremark_per_mhz':score,'crc':actual,'crc_valid':bool(crc_valid),
            'official_valid':official,'target_achieved':False,'board_verified':False,
            'score_target_met':score>=5.6,'note':'Target additionally requires matching bitstream, final STA and board evidence.'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path)
    a=p.parse_args(); print(json.dumps(assess(a.log.read_text(errors='replace')),indent=2))
