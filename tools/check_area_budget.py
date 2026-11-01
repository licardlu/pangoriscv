"""Compare final PDS utilization with the frozen documented area budget.

LUT+FF+Distributed RAM is a bookkeeping total, not a count of LUTs.
Baseline tolerance is opt-in and never changes the frozen budget.
"""
import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = 'baseline-implementation-standalone-001'


def check(summary, module=BASELINE, mode='strict', tolerance=0):
    if mode not in ('strict', 'baseline') or tolerance < 0 or (mode == 'strict' and tolerance):
        raise ValueError('Nonnegative tolerance requires explicit baseline mode')
    with (ROOT / 'docs/architecture/area-budget.csv').open(newline='', encoding='utf-8-sig') as handle:
        budgets = {row['implementation']: row for row in csv.DictReader(handle)}
    if module == 'reference_exact':  # compatibility with the former CLI default
        module = BASELINE
    budget = budgets[module]
    rows = list(csv.reader(Path(summary).read_text(encoding='utf-8-sig').splitlines()))
    index = next(i for i, row in enumerate(rows) if row and row[0] == 'Logic Utilization')
    used = dict(zip(rows[index], rows[index + 1]))
    actual = {key: int(used[key]) for key in ('LUT', 'FF', 'Distributed RAM')}
    expected = {'LUT': int(budget['lut']), 'FF': int(budget['ff']),
                'Distributed RAM': int(budget['lutram'])}
    before, after = sum(expected.values()), sum(actual.values())
    if before != int(budget['lut_ff_lutram_total']):
        raise ValueError('Budget component sum disagrees with declared total')
    allowed = before * tolerance / 100 if mode == 'baseline' else 0
    delta = after - before
    return {'status': 'PASS' if delta <= allowed else 'FAIL', 'mode': mode, 'module': module,
            'source_csv': str(summary), 'budget': expected, 'actual': actual, 'delta': delta,
            'delta_percent': 100 * delta / before, 'allowed_delta': allowed,
            'exact_area_neutral': delta <= 0, 'baseline_tolerance_percent': tolerance,
            'metric': 'LUT+FF+Distributed RAM; not LUT-only'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--from-used', required=True, type=Path)
    parser.add_argument('--module', default=BASELINE)
    parser.add_argument('--mode', choices=['strict', 'baseline'], default='strict')
    parser.add_argument('--tolerance', type=float, default=0)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = check(args.from_used, args.module, args.mode, args.tolerance)
    rendered = json.dumps(result, indent=2)
    if args.report:
        with args.report.open('x', encoding='utf-8') as handle:
            handle.write(rendered + '\n')
    print(rendered)
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
