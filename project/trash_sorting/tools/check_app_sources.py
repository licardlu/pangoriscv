"""Check the application RTL dependency closure, using only files in this package.

Why this exists: PDS/ADS resolves `$readmemh` / `$readmemb` against the
*process working directory*, not against the RTL file that contains them. A
missing ROM file does not fail synthesis, it silently produces a zero-filled
memory, so the CPU never boots and the voice prompt is silent. This script
reproduces the resolution rules of `source/yolo/build_pre_pnr.tcl` and reports
what would actually be loaded.

Usage (from the repository root or from project/trash_sorting):

    python project/trash_sorting/tools/check_app_sources.py
    python project/trash_sorting/tools/check_app_sources.py --verbose

Exit code 0 = every selected design file, every `include` and every active
`$readmem*` target resolves. Non-zero = at least one would fail on a clean
machine. Nothing is written to disk.
"""
import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
APP_ROOT = HERE.parents[1]                 # project/trash_sorting
YOLO = APP_ROOT / 'source' / 'yolo'
SRC = YOLO / 'sources'
PORTABLE = YOLO / 'portable'
BUSINESS = APP_ROOT / 'source' / 'extensions' / 'business' / 'application'
TCL = YOLO / 'build_pre_pnr.tcl'


def tcl_paths(text, pkg_dir, src_dir, business_dir):
    """Resolve every `[file join ...]` argument of add_design/add_constraint."""
    subs = {'$pkg_dir': str(pkg_dir), '$src_dir': str(src_dir), '$business_dir': str(business_dir)}
    out = []
    for kind, expr in re.findall(r'(add_design|add_constraint)\s+(\[[^\]]*\])', text):
        inner = re.match(r'\[file join (.*)\]', expr.strip())
        if not inner:
            out.append((kind, expr, None))
            continue
        parts = []
        for token in inner.group(1).split():
            parts.append(subs.get(token, token))
        path = Path(parts[0]).joinpath(*parts[1:]) if len(parts) > 1 else Path(parts[0])
        out.append((kind, expr, path))
    return out


def includes_of(path):
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return []
    return re.findall(r'`include\s+"([^"]+)"', text)


def readmem_of(path):
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return []
    return re.findall(r'\$readmem[hb]\(\s*"([^"]+)"', text)


def voice_bank_count():
    """BANK_COUNT = ceil(ROM_SAMPLES / BANK_SIZE); only these banks elaborate."""
    player = BUSINESS / 'rtl' / 'trash_voice_rom_player.v'
    if not player.is_file():
        return None
    text = player.read_text(encoding='utf-8', errors='replace')
    samples = re.search(r'ROM_SAMPLES\s*=\s*(\d+)', text)
    shift = re.search(r'BANK_AW\s*=\s*(\d+)', text)
    if not samples or not shift:
        return None
    return -(-int(samples.group(1)) // (1 << int(shift.group(1))))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--verbose', action='store_true', help='print every resolved path')
    args = ap.parse_args()

    problems = []

    if not TCL.is_file():
        print('FAIL missing build entry: %s' % TCL)
        return 1

    items = tcl_paths(TCL.read_text(encoding='utf-8', errors='replace'), YOLO, SRC, BUSINESS)
    designs = [(k, e, p) for k, e, p in items if k == 'add_design']
    constraints = [(k, e, p) for k, e, p in items if k == 'add_constraint']
    for kind, expr, path in items:
        if path is None or not path.is_file():
            problems.append('%s does not resolve: %s' % (kind, expr))
        elif args.verbose:
            print('  ok  %-15s %s' % (kind, path.relative_to(APP_ROOT)))

    # include closure. build_pre_pnr.tcl passes -include_path with sources/include
    # and the business rtl directory; headers are also allowed next to the source.
    search = [SRC / 'include', BUSINESS / 'rtl', SRC, BUSINESS]
    seen_includes = 0
    for kind, expr, path in designs:
        if path is None or not path.is_file() or path.suffix.lower() not in ('.v', '.sv'):
            continue
        for inc in includes_of(path):
            seen_includes += 1
            if not any((base / inc).is_file() for base in search + [path.parent]):
                problems.append('include "%s" from %s not found' % (inc, path.name))

    # $readmemh/$readmemb. Synthesis cwd is source/yolo/sources, so a relative
    # literal is resolved against that directory.
    banks = voice_bank_count()
    active_reads = 0
    inactive_reads = 0
    for kind, expr, path in designs:
        if path is None or not path.is_file():
            continue
        for literal in readmem_of(path):
            match = re.search(r'\.bank(\d+)\.hex$', literal)
            if match and banks is not None and int(match.group(1)) >= banks:
                # Branch exists in the case statement but is never elaborated
                # because BANK_COUNT stops below it. Not a dependency.
                inactive_reads += 1
                continue
            if re.match(r'^[A-Za-z]:[\\/]', literal):
                problems.append('absolute path in %s: %s' % (path.name, literal))
                continue
            active_reads += 1
            if not (SRC / literal).is_file():
                problems.append('%s reads "%s" which is not under %s'
                                % (path.name, literal, SRC.relative_to(APP_ROOT).as_posix()))

    # The 8 firmware lanes are the CPU program. Fail loudly if they are absent:
    # a build without them still "succeeds" and produces a dead bitstream.
    lanes = sorted(SRC.glob('firmware_lane*.bin'))
    if len(lanes) != 8:
        problems.append('expected 8 firmware_lane*.bin in %s, found %d'
                        % (SRC.relative_to(APP_ROOT).as_posix(), len(lanes)))

    print('entry            : %s' % TCL.relative_to(APP_ROOT).as_posix())
    print('design files     : %d (.v/.sv: %d, .idf: %d)'
          % (len(designs),
             sum(1 for _, _, p in designs if p and p.suffix.lower() in ('.v', '.sv')),
             sum(1 for _, _, p in designs if p and p.suffix.lower() == '.idf')))
    print('constraints      : %d' % len(constraints))
    print('include targets  : %d' % seen_includes)
    print('readmem literals : %d active, %d never elaborated (bank >= %s)'
          % (active_reads, inactive_reads, banks))
    print('firmware lanes   : %d' % len(lanes))
    if problems:
        print('\nFAIL %d problem(s):' % len(problems))
        for p in problems:
            print('  - ' + p)
        return 1
    print('\nPASS application source closure')
    return 0


if __name__ == '__main__':
    sys.exit(main())
