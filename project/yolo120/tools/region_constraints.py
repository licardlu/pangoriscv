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


def placed_cpu_cells(path):
    """Read the vendor text export's per-instance logical floorplan coordinates."""
    name, body = None, []
    def finish():
        if name is None:
            return None
        text = ''.join(body)
        region = re.search(r'\(ATTRIBUTE \.REGION_CONSTRAINT \(STRING "([^"]+)"\)\)', text)
        site = re.search(r'\(SITEREF (\d+) (\d+)\)', text)
        return dict(name=name, region=region[1] if region else None,
                    site=[int(site[1]), int(site[2])] if site else None)
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            if re.match(r'\s*\(INSTANCE ', line) or re.match(r'\s*\(NET ', line):
                record = finish()
                if record:
                    yield record
                match = re.match(r'\s*\(INSTANCE \\(ai/cpu/system_cpu_logic_core/\S+)\s', line)
                name = match[1] if match else None
                body = []
            elif name:
                body.append(line)
    record = finish()
    if record:
        yield record


def verify_region(out):
    inputs = json.loads((out/'inputs.json').read_text(encoding='utf-8'))
    xmin, xmax, ymin, ymax = inputs['cpu_region']
    cells = list(placed_cpu_cells(out/'placed_region.adif'))
    if len(cells) < 1000 or len({cell['name'] for cell in cells}) != len(cells):
        raise ValueError('Missing or duplicate placed CPU cells')
    for cell in cells:
        site = cell['site']
        if (cell['region'] != 'cpu_core_region' or site is None or
                not (xmin <= site[0] <= xmax and ymin <= site[1] <= ymax)):
            raise ValueError('CPU cell lacks region or lies outside requested bounds: '+str(cell))
    write_json(out/'physical_placement.json', dict(passed=True,
        cpu_region=inputs['cpu_region'], placed_cpu_cells=len(cells),
        pnr_sha256=sha(out/'place_route/yolo_camera_top_pnr.adf'),
        export_sha256=sha(out/'placed_region.adif'),
        cells=cells, note='Logical floorplan SITEREF, not physical CLMA resource-name coordinates'))
    return len(cells)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True, type=Path)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    operation = verify_region if args.verify else append_region
    print('YOLO120_CPU_REGION_VERIFIED' if args.verify else 'YOLO120_CPU_REGION_LEAVES',
          operation(args.build.resolve()))
