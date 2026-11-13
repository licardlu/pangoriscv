"""Synthetic scoring tests: no held-out pictures or model predictions are used."""
import argparse
import importlib.util
from pathlib import Path
import json


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    module = Path(__file__).resolve().parents[1]/'training/evaluate_final_battery.py'
    spec = importlib.util.spec_from_file_location('final_score', module)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    a.out.mkdir(parents=True, exist_ok=False)
    lib = m.compile_policy(a.cc.resolve(), a.out)
    row = dict(id=1, file='synthetic', display_size=[100, 100], source='held_battery',
               primary_score=True, quality='SYNTHETIC', held_object=dict(bin=2, xyxy=[.1, .1, .3, .3]))
    def box(xyxy, category=2, score=.9):
        return dict(box=xyxy, category=category, score=score)
    exact = box([10, 10, 30, 30])
    correct = m.score_row(row, [exact], lib)
    assert correct['counts']['subject_and_bucket_correct'] == 1
    assert correct['subject_iou'] == 1
    wrong_bucket = m.score_row(row, [box([10, 10, 30, 30], 1)], lib)
    assert wrong_bucket['counts']['selected_subject_iou050'] == 1
    assert wrong_bucket['counts']['selected_red_bucket'] == 0
    assert wrong_bucket['counts']['subject_and_bucket_correct'] == 0
    # Background red does not turn a wrong-subject answer into a true success.
    background = m.score_row(row, [exact, box([40, 40, 95, 95], 2, .3)], lib)
    assert background['selected_index'] == 1
    assert background['counts']['base_subject_red_detected_iou050'] == 1
    assert background['counts']['selected_red_bucket'] == 1
    assert background['counts']['subject_and_bucket_correct'] == 0
    empty = m.score_row(row, [], lib)
    assert empty['selected_index'] == -1 and empty['counts']['selected_images'] == 0
    # Compare clipped areas, not the much larger off-screen rectangle.
    clipped = m.score_row(row, [box([-500, 0, 5, 30], 0), exact], lib)
    assert clipped['selected_index'] == 1
    # Equal valid area is resolved by score, mirroring production.
    tied = m.score_row(row, [box([50, 50, 70, 70], 1, .3), exact], lib)
    assert tied['selected_index'] == 1
    secondary = m.score_row(dict(row, id=2, source='table_battery', primary_score=False), [exact], lib)
    summary = m.aggregate([correct, background, secondary])
    assert summary['primary']['images'] == 2
    assert summary['primary']['subject_and_bucket_correct'] == 1
    assert summary['secondary_motion_blur']['images'] == 1
    assert summary['all_angles']['images'] == 3
    invalid_rejected = 0
    for invalid in (box([1, 1, 10, 10], 4), box([float('nan'), 1, 10, 10]), box([1, 2, 3])):
        try: m.score_row(row, [invalid], lib)
        except ValueError: invalid_rejected += 1
    assert invalid_rejected == 3
    result = dict(status='PASS', synthetic_only=True, scoring_cases=7,
                  invalid_detection_cases=invalid_rejected,
                  script_sha256=m.sha(module), policy_sha256=m.sha(m.SW/'yolo_contact_policy.h'))
    m.write(a.out/'result.json', result)
    print('FINAL_BATTERY_SCORING_TEST_PASS '+json.dumps(result))


if __name__ == '__main__':
    main()
