"""Assess measured CPU cycles. Synthetic unit-test inputs are never board evidence."""
import math
import re


def assess(total_ticks, iterations, cpu_hz, crc_valid):
    if (not all(math.isfinite(x) and x > 0 for x in (total_ticks, iterations, cpu_hz))
            or int(iterations) != iterations or int(total_ticks) != total_ticks):
        raise ValueError('positive integral ticks/iterations and positive CPU frequency required')
    seconds = total_ticks / cpu_hz
    score = iterations * 1_000_000 / total_ticks
    return {
        'total_ticks': total_ticks,
        'iterations': iterations,
        'cpu_hz': cpu_hz,
        'seconds': seconds,
        'coremark_per_mhz': score,
        'crc_valid': bool(crc_valid),
        'meets_target': bool(crc_valid and seconds >= 10 and score >= 5.2 and cpu_hz >= 120_000_000),
    }


def parse_uart(report):
    if report.count('BENCH_DONE') != 1:
        raise ValueError('expected exactly one completed benchmark report')
    fields = {}
    for name, pattern in {
        'cpu_hz': r'^CPU_HZ=(\d+)$',
        'iterations': r'^Iterations\s*:\s*(\d+)$',
        'seedcrc': r'^seedcrc\s*:\s*0x([0-9a-fA-F]+)$',
        'crclist': r'^\[0\]crclist\s*:\s*0x([0-9a-fA-F]+)$',
        'crcmatrix': r'^\[0\]crcmatrix\s*:\s*0x([0-9a-fA-F]+)$',
        'crcstate': r'^\[0\]crcstate\s*:\s*0x([0-9a-fA-F]+)$',
        'crcfinal': r'^\[0\]crcfinal\s*:\s*0x([0-9a-fA-F]+)$',
        'ticks_hi': r'^TICKS_HI=(\d+)$',
        'ticks_lo': r'^TICKS_LO=(\d+)$',
    }.items():
        matches = re.findall(pattern, report, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f'expected one {name} field')
        fields[name] = int(matches[0], 16 if name.startswith('crc') or name == 'seedcrc' else 10)
    fields['total_ticks'] = fields['ticks_hi'] * (1 << 32) + fields['ticks_lo']
    if fields['ticks_hi'] >= 1 << 32 or fields['ticks_lo'] >= 1 << 32:
        raise ValueError('counter words must be unsigned 32-bit values')
    if any(fields[k] > 0xffff for k in ('seedcrc', 'crclist', 'crcmatrix', 'crcstate', 'crcfinal')):
        raise ValueError('CRC words must be unsigned 16-bit values')
    banners = re.findall(r'^ITERATIONS=(\d+)$', report, re.MULTILINE)
    if banners and (len(banners) != 1 or int(banners[0]) != fields['iterations']):
        raise ValueError('firmware and benchmark iteration counts differ')
    fields['crc_valid'] = bool(
        'Correct operation validated.' in report
        and not re.search(r'ERROR!|Errors detected|TRAP cause=', report, re.IGNORECASE)
        and fields['seedcrc'] == 0xe9f5
        and fields['crclist'] == 0xe714
        and fields['crcmatrix'] == 0x1fd7
        and fields['crcstate'] == 0x8e3a
    )
    result = assess(fields['total_ticks'], fields['iterations'], fields['cpu_hz'], fields['crc_valid'])
    return {**fields, **result, 'board_verified': False}
