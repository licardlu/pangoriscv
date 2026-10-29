import argparse
import json
from pathlib import Path
import re

from measurement import parse_uart

parser = argparse.ArgumentParser()
parser.add_argument('log', type=Path)
args = parser.parse_args()
lines = []
for line in args.log.read_text(encoding='utf-8', errors='replace').splitlines():
    match = re.search(r'# UART: ?(.*)$', line)
    if match:
        lines.append(match.group(1))
print(json.dumps(parse_uart('\n'.join(lines)), indent=2))
