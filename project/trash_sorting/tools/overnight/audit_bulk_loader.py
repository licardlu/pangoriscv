"""Audit the actual local YOLO cache, keeping requested and effective draws separate."""
import argparse
from collections import Counter
import math
from pathlib import Path
import re

import numpy as np
from adapt_quant_heads import read, save, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--experiment', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    exp = args.experiment.resolve()
    plan = read(exp / 'plan.json')
    data = Path(plan['manifest']).parent
    rows = read(exp / 'unique_train.json')
    requested = (data / 'train.txt').read_text(encoding='utf8').splitlines()
    # This cache was generated locally by this run, not downloaded from a source.
    cache_path = data / 'train.cache'
    cache = np.load(cache_path, allow_pickle=True).item()
    metadata = {'hash', 'results', 'version', 'msgs'}
    effective = [str(Path(k).resolve()) for k in cache if k not in metadata]
    requested = [str(Path(k).resolve()) for k in requested if k.strip()]
    truth = {str(Path(r['prepared_image']).resolve()): r for r in rows}
    assert set(effective) == set(requested) == set(truth)
    assert len(effective) == len(set(effective)) == plan['unique_train']
    batch = plan['batch']
    log = exp / 'training.log'
    observed = sorted(set(int(n) for n in re.findall(r'320:\s*\d+%\|[^\r\n]*?\|\s*\d+/(\d+)\s+\d+:\d+', log.read_text(encoding='utf8', errors='replace'))))
    batches = math.ceil(len(effective) / batch)
    assert observed == [batches], (observed, batches)
    def counts(paths):
        sources = Counter()
        classes = Counter()
        contexts = Counter()
        for path in paths:
            row = truth[path]
            sources[row['source']] += 1
            present = set(int(b[0]) for b in row['boxes'])
            classes.update(present)
            waste, hand = bool(present & set(range(4))), 4 in present
            contexts['waste_with_hand' if waste and hand else 'waste_only' if waste else 'hand_only' if hand else 'empty'] += 1
        return dict(sources=dict(sources), class_image_counts=dict(classes), contexts=dict(contexts))
    result = dict(status='COMPLETED_EFFECTIVE_LOADER_AUDIT',
        requested_list_entries=len(requested), effective_primary_samples_per_epoch=len(effective),
        planned_epochs=plan['epochs'], primary_samples_if_all_epochs_complete=len(effective)*plan['epochs'],
        batch=batch, expected_batches_per_epoch=batches, observed_training_log_batch_totals=observed,
        last_batch_size=len(effective)-(batches-1)*batch,
        balanced_replay_effective=False, all_unique_training_files_retained=True,
        requested=counts(requested), effective=counts(effective),
        reason='YOLO LoadImagesAndLabels rebuilds im_files from cache dictionary keys, collapsing repeated paths.',
        frozen_plan_changed=False, training_changed_or_restarted=False, final_test_accessed=False,
        independent_original_photo_count=None, qualified_20000_original_target_achieved=False,
        limitations=['Primary samples exclude additional stochastic mosaic/mixup source reads.',
                     'Four-epoch sample total is conditional until progress confirms completion.',
                     'Unique file hashes include existing derived views; they are not certified independent original photos.'],
        evidence_sha256={str(p): sha(p) for p in [exp/'plan.json', exp/'unique_train.json', data/'train.txt', cache_path]})
    args.out.mkdir(parents=True, exist_ok=False)
    save(args.out/'result.json', result)
    text = ['# 整包训练实际加载数量核对', '',
            f'请求清单 {len(requested)} 行，加载器实际保留 {len(effective)} 个文件。所有唯一训练文件均保留。',
            f'每批 {batch} 张，每轮 {batches} 批，最后一批 {result["last_batch_size"]} 张，与运行日志一致。',
            f'若固定四轮完整结束，主样本加载共 {result["primary_samples_if_all_epochs_complete"]} 次；增强的额外图源读取不计入该数。', '',
            '重复路径在 YOLO 的标签缓存字典中被合并，因此原清单的平衡回放未生效。冻结计划保留原样，这份审计纠正其采样口径。没有为此重启或改变在途训练。', '',
            '这不是新增照片数量，2 万张合格独立原图目标未完成。', '',
            '| 场景 | 请求清单次数 | 实际每轮文件数 |', '|---|---:|---:|']
    for context in sorted(set(result['requested']['contexts']) | set(result['effective']['contexts'])):
        text.append(f'| {context} | {result["requested"]["contexts"].get(context,0)} | {result["effective"]["contexts"].get(context,0)} |')
    (args.out/'loader_audit.md').write_text('\n'.join(text)+'\n', encoding='utf8')
    print({k: result[k] for k in ['status', 'requested_list_entries', 'effective_primary_samples_per_epoch', 'expected_batches_per_epoch', 'balanced_replay_effective']}, flush=True)


if __name__ == '__main__':
    main()
