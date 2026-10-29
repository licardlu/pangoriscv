"""Assess raw UART or RTL-decoded UART output; never infer board verification."""
import argparse
import json
from pathlib import Path
import re
from measurement import parse_uart

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('log', type=Path)
parser.add_argument('--source', choices=['simulation','board'], required=True)
args = parser.parse_args()
text = args.log.read_text(encoding='utf-8-sig', errors='replace')
if args.source == 'simulation':
    text = '\n'.join(m.group(1) for line in text.splitlines()
                     if (m := re.search(r'# UART: ?(.*)$',line)))
result = parse_uart(text)
result['source_declared_by_user'] = args.source
print(json.dumps(result, indent=2))
