"""Conservative firmware call-chain stack audit, including declared callbacks.

This is a static audit of this application's fixed callback bindings, not a
runtime high-water measurement. Unknown indirect transfers fail the audit.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse(disassembly):
    functions = {}; current = None
    for line in disassembly.splitlines():
        parts = line.strip().split()
        if len(parts) == 2 and parts[1].startswith('<') and parts[1].endswith('>:'):
            current = parts[1][1:-2]; functions[current] = []
        elif current and len(parts) >= 3 and parts[0].endswith(':'):
            try:
                address = int(parts[0][:-1], 16); int(parts[1], 16)
            except ValueError:
                continue
            functions[current].append(dict(address=address, mnemonic=parts[2],
                operands=' '.join(parts[3:]), text=line.strip()))
    if not functions or 'main' not in functions:
        raise ValueError('Could not parse firmware disassembly')
    return functions


def dispatch_base(producers, count):
    bases=[int(row['operands'].split('#',1)[1].strip().split()[0],16)
        for row in producers if row['mnemonic']=='addi' and '#' in row['operands']]
    if len(bases)==1:return bases[0]
    if bases:raise ValueError('Ambiguous dispatch base')
    # An aligned absolute table has a zero low immediate. objdump prints
    # addi r,r,0 as mv r,r and omits its address comment. Accept only the
    # complete bounded, scaled, loaded switch sequence, not any nearby LUI.
    rows=producers[-7:]
    if [r['mnemonic'] for r in rows]!=['li','bltu','lui','slli','mv','add','lw']:
        raise ValueError('Unrecognized dispatch producer')
    args=[r['operands'].split('#',1)[0].strip() for r in rows]
    bound=args[0].split(',')
    guard=args[1].split(',')
    upper=args[2].split(',')
    scale=args[3].split(',')
    if len(bound)!=2 or len(guard)!=3 or len(upper)!=2 or len(scale)!=3:
        raise ValueError('Malformed aligned dispatch')
    table_reg=upper[0]; index_reg=scale[0]
    if not (int(bound[1],0)==count-1 and guard[:2]==[bound[0],scale[1]]
            and int(scale[2],0)==2 and args[4]==table_reg+','+table_reg
            and args[5]==','.join([index_reg,index_reg,table_reg])
            and args[6]==index_reg+',0('+index_reg+')'
            and len({table_reg,index_reg,scale[1]})==3):
        raise ValueError('Unbounded or mismatched aligned dispatch')
    return (int(upper[1],0)<<12)&0xffffffff


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--firmware', type=Path, required=True)
    p.add_argument('--gcc-prefix', required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args(); out=a.out.resolve(); out.mkdir(parents=True,exist_ok=False)
    build=a.firmware.resolve(); elf=build/'firmware.elf'
    disassembly=subprocess.check_output([a.gcc_prefix+'-objdump.exe','-d',str(elf)],text=True)
    (out/'disassembly.txt').write_text(disassembly,encoding='utf8')
    functions=parse(disassembly)
    # The player owns fixed media_board IO; the SD/FAT/PMJ wrappers below
    # point only to the concrete functions assigned by setup/init in this image.
    bindings={
        'float_read':['yolo_acc_read'],
        'read_bytes':['yolo_acc_read','yolo_acc_read_bulk'],
        'write_bytes':['yolo_acc_write','yolo_acc_write_bulk'],
        'head_scalar.constprop.0':['yolo_acc_write'],
        'read_float':['yolo_acc_read'],
        'read_reg.lto_priv.1':['read_reg.lto_priv.0'],
        'write_reg.lto_priv.1':['write_reg.lto_priv.0'],
        'now.lto_priv.0':['milliseconds'],
        'now.constprop.0':['milliseconds'],
        'cancelled':['page'],
        'wr':['write_reg.lto_priv.1'],
        'rd':['read_reg.lto_priv.1'],
        'now.lto_priv.1':['now.lto_priv.0'],
        'guard':['cancelled'],
        'delay.constprop.0':['cancelled'],
        'block':['media_sdmmc_sector_callback'],
        'read_at.constprop.0':['media_fat32_read'],
        'infer_reply':['yolo_acc_read','yolo_acc_write'],
        'core_list_mergesort':['cmp_idx','cmp_complex'],
    }
    # libgcc soft-float division dispatches through an internal jump table.
    # Check its computed target producers before accepting that local dispatch.
    local_dispatch={'__divsf3':[(16,True),(15,True)],'media_player_poll':[(8,False)]}
    if 'core_state_transition' in functions:local_dispatch['core_state_transition']=[(8,False)]
    dispatch_checks=[]
    binary=(build/'firmware.bin').read_bytes()
    for name,tables in local_dispatch.items():
        instructions=functions.get(name,[]); addresses={row['address'] for row in instructions}
        jumps=[i for i,row in enumerate(instructions) if row['mnemonic'] in ('jr','jalr')]
        if len(jumps)!=len(tables):raise ValueError('Library/switch dispatch changed: '+name)
        for index,(count,relative) in zip(jumps,tables):
            producers=instructions[max(0,index-(24 if name=='core_state_transition' else 7)):index]
            try:base=dispatch_base(producers,count)
            except ValueError as e:raise ValueError(str(e)+': '+name) from e
            if not relative and instructions[index]['operands']!=producers[-1]['operands'].split(',',1)[0]:
                raise ValueError('Dispatch jump register differs from loaded target: '+name)
            offset=base-0x80000000
            if offset<0 or offset+count*4>len(binary):raise ValueError('Dispatch outside image')
            targets=[]
            for slot in range(count):
                value=int.from_bytes(binary[offset+slot*4:offset+slot*4+4],'little',signed=relative)
                target=base+value if relative else value
                if target not in addresses:raise ValueError('Non-local dispatch target: '+name)
                targets.append(hex(target))
            dispatch_checks.append(dict(function=name,base=hex(base),relative=relative,targets=targets))
    frames={}; edges={name:set() for name in functions}; indirect={}; unknown=[]
    # libgcc's shared ABI prologues reserve <=64 bytes, then optionally
    # shrink that reservation with t1 in {0,-16,-32}. jr t0 returns to the
    # call site. Verify the actual helper code before accepting those effects.
    abi_helpers={n for n in functions if re.fullmatch(r'__riscv_save_\d+',n)}
    for name in abi_helpers:
        instructions=functions[name]
        for ins in instructions:
            op,args=ins['mnemonic'],ins['operands'].split('#',1)[0].strip()
            if op not in ('addi','li','sw','j','sub','jr'):raise ValueError('ABI helper changed: '+ins['text'])
            if op=='li' and args not in ('t1,0','t1,-16','t1,-32'):raise ValueError('ABI stack adjustment changed')
            if op=='sub' and args!='sp,sp,t1':raise ValueError('ABI stack adjustment changed')
            if op=='jr' and args!='t0':raise ValueError('ABI return changed')
        if instructions[0]['mnemonic']!='addi' or instructions[0]['operands'] not in ('sp,sp,-64','sp,sp,-16'):
            raise ValueError('ABI stack reservation changed')
    for name,instructions in functions.items():
        frame=0
        for ins in instructions:
            op=ins['mnemonic']; args=ins['operands']
            if args.startswith('sp,') and op not in ('sw','sb','sh'):
                fields=args.split('#',1)[0].strip().split(',')
                if op=='addi' and len(fields)==3 and fields[:2]==['sp','sp']:
                    amount=int(fields[2],0)
                    if amount<0:frame-=amount
                elif name in abi_helpers and op=='sub' and args=='sp,sp,t1':
                    pass # Verified nonpositive t1 only shrinks the reservation.
                elif name=='_start' and op in ('auipc','addi'):
                    pass
                else:unknown.append(dict(function=name,reason='unrecognized stack mutation',instruction=ins))
            if op in ('jal','j','tail') and '<' in args:
                target=args.split('<',1)[1].split('>',1)[0]
                if target==name and op=='jal':raise ValueError('Recursive call: '+name)
                if '+' not in target and target!=name:
                    if target not in functions:unknown.append(dict(function=name,reason='missing direct callee',target=target))
                    else:edges[name].add(target)
            if op in ('jalr','jr'):
                indirect.setdefault(name,[]).append(ins)
                if name in bindings:edges[name].update(bindings[name])
                elif name not in local_dispatch and name not in abi_helpers:unknown.append(dict(function=name,reason='unbound indirect transfer',instruction=ins))
        frames[name]=frame
    for caller,targets in bindings.items():
        if caller in indirect:
            for target in targets:
                if target not in functions:unknown.append(dict(function=caller,reason='callback symbol missing',target=target))
    # Cross-check compiler reports, retaining the larger bound. Some functions
    # have two-part prologues; summing negative SP adjustments is conservative.
    compiler_frames={}
    for path in build.glob('*.su'):
        for line in path.read_text(encoding='utf8').splitlines():
            location,size,kind=line.rsplit('	',2)
            if kind!='static':unknown.append(dict(reason='non-static compiler stack',line=line))
            name=location.rsplit(':',1)[-1]
            compiler_frames[name]=max(compiler_frames.get(name,0),int(size))
    for name in frames:
        key=re.sub(r'\.(?:constprop|isra)\.\d+',lambda m:m[0].rsplit('.',1)[0],name)
        key=re.sub(r'\.lto_priv\.\d+$','',key)
        frames[name]=max(frames[name],compiler_frames.get(key,0))
    memo={}; active=[]
    def walk(name):
        if name in memo:return memo[name]
        if name in active:raise ValueError('Recursive stack path: '+' -> '.join(active+[name]))
        active.append(name); best=(0,[])
        for target in sorted(edges[name]):
            value,path=walk(target)
            if value>best[0]:best=value,path
        active.pop(); memo[name]=(frames[name]+best[0],[name]+best[1]); return memo[name]
    for name in functions:walk(name)
    mapping=(build/'firmware.map').read_text(encoding='utf8')
    bss=int(re.search(r'(0x[0-9a-f]+)\s+_bss_end =',mapping)[1],16)
    available=0x80014000-bss; maximum,path=memo['main']
    result=dict(status='STATIC_STACK_AUDIT_PASS' if not unknown and maximum<=available else 'STATIC_STACK_AUDIT_INCOMPLETE',
        elf_sha256=sha(elf),available_stack_bytes=available,
        conservative_call_chain_bytes=maximum,remaining_bytes=available-maximum,
        worst_chain=[dict(function=name,frame_bytes=frames[name]) for name in path],
        function_frames=frames,edges={name:sorted(targets) for name,targets in edges.items()},
        indirect_transfers=indirect,declared_callback_bindings=bindings,
        verified_local_dispatch=dispatch_checks,unresolved=unknown,
        runtime_high_water_measured=False,interrupt_stack_covered=False,
        assumptions=['Fixed application callback assignments in the linked source',
            'Current startup does not enable interrupts',
            'Tail calls conservatively counted as nested frames',
            'Negative constant SP adjustments summed, compiler reports cross-checked'])
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps({k:result[k] for k in ('status','available_stack_bytes','conservative_call_chain_bytes','remaining_bytes','worst_chain','unresolved')},indent=2))
    if result['status']!='STATIC_STACK_AUDIT_PASS':raise SystemExit(1)


if __name__=='__main__':main()
