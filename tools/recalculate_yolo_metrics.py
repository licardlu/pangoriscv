"""Recalculate recorded YOLO120 A/B observations; no board access."""
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[1]


def main():
    path = ROOT / 'evidence/records/optimization/yolo120/experiment-yolo120-006/result.json'
    data = json.loads(path.read_text(encoding='utf-8-sig'))
    groups = {m: [r for r in data['runs'] if r['camera_fast'] == m and not r['warmup']]
              for m in (0, 1)}
    if any(len(rows) != 10 for rows in groups.values()):
        raise ValueError('Expected ten measured frames in each A/B group')
    values = {m: {
        'mean_s': statistics.mean(max(r['wall_seconds'], r['device_seconds']) for r in rows),
        'capture_mean_s': statistics.mean(r['profile']['stages']['capture'] for r in rows)
    } for m, rows in groups.items()}
    print(json.dumps({
        'experimental_only': not data['candidate']['timing_pass'],
        'modes': values,
        'end_to_end_speedup': values[0]['mean_s'] / values[1]['mean_s'],
        'capture_speedup': values[0]['capture_mean_s'] / values[1]['capture_mean_s'],
        'accuracy': 'Not measured; requires annotated evaluation data'
    }, indent=2))


if __name__ == '__main__':
    main()
