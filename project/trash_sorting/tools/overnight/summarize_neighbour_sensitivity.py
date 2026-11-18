"""Development sensitivity report excluding pHash-flagged validation images; no training/test access."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--neighbours', type=Path, required=True)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--crosscheck', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    neighbours = read(a.neighbours)
    flagged = {Path(row['val']['path']).stem for row in neighbours}
    truth = {Path(r['prepared_image']).stem: r for r in read(a.manifest) if r['split'] == 'val'}
    results = {}
    identities = {'neighbours': sha(a.neighbours), 'manifest': sha(a.manifest)}
    for label in ('stage4_original', 'stage4_focused', 'conservative_original', 'conservative_focused'):
        directory = a.crosscheck/(label+'_score')
        report = read(directory/'result.json')
        if report['held_out_test_used'] or report['manifest_sha256'] != identities['manifest']:
            raise ValueError('Expected fixed development validation results')
        decisions = read(directory/'decisions.json')
        stats = defaultdict(Counter)
        for stem, decision in decisions.items():
            gt = truth[stem]
            has_waste = any(int(box[0]) < 4 for box in gt['boxes'])
            group = 'flagged' if stem in flagged else 'unflagged'
            for subset in ('all', group):
                s = stats[subset]
                s['images'] += 1
                s['positive_images' if has_waste else 'background_images'] += 1
                if has_waste:
                    s['correct_class_and_iou050'] += bool(decision['correct_class_and_iou050'])
                    s['missed_or_wrong'] += not decision['correct_class_and_iou050']
                else:
                    s['background_false_selected'] += decision['selected'] is not None
                    s['background_correct_rejection'] += decision['selected'] is None
        for s in stats.values():
            s['positive_success_fraction'] = s['correct_class_and_iou050']/s['positive_images'] if s['positive_images'] else None
            s['background_false_selection_fraction'] = s['background_false_selected']/s['background_images'] if s['background_images'] else None
        results[label] = dict(model_sha256=report['model_sha256'], cohorts=dict(stats))
        identities[label] = {'decisions_sha256': sha(directory/'decisions.json'), 'result_sha256': sha(directory/'result.json')}
    output = dict(status='DEVELOPMENT_SENSITIVITY_REPORT', scope='Saved software Q15/C decisions; not camera accuracy',
        test_used=False, training_performed=False, thresholds_changed=False, split_changed=False,
        flagged_pairs=len(neighbours), flagged_parent_val_images=len(flagged),
        flag_rule='pHash distance <=6; all flags excluded, regardless of visual judgement or outcome',
        limitations=['Unflagged images are not proven free of same-object or same-session leakage.',
                    'pHash is dominated by background in several images and is not an object-identity test.',
                    'This is sensitivity analysis of a developed-on validation set, not independent final evaluation.'],
        input_identities=identities, comparisons=results)
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'result.json').write_text(json.dumps(output, indent=2), encoding='utf8')
    for label, report in results.items():
        print(label, json.dumps(report['cohorts'], sort_keys=True))


if __name__ == '__main__':
    main()
