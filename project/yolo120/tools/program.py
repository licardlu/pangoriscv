"""Scan JTAG or temporarily program an accepted YOLO120 SRAM bitstream."""
import argparse
import json
from pathlib import Path
import sys

from build import HZ, YOLO, module, sha, tool_config, write_json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--implementation', type=Path)
    p.add_argument('--scan-only', action='store_true')
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--jtag-port', type=int, default=65420)
    p.add_argument('--tools', type=Path, help='PDS bin directory containing cdt_cfg.exe')
    args = p.parse_args()
    if args.scan_only == bool(args.implementation):
        p.error('Choose --scan-only or --implementation')
    tools = args.tools or Path(tool_config()['pds']).parent
    candidate = None
    commands = ['program_board.py', '--out', str(args.out), '--port', str(args.jtag_port)]
    if args.implementation:
        candidate = json.loads((args.implementation/'acceptance.json').read_text(encoding='utf-8'))
        bitstream = Path(candidate.get('bitstream') or '')
        if (not candidate.get('timing_pass') or candidate.get('cpu_hz') != HZ or
                not bitstream.is_file() or bitstream.suffix.lower() != '.sbit' or
                sha(bitstream) != candidate.get('bitstream_sha256')):
            p.error('Refusing candidate without matching final STA and bitstream hash')
        commands += ['--sbit', str(bitstream)]
    legacy = module(YOLO/'scripts/program_board.py', 'yolo_jtag')
    legacy.TOOLS = tools.resolve()
    previous = sys.argv
    try:
        sys.argv = commands
        legacy.main()
    finally:
        sys.argv = previous
    if candidate:
        write_json(args.out/'implementation.json', candidate)


if __name__ == '__main__':
    main()
