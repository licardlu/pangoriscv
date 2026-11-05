"""Bind CPU mapped leaf cells to a region after PDS flattens the hierarchy."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

from build import sha, write_json


def append_region(out):
    inputs = json.loads((out/'inputs.json').read_text(encoding='utf-8'))
    request = inputs['physical_constraints'][0]
    region = out/request['path']
    if sha(region) != request['sha256']:
        raise ValueError('Region request hash changed')
    text = (out/'mapped_region.adif').read_text(encoding='utf-8')
    leaves = re.findall(r'\(INSTANCE \\(ai/cpu/system_cpu_logic_core/\S+)\s+'
                        r'\(VIEWREF OPER \(CELLREF \S+ \(OPERAREF (\S+)', text)
    if len(leaves) < 1000 or len({name for name, _ in leaves}) != len(leaves):
        raise ValueError('CPU mapped leaves missing or duplicate')
    if any(any(c in name for c in '{}\r\n') for name, _ in leaves):
        raise ValueError('Unsupported mapped identifier')
    commands = region.read_text(encoding='ascii') + ''.join(
        'def_inst_region {'+name+'} cpu_core_region\n' for name, _ in leaves)
    generated = out/'cpu_region.generated.txt'
    generated.write_text(commands, encoding='ascii')
    active = out/request['active_path']
    with active.open('a', encoding='ascii') as stream:
        stream.write('\n'+commands)
    write_json(out/'region_manifest.json', dict(instance_count=len(leaves),
        primitive_counts=dict(Counter(kind for _, kind in leaves)),
        commands_sha256=sha(generated), request_sha256=sha(region),
        mapped_sha256=sha(out/'device_map/yolo_camera_top_map.adf'),
        adif_sha256=sha(out/'mapped_region.adif')))
    return len(leaves)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True, type=Path)
    args = parser.parse_args()
    print('YOLO120_CPU_REGION_LEAVES', append_region(args.build.resolve()))
