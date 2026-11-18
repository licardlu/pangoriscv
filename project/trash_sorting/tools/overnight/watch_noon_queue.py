"""Read-only, current-task progress watch; never trains or touches hardware.

Print a compact snapshot every55s and stop at the user's existing deadline.
Any failed pipeline ends the watch immediately for human-agent diagnosis.
"""
from datetime import datetime,timezone
import json
from pathlib import Path
import time

ROOT=Path(__file__).resolve().parents[4]
NAMES=['quant_reviewed_shape_20261118_001','quant_reviewed_context_20261118_001',
       'quant_full_recovery_20261118_001','quant_reviewed_foam_20261118_001',
       'quant_deployed_teacher_20261118_001']
DEADLINE=datetime.fromisoformat('2026-11-18T04:00:00+00:00')


def read(path):
    try:return json.loads(path.read_text(encoding='utf8'))
    except (FileNotFoundError,json.JSONDecodeError):return {}


def snapshot():
    lines=[];failed=False
    for name in NAMES:
        exp=ROOT/'build'/name/'experiment_001'
        state=read(exp/'pipeline_state.json');status=state.get('status','not_started')
        progress=read(exp/'training/progress.json')
        tail=''
        if status=='train' and progress:
            age=round(time.time()-(exp/'training/progress.json').stat().st_mtime)
            tail=f" epoch{progress['epoch']}/{progress['epochs']} batch{progress['batch']}/{progress['batches_total']} age{age}s"
        if status=='evaluation':
            detail=read(exp/'evaluation/state.json');tail=' '+detail.get('status','')
        if status=='failed':failed=True;tail=' '+state.get('error','')
        lines.append(name.replace('_20261118_001','')+':'+status+tail)
    return dict(utc=datetime.now(timezone.utc).isoformat(),pipelines=lines,failed=failed)


def main():
    out=ROOT/'build/noon_continuation_20261118_001/active_queue_watch_001.jsonl'
    with out.open('x',encoding='utf8') as log:
        while True:
            state=snapshot();line=json.dumps(state)
            log.write(line+'\n');log.flush();print(line,flush=True)
            if state['failed'] or datetime.now(timezone.utc)>=DEADLINE:return
            time.sleep(min(55,max(0,(DEADLINE-datetime.now(timezone.utc)).total_seconds())))


if __name__=='__main__':main()
