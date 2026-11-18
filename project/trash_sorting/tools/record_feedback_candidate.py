"""Bind reviewed 023 sources, computer ROMs and software evidence; no hardware access."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf8'))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-dir', type=Path, required=True)
    p.add_argument('--firmware', type=Path, required=True)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--stack', type=Path, required=True)
    p.add_argument('--rtl', type=Path, required=True)
    p.add_argument('--interfaces', type=Path, required=True)
    p.add_argument('--commit-ack', type=Path,
                   help='Required for candidates using GAME_TARGET_LOCK acceptance tokens')
    p.add_argument('--audio', type=Path, required=True)
    p.add_argument('--numeric', type=Path, required=True)
    p.add_argument('--score', type=Path, required=True)
    p.add_argument('--checkpoint', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    source = a.source_dir.resolve()
    sw = source/'yolo/software'
    out = a.out.resolve()
    require(not out.exists(), 'Never overwrite review evidence')
    sys.path.insert(0, str(Path(__file__).parent/'overnight'))
    from build_full import verify_firmware_sources
    require((source/'yolo/sources/firmware-source-manifest.json').is_file(), 'Missing ROM provenance')
    verify_firmware_sources(source)
    firmware = read(a.firmware/'manifest.json')
    require(firmware == read(source/'yolo/sources/firmware-source-manifest.json'), 'ROM manifest differs')
    require(sha(a.firmware/'firmware.bin') == firmware['firmware_sha256'], 'Firmware binary changed')
    model = read(source/'yolo/model/memory_map.json')
    require(sha(a.checkpoint) == model['checkpoint_sha256'], 'Checkpoint identity mismatch')
    require(model['blob_sha256'] == firmware['model_sha256'], 'Model mismatch')
    evidence = {name: read(getattr(a, name)/'result.json')
                for name in ('native', 'stack', 'rtl', 'interfaces', 'audio', 'numeric', 'score')}
    if 'OSD_ACCEPTANCE_TOKEN' in (sw/'platform_main.c').read_text(encoding='utf8'):
        require(a.commit_ack is not None, 'Missing token-acceptance RTL evidence')
    if a.commit_ack is not None:
        evidence['commit_ack'] = read(a.commit_ack/'result.json')
        require(evidence['commit_ack']['status'] == 'GAME_COMMIT_ACK_RTL_PASS',
                'Token-acceptance RTL did not pass')
        for path, expected in evidence['commit_ack']['source_hashes'].items():
            require(sha(Path(path)) == expected, 'Token-acceptance source changed: '+path)
    for name, r in evidence.items():
        require('PASS' in r['status'], 'Evidence did not pass: '+name)
    require(evidence['stack']['elf_sha256'] == sha(a.firmware/'firmware.elf'), 'Stack audit belongs to another ELF')
    require(evidence['stack']['remaining_bytes'] >= 0, 'Insufficient stack')
    for path, expected in evidence['native']['source_sha256'].items():
        require(sha(Path(path)) == expected, 'Native source changed: '+path)
    for case in evidence['native']['cases'].values():
        for path, expected in case['files'].items():
            require(sha(Path(path)) == expected, 'Test source changed: '+path)
    for name in ('rtl', 'interfaces'):
        for path, expected in evidence[name]['top_files'].items():
            require(sha(Path(path)) == expected, name+' RTL source changed: '+path)
    for path, expected in evidence['interfaces']['omitted_generated_ip_bodies'].items():
        require(sha(Path(path)) == expected, 'Generated IP wrapper changed: '+path)
    for name in ('numeric', 'score'):
        require(evidence[name]['model_sha256'] == model['blob_sha256'], name+' model mismatch')
    score = evidence['score']
    require(score['held_out_test_used'] is False, 'Do not select candidates on final test')
    require(score['numeric_result_sha256'] == sha(a.numeric/'result.json'), 'Numeric report changed')
    require(score['predictions_sha256'] == sha(a.numeric/'predictions.json'), 'Predictions changed')
    for name, expected in score['policy_headers'].items():
        require(sha(sw/name) == expected, 'Selector header changed: '+name)
    rom = source/'extensions/business/application/assets/audio_rom'
    require(sha(rom/'voice_rom_manifest.json') == evidence['audio']['manifest_sha256'], 'Audio manifest changed')
    require(firmware['benchmark_mode'] == 'live' and firmware['board_programmed'] is False,
            'Expected a computer-only live benchmark candidate')
    out.mkdir(parents=True)
    # A complete source snapshot makes ROMs reproducible even if the live candidate changes.
    shutil.copytree(source, out/'source', ignore=shutil.ignore_patterns('__pycache__'))
    inventory = {str(f.relative_to(source)).replace('\\', '/'): sha(f)
                 for f in sorted(source.rglob('*')) if f.is_file() and '__pycache__' not in f.parts}
    for name, expected in inventory.items():
        require(sha(out/'source'/name) == expected, 'Snapshot differs: '+name)
    (out/'source_sha256.json').write_text(json.dumps(inventory, indent=2), encoding='utf8')
    for name in ('manifest.json', 'build.log', 'firmware.elf', 'firmware.map', 'firmware.elf.ltrans0.ltrans.su'):
        shutil.copy2(a.firmware/name, out/('firmware_'+name))
    proof = {}
    for name in evidence:
        directory = getattr(a, name)
        dest = out/name
        dest.mkdir()
        for path in directory.iterdir():
            if path.is_file() and path.suffix in ('.json', '.log'):
                shutil.copy2(path, dest/path.name)
        proof[name] = {'input': str(directory.resolve()), 'result_sha256': sha(directory/'result.json')}
    summary = dict(status='CODE_REVIEW_SNAPSHOT_PASS', created_utc=datetime.now(timezone.utc).isoformat(),
        pnr_performed=False, board_modified=False, camera_accuracy_measured=False,
        coremark_fpga_score_measured=False, stereo_physical_distance_verified=False,
        source_files=len(inventory), source_inventory_sha256=sha(out/'source_sha256.json'),
        firmware_sha256=firmware['firmware_sha256'], firmware_bytes=firmware['firmware_bytes'],
        elf_sha256=sha(a.firmware/'firmware.elf'), model_sha256=model['blob_sha256'],
        checkpoint_sha256=model['checkpoint_sha256'], checkpoint_path=str(a.checkpoint.resolve()),
        stack_available_bytes=evidence['stack']['available_stack_bytes'],
        stack_conservative_chain_bytes=evidence['stack']['conservative_call_chain_bytes'],
        stack_remaining_bytes=evidence['stack']['remaining_bytes'],
        default_stereo_calibration='unverified; full calibrated paths are not enabled or size-approved',
        source_rom_staged_on_computer=True, evidence=proof,
        limits=['Software Q15 replay does not measure camera accuracy.',
                'Top interface elaboration omits generated IP behavior.',
                'Runtime stack water mark and physical timing/area remain unmeasured.',
                'Future PNR and board download require user agreement.'])
    (out/'result.json').write_text(json.dumps(summary, indent=2), encoding='utf8')
    print(json.dumps({k: summary[k] for k in ('status', 'source_files', 'firmware_bytes', 'stack_remaining_bytes')}, indent=2))


if __name__ == '__main__':
    main()
