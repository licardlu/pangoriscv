"""Bind packaged RTL/firmware/bitstream to its final timing and utilization.

Identity validity and area acceptance are reported separately. No board claim
is inferred from static timing or from a matching source hash.
"""
import hashlib
import json
from pathlib import Path

from check_area_budget import check as check_area
from timing_gate import assess
from verify_image import verify

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT, selected=None):
    root = Path(root).resolve()
    selected = selected or json.loads((root/'provenance/SELECTED_IMPLEMENTATION.json').read_text())

    def file(relative):
        path = (root/relative).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError('Missing/outside release: '+relative)
        return path

    def matched(relative, digest):
        path = file(relative)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('Selected implementation identity mismatch: '+relative)
        return path

    bit = matched(selected['bitstream'], selected['bitstream_sha256'])
    report = matched(selected['timing_report'], selected['timing_report_sha256'])
    summary = matched(selected['area_summary'], selected['area_summary_sha256'])
    source_hashes = selected['source_sha256']
    if not source_hashes or 'flow/build.tcl' not in source_hashes:
        raise ValueError('Selected implementation source/flow binding required')
    for relative, digest in source_hashes.items():
        matched(relative, digest)
    timing = assess(report.read_text())
    if not timing['sta_closed']:
        raise ValueError('Selected final timing did not close')
    image = verify(root/'firmware/image/coremark.elf', root/'firmware/image')
    if image != selected['firmware']:
        raise ValueError('Selected implementation firmware mismatch')
    area = check_area(summary)
    return {'binding_valid': True, 'tag': selected['tag'], 'bitstream': bit.relative_to(root).as_posix(),
            'sta_closed': True, 'setup_wns_ns': timing['setup_wns_ns'],
            'minimum_hold_ns': min(timing['checks'][f'Hold({corner} Corner)']['slack_ns']
                                   for corner in ('Slow', 'Fast')),
            'area': area, 'board_verified': False,
            'performance_target_verified': False,
            'note': 'Binding/STA pass does not waive the area budget or establish hardware stability.'}


if __name__ == '__main__':
    result = check()
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['area']['status'] == 'PASS' else 1)
