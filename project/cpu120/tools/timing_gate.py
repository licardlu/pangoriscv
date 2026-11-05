"""Final PDS multi-corner acceptance with strictly positive margins at >=120 MHz."""
import argparse
import json
from pathlib import Path
import re


def assess(text):
    checks = {}
    pattern = r'^(Setup|Hold|Recovery|Removal|Minimum Pulse Width) Summary\((Slow|Fast) Corner\):[^\n]*\n(.*?^=+[ \t]*$)'
    for found in re.finditer(pattern, text, re.M | re.S):
        kind, corner, block = found.groups()
        rows = []
        for line in block.splitlines():
            columns = line.split()
            if columns and columns[0] == 'core_clk':
                try:
                    slack, total, failing, endpoints = columns[-4:]
                    rows.append({'slack_ns': float(slack), 'total_violation_ns': float(total),
                                 'failing_endpoints': int(failing), 'endpoints': int(endpoints)})
                except ValueError as exc:
                    raise ValueError('Malformed timing row: '+line) from exc
        if len(rows) != 1 or rows[0]['endpoints'] <= 0:
            raise ValueError('Missing/ambiguous core clock timing row')
        checks[f'{kind}({corner} Corner)'] = rows[0]
    required = {f'{kind}({corner} Corner)' for corner in ['Slow', 'Fast']
                for kind in ['Setup', 'Hold', 'Recovery', 'Removal', 'Minimum Pulse Width']}
    if set(checks) != required:
        raise ValueError('Incomplete final multi-corner report: '+repr(required-set(checks)))
    periods = re.findall(r'^\s*core_clk\s+(\d+\.\d+)\s+\{[^}]+\}\s+Declared', text, re.M)
    if len(periods) != 1:
        raise ValueError('Missing unique core clock period')
    period = float(periods[0])
    closed = ('Design Summary : All Constraints Met.' in text and period <= 1000/120
              and all(c['slack_ns'] > 0 and c['failing_endpoints'] == 0
                      and c['total_violation_ns'] == 0 for c in checks.values()))
    return {'sta_closed': closed, 'constraint_mhz': 1000/period,
            'setup_wns_ns': min(checks[f'Setup({c} Corner)']['slack_ns'] for c in ['Slow', 'Fast']),
            'setup_failing_endpoints': sum(checks[f'Setup({c} Corner)']['failing_endpoints'] for c in ['Slow', 'Fast']),
            'checks': checks, 'board_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    args = parser.parse_args()
    result = assess(args.report.read_text(errors='replace'))
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['sta_closed'] else 1)
