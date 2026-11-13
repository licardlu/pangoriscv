"""Read-only handoff checks, including relocated clones; no board access."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import zlib


def read(path):
    return json.loads(path.read_text(encoding='utf8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(root):
    project = root / 'project/trash_sorting'
    snapshot = project / 'releases/hand_trial_092'
    manifest = read(snapshot / 'manifest.json')
    for relative, expected in manifest['files'].items():
        path = (snapshot / relative).resolve()
        if not path.is_relative_to(snapshot.resolve()) or sha(path) != expected:
            raise ValueError('Snapshot file differs: ' + relative)
    spec = importlib.util.spec_from_file_location('handoff_build_full', project / 'tools/build_full.py')
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    builder.verify_firmware_sources(snapshot / 'source')
    releases = []
    for relative, count in [('diagnostics/hand_trial_54mhz_092', 5),
                            ('bitstream/full_54mhz_20261113', 4)]:
        folder = project / relative
        release = read(folder / 'manifest.json')
        model = read(folder / 'model/memory_map.json')
        blob = (folder / 'model/model.bin').read_bytes()
        if sha(folder / 'yolo_camera_top.sbit') != release['bitstream_sha256']:
            raise ValueError('Bitstream differs: ' + relative)
        if hashlib.sha256(blob).hexdigest() != model['blob_sha256'] or model['blob_sha256'] != release['model_sha256']:
            raise ValueError('Model differs: ' + relative)
        if zlib.crc32(blob) != model['blob_crc32'] or release['raw_model_classes'] != count:
            raise ValueError('CRC or class schema differs: ' + relative)
        if not release['timing_pass'] or release['servo_reversed_mask'] != '1111':
            raise ValueError('Release timing/mechanics gate failed: ' + relative)
        builder.timing_gate((root / 'evidence/records/optimization' /
            ('trash_hand_trial_fast54_20261113_092' if count == 5 else 'trash_camera_probe_fast54_20261113_062') /
            'yolo_camera_top.rtr').read_text(encoding='utf8', errors='replace'))
        releases.append(dict(path=relative, classes=count, sha256=release['bitstream_sha256']))
    current = project / 'diagnostics/hand_trial_54mhz_092'
    fixtures = read(current / 'fixtures/manifest.json')
    if fixtures['model_sha256'] != read(current / 'manifest.json')['model_sha256']:
        raise ValueError('Fixtures belong to another model')
    for case in fixtures['cases']:
        payload = (current / 'fixtures' / case['file']).read_bytes()
        if len(payload) != 819200 or hashlib.sha256(payload).hexdigest() != case['sha256']:
            raise ValueError('Invalid fixture: ' + case['file'])
    checkpoint = project / 'training/candidates/hand_trial_045'
    if sha(checkpoint / 'best.pt') != read(checkpoint / 'quantization_provenance.json')['checkpoint_sha256']:
        raise ValueError('Checkpoint changed')
    state = read(root / 'evidence/records/trash-hand-trial-program-20261113-093/result.json')
    for field in ('board_programmed', 'model_crc_verified', 'autonomous_started', 'autonomous_frame_received'):
        if not state[field]:
            raise ValueError('Archived deployment was incomplete: ' + field)
    if state['bitstream_sha256'] != releases[0]['sha256']:
        raise ValueError('Board evidence belongs to another bitstream')
    return dict(status='PASS', snapshot_files=len(manifest['files']), releases=releases,
                fixture_ids=[c['id'] for c in fixtures['cases']],
                scope='file identities, firmware/model closure, archived STA/deployment; no fresh board or accuracy test')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(check(args.root.resolve()), ensure_ascii=False, indent=2))
