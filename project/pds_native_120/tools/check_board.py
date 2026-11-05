"""Validate a real captured CoreMark run against the frozen board baseline."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def check(directory):
    directory = Path(directory).resolve()
    raw = (directory/'uart.log').read_bytes()
    text = raw.decode('utf-8')
    metadata = json.loads((directory/'board_capture.json').read_text(encoding='utf-8-sig'))
    expected_sha = metadata['bitstream_sha256'].lower()
    recorded = (ROOT/metadata['bitstream']).resolve()
    bit = recorded
    relocated = ''
    if not bit.is_file() or hashlib.sha256(bit.read_bytes()).hexdigest() != expected_sha:
        # The capture may name a build/ path that was cleaned out of the
        # package. Identity is the SHA, not the path: accept any packaged
        # bitstream with the same bytes and say which one was used.
        for candidate in sorted(ROOT.rglob('*.sbit')):
            if hashlib.sha256(candidate.read_bytes()).hexdigest() == expected_sha:
                bit = candidate
                relocated = candidate.relative_to(ROOT).as_posix()
                break
        else:
            raise ValueError('No packaged bitstream matches the captured SHA256: ' + expected_sha)
    # A capture taken against a shipped bitstream has no build database. Only
    # cross-check the build record when that record is still present; never
    # invent a timing verdict when the report is absent.
    sta = None
    build_record_available = False
    build_name = (metadata.get('build') or '').strip()
    if build_name and (ROOT/build_name/'build_result.json').is_file():
        build = (ROOT/build_name).resolve()
        if not build.is_relative_to(ROOT):
            raise ValueError('Capture build path outside package')
        build_result = json.loads((build/'build_result.json').read_text())
        if build_result['sha256'] != expected_sha or len(build_result['final_timing']) != 1:
            raise ValueError('Capture/build identity mismatch')
        timing = (ROOT/build_result['final_timing'][0]).resolve()
        if not timing.is_relative_to(ROOT):
            raise ValueError('Timing path outside package')
        sta = 'Design Summary : All Constraints Met.' in timing.read_text(errors='replace')
        build_record_available = True
    trace = (directory/'program_trace.txt').read_text()
    if not re.search(r'^program OK: 1\r?$', trace, re.M) or not re.search(r'^id OK:\s*(?:0x)?00602899\s*$', trace, re.M | re.I):
        raise ValueError('Missing successful programming/device ID')
    if not re.search(r'^BENCH_DONE\r?$', text, re.M) or 'Correct operation validated.' not in text:
        raise ValueError('Incomplete or invalid CoreMark run')
    def number(pattern):
        values = re.findall(pattern, text, re.M)
        if len(values) != 1:
            raise ValueError('Missing or ambiguous benchmark field: ' + pattern)
        return int(values[0], 0)
    hz = number(r'^CPU_HZ=(\d+)\r?$')
    iterations = number(r'^ITERATIONS=(\d+)\r?$')
    ticks = number(r'^Total ticks\s*:\s*(\d+)\r?$')
    if number(r'^TICKS_HI=(\d+)\r?$')*(1 << 32) + number(r'^TICKS_LO=(\d+)\r?$') != ticks:
        raise ValueError('Full tick counter fields disagree')
    crc = {}
    for name, expected in [('seedcrc', 0xe9f5), ('crclist', 0xe714), ('crcmatrix', 0x1fd7),
                           ('crcstate', 0x8e3a), ('crcfinal', 0x25b5)]:
        crc[name] = number(r'^(?:\[0\])?' + name + r'\s*:\s*(0x[0-9a-fA-F]+)\r?$')
        if crc[name] != expected:
            raise ValueError('CRC mismatch: ' + name)
    if (hz, iterations, ticks) != (120461538, 7000, 1309328358) or ticks/hz < 10:
        raise ValueError('Clock, iterations or ticks differ from frozen reference')
    result = {'status': 'PASS', 'board_verified': True, 'bitstream_sha256': expected_sha,
              'cpu_hz': hz, 'iterations': iterations, 'ticks': ticks, 'crc': crc,
              'seconds': ticks/hz, 'coremark_per_mhz': iterations*1000000/ticks,
              'uart_sha256': hashlib.sha256(raw).hexdigest(), 'performance_parity': True,
              'sta_closed': sta, 'build_record_available': build_record_available,
              'full_semantic_modularization_complete': False}
    if relocated:
        result['bitstream_relocated_to'] = relocated
        result['bitstream_recorded_path'] = metadata['bitstream']
    # Never overwrite an archived measurement; a re-check goes to a new name.
    target = directory/'measurement.json'
    if target.exists():
        target = directory/'measurement.recheck.json'
    target.write_text(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.directory), indent=2))
