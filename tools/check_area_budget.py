"""Check documented whole-SoC area budgets against a final PDS CSV.

Strict mode enforces the documented absolute delta. Baseline mode additionally
permits an explicitly supplied percentage tolerance; it is not exact neutrality.
"""
import argparse
import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_budget(module):
    with (ROOT/'docs/architecture/area-budget.csv').open(newline='',encoding='utf-8-sig') as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError('Area budget is empty')
    key = 'implementation' if 'implementation' in rows[0] else 'module'
    # Preserve the original CLI alias for the documented standalone baseline.
    name = ('baseline-implementation-standalone-001'
            if key == 'implementation' and module == 'reference_exact' else module)
    budgets = {row[key]: row for row in rows}
    if name not in budgets:
        raise ValueError('Unknown area budget: '+name)
    budget = budgets[name]
    columns = ('lut', 'ff', 'lutram') if key == 'implementation' else ('LUT', 'FF', 'LUTRAM')
    expected = dict(zip(('LUT', 'FF', 'Distributed RAM'),
                        (int(budget[column]) for column in columns)))
    if any(v < 0 for v in expected.values()) or not sum(expected.values()):
        raise ValueError('Invalid documented area budget')
    return expected, float(budget.get('max_delta', 0))


def check(summary, module, mode, tolerance):
    expected, allowed = read_budget(module)
    rows = list(csv.reader(summary.read_text(encoding='utf-8-sig').splitlines()))
    index = next(i for i,r in enumerate(rows) if r and r[0]=='Logic Utilization')
    used = dict(zip(rows[index],rows[index+1]))
    actual = {key:int(used[key]) for key in ('LUT','FF','Distributed RAM')}
    before, after = sum(expected.values()),sum(actual.values())
    if any(v < 0 for v in actual.values()) or not math.isfinite(allowed):
        raise ValueError('Invalid area values')
    if mode == 'baseline':
        allowed += before*tolerance/100
    elif tolerance:
        raise ValueError('tolerance requires explicit baseline mode')
    if not math.isfinite(tolerance) or tolerance < 0:
        raise ValueError('negative tolerance is invalid')
    delta = after-before
    return {'status':'PASS' if delta<=allowed else 'FAIL', 'mode':mode,'module':module,
            'source_csv':str(summary),'budget':expected,'actual':actual,'delta':delta,
            'delta_percent':100*delta/before,'allowed_delta':allowed,
            'exact_area_neutral':delta<=0,'baseline_tolerance_percent':tolerance}


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--from-used',required=True,type=Path)
    parser.add_argument('--module',default='reference_exact')
    parser.add_argument('--mode',choices=['strict','baseline'],default='strict')
    parser.add_argument('--tolerance',type=float,default=0)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    result=check(args.from_used,args.module,args.mode,args.tolerance)
    rendered=json.dumps(result,indent=2)
    if args.report:
        with args.report.open('x',encoding='utf-8') as handle:
            handle.write(rendered+'\n')
    print(rendered)
    raise SystemExit(0 if result['status']=='PASS' else 1)
