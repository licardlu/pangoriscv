"""Summarize independent SRAM restore runs; fail closed on incomplete board evidence."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import statistics as S


def read(p): return json.loads(p.read_text(encoding='utf8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def summarize(folder):
    r = read(folder/'result.json'); j = read(folder/'jtag/result.json')
    for k in ('board_programmed', 'model_loaded', 'model_crc_verified', 'camera_inference_pass', 'autonomous_started'):
        if not r.get(k): raise ValueError(str(folder)+': missing '+k)
    if r.get('error') or not r.get('input_equivalence', {}).get('passed'):
        raise ValueError('Incomplete restore/input checks')
    if not (j['programming_requested'] and j['configuration_active_verified'] and j['cable_disconnected']
            and j['sha256'] == r['bitstream_sha256'] and len(j['configuration_status_hex']) == 2):
        raise ValueError('Incomplete JTAG checks')
    for status in j['configuration_status_hex']:
        v = int(status, 16)
        if v & 0x7d000 != 0x7d000 or v & 7: raise ValueError('JTAG configuration inactive')
    frames = r.get('camera_probe_frames', [])
    if len(frames) != 10 or [x['index'] for x in frames] != list(range(1, 11)) or r.get('camera_probe_warmup', {}).get('index') != 0:
        raise ValueError('Exactly one warmup plus ten camera probes required')
    fixtures = r.get('numerical_fixtures', [])
    if {x['id'] for x in fixtures} != {1, 23, 38, 76} or len(fixtures) != 4 or not all(x['passed'] for x in fixtures):
        raise ValueError('Four original numerical fixtures required')
    for x in [r['camera_probe_warmup'], *frames]:
        p = x['profile']
        if (p['cpu_hz'] != 54000000 or p['flags'] != 63 or len(p['operators']) != 85
                or any(o['cycles'] <= 0 for o in p['operators'])
                or abs(sum(p['stages'].values())-x['device_seconds']) > 1e-6
                or abs(max(x['request_seconds'], x['device_seconds'])-x['seconds']) > 1e-6):
            raise ValueError('Invalid complete probe timing')
    seconds = [x['seconds'] for x in frames]
    if abs(S.mean(seconds)-r['camera_probe_mean_seconds']) > 1e-6:
        raise ValueError('Reported camera mean inconsistent')
    stages = {k:S.mean(x['profile']['stages'][k] for x in frames) for k in frames[0]['profile']['stages']}
    kinds = {k:S.mean(x['profile']['seconds_by_kind'].get(k, 0) for x in frames) for k in frames[0]['profile']['seconds_by_kind']}
    fixed = {}
    for case in fixtures:
        p = case['profile']
        if p['cpu_hz'] != 54000000 or p['flags'] != 63 or len(p['operators']) != 85:
            raise ValueError('Invalid fixed-fixture profile')
        fixed[str(case['id'])] = dict(request_seconds=case['inference_request_seconds'],
                stages=p['stages'], seconds_by_kind=p['seconds_by_kind'], detections=case['detections'])
    return dict(folder=str(folder.resolve()), source_result_sha256=sha(folder/'result.json'),
                bitstream_sha256=r['bitstream_sha256'], model_sha256=r['model_sha256'],
                camera_mean_seconds=S.mean(seconds), camera_max_seconds=max(seconds), camera_min_seconds=min(seconds),
                camera_p90_seconds=sorted(seconds)[8], camera_population_stdev=S.pstdev(seconds),
                camera_frames_at_most_2_seconds=sum(t <= 2 for t in seconds), camera_samples=10,
                camera_detection_counts=[len(x['detections']) for x in frames], camera_stages_mean=stages,
                camera_kinds_mean=kinds, fixed_fixtures=fixed,
                fixed_forward_mean=S.mean(x['stages']['forward'] for x in fixed.values()))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--runs', type=Path, nargs='+', required=True)
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args()
    results = [summarize(p) for p in a.runs]
    if len({r['model_sha256'] for r in results}) != 1:
        raise ValueError('Speed comparison requires exactly the same model')
    base = results[0]
    for r in results:
        r['camera_mean_change_vs_first_percent'] = (r['camera_mean_seconds']/base['camera_mean_seconds']-1)*100
        r['fixed_forward_change_vs_first_percent'] = (r['fixed_forward_mean']/base['fixed_forward_mean']-1)*100
        # Each fixed input has already matched the same numerical oracle.
        # Preserve the actual results so a reviewer can assess equivalence.
    report = dict(status='BOARD_SPEED_COMPARISON_VALIDATED', runs=results,
                  limits=['Camera is live, not an identical static scene across SRAM downloads',
                          'Four fixed numerical inputs compare forward cycles independently of changing camera content',
                          'Probe includes capture/inference/decode/selection; excludes display/quiz commit, voice, answer and servo',
                          'Ten-frame statistics are not an all-scene worst-case or full game latency guarantee'])
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps([{k:r[k] for k in ('folder','camera_mean_seconds','camera_max_seconds','fixed_forward_mean',
                                       'camera_mean_change_vs_first_percent','fixed_forward_change_vs_first_percent')} for r in results]))


if __name__ == '__main__': main()
