"""Finish two already-frozen offline experiments without touching the board."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

from adapt_quant_heads import ROOT, read, save, sha


def main():
    tools = Path(__file__).resolve().parent
    py = ROOT / 'build/trash_train_env/Scripts/python.exe'
    env = dict(os.environ, PYTHONUTF8='1')
    out = ROOT / 'build/noon_continuation_20261118_001'
    out.mkdir(exist_ok=False)
    state = dict(status='running', steps=[], board_accessed=False)
    blob = ROOT / 'project/trash_sorting/candidates/continuation_023/source/yolo/model/model.bin'
    digest = '7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728'
    baseline = ROOT / 'build/quant_tail_20261118_001/baseline_continuation_current_policy'

    def persist():
        assert sha(blob) == digest
        save(out/'state.json', state)

    def run(name, args):
        step = dict(name=name, started_unix=time.time(), status='running')
        state['steps'].append(step)
        state['status'] = name
        persist()
        print('START', name, flush=True)
        with (out/(name+'.log')).open('x', encoding='utf8') as log:
            proc = subprocess.run([str(py), *map(str,args)], cwd=ROOT, env=env,
                                  stdout=log, stderr=subprocess.STDOUT)
        step.update(returncode=proc.returncode, elapsed_s=time.time()-step['started_unix'],
                    status='completed' if proc.returncode == 0 else 'failed')
        persist()
        if proc.returncode:
            raise RuntimeError(name+' failed; see saved log')
        print('DONE', name, flush=True)

    try:
        for label, directory in [('targeted', 'quant_targeted_tail_20261118_001'),
                                 ('orientation', 'quant_battery_orientation_20261118_001')]:
            exp = ROOT/'build'/directory/'experiment_001'
            plan = read(exp/'plan.json')
            assert plan['epochs'] == 3 and plan['checkpoint_selection'].startswith('Final third epoch')
            state['experiment'] = str(exp)
            if label == 'targeted':
                state['status'] = 'waiting_existing_targeted_train'
                persist()
                # This is the training process already running when this task resumed.
                start = time.time()
                while not (exp/'training/result.json').exists():
                    assert time.time()-start < 1800, 'Existing training did not finish within 30 min'
                    time.sleep(5)
            else:
                assert not (exp/'training').exists(), 'Never duplicate or overwrite training'
                run(label+'_train', [tools/'train_qat_tail.py','train','--out',exp])
            assert read(exp/'training/result.json')['status'] == 'PASS'
            dest = exp.parent/'baseline_continuation_current_policy'
            if not dest.exists():
                shutil.copytree(baseline, dest)
            assert sha(dest/'decisions.json') == sha(baseline/'decisions.json')
            run(label+'_evaluation',[tools/'evaluate_quant_head_adaptation.py','--experiment',exp,'--qat-tail'])
            run(label+'_continuation',[tools/'evaluate_qat_continuation.py','--experiment',exp])
            run(label+'_gallery',[tools/'render_quant_comparison.py','--experiment',exp,
                                 '--baseline-root',ROOT/'build/quant_head_adapt_20261118_001'])
            run(label+'_coverage',[tools/'summarize_recognition_coverage.py','--experiment',exp,
                                  '--out',exp/'evaluation/recognition_coverage'])
            run(label+'_archive',[tools/'record_qat_comparison.py','--experiment',exp,'--name',directory])
        state['status'] = 'COMPLETED_TWO_FROZEN_OFFLINE_EXPERIMENTS'
    except BaseException as error:
        state.update(status='failed', error=repr(error))
        raise
    finally:
        persist()


if __name__ == '__main__':
    main()
