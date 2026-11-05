"""Directed RTL and real-CPU boot checks for a staged YOLO120 build."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import zlib

from build import PROJECT, REPO, YOLO, tool_config, write_json


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--modelsim')
    parser.add_argument('--cases', nargs='+', default=['stream','bulk','mmio','snapshot','cdc','bridge','tlul','runtime'])
    args=parser.parse_args()
    build=args.build.resolve()
    if not build.is_relative_to(PROJECT/'build'):
        parser.error('Use a staged build inside project/yolo120/build')
    tools=Path(args.modelsim or tool_config()['modelsim'])
    src=build/'sources'
    engine=[src/n for n in ('conv_engine_axil.v','conv_band_rt.v','requant_q15.v','mac_array.v')]
    cpu=[src/Path(p).name for p in (REPO/'project/cpu120/sources.f').read_text().splitlines()
         if p and 'rtl/board/' not in p and not p.endswith('/MicroSoc.v')]
    cpu += [src/'vexii_ai_soc.v',src/'tlul_to_axil.v']
    cases={
        'stream':(PROJECT/'tests/tb_snapshot_stream.sv', engine+[src/'video_ai_frontend.v',src/'camera_snapshot.v'],'SNAPSHOT_STREAM_PASS'),
        'bulk':(YOLO/'tb/tb_acc_bulk.v',engine,'BULK_EQUIV_PASS'),
        'mmio':(YOLO/'tb/tb_vexii_mmio.v',cpu,'VEXII_MMIO_PASS'),
        'snapshot':(YOLO/'tb/tb_camera_snapshot.v',[src/'camera_snapshot.v'],'SNAPSHOT_PASS'),
        'cdc':(YOLO/'tb/tb_cdc_path.v',[src/'bridge_to_cdc.v',src/'axi_cdc.v'],'CDC_PATH_PASS'),
        'bridge':(YOLO/'tb/tb_ddr_bridge.v',[src/'ddr_axi_bridge.v'],'BRIDGE-PASS'),
        'tlul':(YOLO/'tb/tb_tlul_axil.v',[src/'tlul_to_axil.v'],'TLUL_AXIL_PASS'),
        'runtime':(PROJECT/'tests/tb_runtime_uart.sv',cpu,'RUNTIME_UART_PASS')}
    results=[]
    for name in args.cases:
        tb,sources,marker=cases[name]
        out=build/'checks'/name
        out.mkdir(parents=True,exist_ok=False)
        for lane in (build/'firmware').glob('MicroSoc*.bin'):
            shutil.copy2(lane,out/lane.name)
        if name=='runtime':
            requests=b''; replies=b''
            for flag in (0,1):
                header=struct.pack('<4sBBHI',b'YAI1',10,0,0,flag)
                requests+=header+struct.pack('<I',zlib.crc32(header))
                reply=struct.pack('<4sBHB',b'YAR1',0,4,0)+struct.pack('<I',flag)
                replies+=reply+struct.pack('<I',zlib.crc32(reply))
            for filename,data in [('runtime_requests.hex',requests),('runtime_replies.hex',replies)]:
                (out/filename).write_text(''.join(f'{v:02x}\n' for v in data),encoding='ascii')
        commands=[
            [tools/'vlib.exe','work'],
            [tools/'vlog.exe','-sv','+incdir+'+str(src),tb,*sources],
            [tools/'vsim.exe','-c','-quiet','-voptargs=+acc',tb.stem,'-do',
             'onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0']]
        for i,command in enumerate(commands):
            result=subprocess.run(list(map(str,command)),cwd=out,capture_output=True,
                                  text=True,errors='replace',timeout=600)
            log=result.stdout+result.stderr
            (out/f'{i}.log').write_text(log,encoding='utf-8')
            if result.returncode or '** Error' in log or '** Fatal' in log:
                raise RuntimeError(f'{name}: '+log[-5000:])
        if marker not in log:
            raise RuntimeError('Missing positive pass marker: '+name+'\n'+log[-3000:])
        results.append(dict(case=name,passed=True,marker=marker))
        print(name+' PASS',flush=True)
        write_json(build/'checks/result.json',dict(cases=results,board_verified=False))
    print('YOLO120_RTL_CHECKS_PASS; simulation does not establish hardware latency')


if __name__=='__main__':
    main()
