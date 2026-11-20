"""Report data coverage and paired validation outcomes without reading images.

This diagnostic never changes acceptance gates, thresholds, weights or splits.
File identities and source folders are not physical object identities.
"""
import argparse
from collections import Counter, defaultdict
from pathlib import Path

from adapt_quant_heads import ROOT, PARENT, read, save, sha
from replay_policy import overlap


NAMES = ('kitchen', 'recyclable', 'hazardous', 'other', 'hand')


def cohorts(row):
    groups = ['all', 'source/' + row['source']]
    waste = any(int(b[0]) < 4 for b in row['boxes'])
    hand = any(int(b[0]) == 4 for b in row['boxes'])
    groups.append('has_waste' if waste else 'no_waste')
    if hand:
        groups.append('waste_with_hand' if waste else 'hand_without_waste')
    if row['source'] == 'sumn2u':
        # Use documented directory names only; do not infer materials visually.
        parts = str(row.get('image', '')).replace('\\', '/').lower().split('/')
        for material in ('glass', 'metal', 'paper', 'cardboard', 'plastic', 'biological', 'trash'):
            if material in parts:
                groups.append('source_folder/sumn2u/' + material)
                break
    return groups


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--experiment', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    exp = args.experiment.resolve()
    plan=read(exp/'plan.json')
    evaluation = read(exp/'evaluation/state.json')
    candidate_kind = 'full_finetune' if 'full_finetune_quantization' in evaluation else 'qat'
    candidate_label = '本轮整网训练' if candidate_kind == 'full_finetune' else 'QAT'
    manifest_path = Path(plan.get('manifest',PARENT / 'dataset_004/manifest.json'))
    manifest = read(manifest_path)
    by_identity = {}
    train_source = defaultdict(set)
    for row in manifest:
        if row['split'] != 'train':
            continue
        digest = row['image_sha256']
        if digest in by_identity:
            assert by_identity[digest]['boxes'] == row['boxes'], 'Conflicting repeated labels'
        by_identity[digest] = row
        train_source[row['source']].add(digest)
    train_classes = {name: dict(images=0, instances=0) for name in NAMES}
    train_context = Counter()
    for row in by_identity.values():
        counts = Counter(int(b[0]) for b in row['boxes'])
        for c, count in counts.items():
            train_classes[NAMES[c]]['images'] += 1
            train_classes[NAMES[c]]['instances'] += count
        waste = any(c < 4 for c in counts)
        hand = 4 in counts
        train_context['waste_with_hand' if waste and hand else 'waste_without_hand' if waste else 'hand_without_waste' if hand else 'pure_empty'] += 1
    baseline_root = ROOT / 'build/quant_head_adapt_20261118_001'
    files = {
        'deployed': baseline_root / 'baseline_q15_current_policy/decisions.json',
        'head_gt': baseline_root / 'experiment_003/evaluation/score_oldval/decisions.json',
        'head_distilled': baseline_root / 'experiment_004/evaluation/score_oldval/decisions.json',
        'tail_qat': exp / 'evaluation/score_oldval/decisions.json',
    }
    decisions = {name: read(path) for name, path in files.items()}
    truth = {Path(row['prepared_image']).stem: row for row in manifest if row['split'] == 'val'}
    assert all(set(d) == set(truth) for d in decisions.values())
    sizes = {Path(row['path']).stem: row['display_size'] for row in read(ROOT / 'build/overnight_20261116/numeric_allval_001/inventory.json')}
    summary = defaultdict(lambda: dict(images=0, positive_images=0, no_waste_images=0, models={name: Counter() for name in files}))
    classes = {name: dict(images=0, models={model: 0 for model in files}) for name in NAMES[:4]}
    for stem, row in truth.items():
        waste = [b for b in row['boxes'] if int(b[0]) < 4]
        w, h = sizes[stem]
        for c in {int(b[0]) for b in waste}:
            classes[NAMES[c]]['images'] += 1
            for name, model in decisions.items():
                sel = model[stem]['selected']
                correct = bool(sel and int(sel[5]) == c and any(
                    int(gc) == c and overlap(sel[:4], [(cx-bw/2)*w, (cy-bh/2)*h, (cx+bw/2)*w, (cy+bh/2)*h]) >= .5
                    for gc, cx, cy, bw, bh in waste))
                classes[NAMES[c]]['models'][name] += correct
        for group in cohorts(row):
            entry = summary[group]
            entry['images'] += 1
            entry['positive_images'] += bool(waste)
            entry['no_waste_images'] += not waste
            for name, model in decisions.items():
                d = model[stem]
                correct = bool(d['correct_class_and_iou050'])
                base = bool(decisions['deployed'][stem]['correct_class_and_iou050'])
                entry['models'][name]['correct_positive'] += bool(waste) and correct
                entry['models'][name]['false_selection_no_waste'] += not waste and d['selected'] is not None
                entry['models'][name]['positive_gain'] += bool(waste) and correct and not base
                entry['models'][name]['positive_loss'] += bool(waste) and base and not correct
    result = dict(status='DEVELOPMENT_COVERAGE_DIAGNOSTIC', final_test_images_or_labels_read=False,
        candidate_kind=candidate_kind, legacy_candidate_key='tail_qat',
        scope='Saved validation decisions only; not a camera or physical-object-generalization measurement.',
        train_file_identities=len(by_identity), train_source_file_identities={k: len(v) for k, v in sorted(train_source.items())},
        train_class_counts=train_classes, train_context_counts=dict(train_context),
        val_cohorts=dict(summary), val_subject_by_class=classes,
        manifest_sha256=sha(manifest_path), decision_sha256={k: sha(v) for k, v in files.items()})
    args.out.mkdir(parents=True, exist_ok=False)
    save(args.out / 'result.json', result)
    lines = ['# 识别覆盖与逐来源开发验证', '',
        '这里只分析固定开发验证集已有预测，不增加验证图片、不调阈值，不读取最终测试图片或标签。文件SHA数量不是实物数量；来源文件夹不能证明现场识别质量。', '',
        f"训练文件身份：{len(by_identity)}。按已标注框，纯空场景 {train_context['pure_empty']}；仅手无垃圾 {train_context['hand_without_waste']}；手与垃圾同时出现 {train_context['waste_with_hand']}。", '',
        '| 训练类别 | 有该类的独立文件 | 框数 |', '|---|---:|---:|']
    for name, row in train_classes.items():
        lines.append(f"| {name} | {row['images']} | {row['instances']} |")
    lines += ['', f'| 验证来源/场景 | 有物/无物 | 原部署正确/误选 | {candidate_label}正确/误选 | {candidate_label}新增正确/新增错误 |', '|---|---:|---:|---:|---:|']
    for group, row in sorted(summary.items()):
        b, c = row['models']['deployed'], row['models']['tail_qat']
        lines.append(f"| {group} | {row['positive_images']}/{row['no_waste_images']} | {b['correct_positive']}/{b['false_selection_no_waste']} | {c['correct_positive']}/{c['false_selection_no_waste']} | {c['positive_gain']}/{c['positive_loss']} |")
    lines += ['', '正确指主体类别与标注匹配且IoU≥0.5；误选仅统计无垃圾图片。增益和退步是同图配对，不能用净增益掩盖具体退步。空手集没有证明复杂无人背景覆盖；不存在的现场验证类别也不能由同桶其他物品代替。', '']
    (args.out / 'coverage.md').write_text('\n'.join(lines), encoding='utf8')
    print(args.out, flush=True)


if __name__ == '__main__':
    main()
