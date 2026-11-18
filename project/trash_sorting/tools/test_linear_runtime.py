"""Check production-size C linear operators against independent integer Q24 math.

Host arithmetic only; this is not a RISC-V execution or speed measurement.
"""
import argparse
import ctypes as C
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cc', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--source-dir', type=Path, default=ROOT/'project/trash_sorting/source')
    p.add_argument('--compact-scratch', action='store_true')
    a = p.parse_args()
    a.out = a.out.resolve()
    a.out.mkdir(parents=True, exist_ok=False)
    (a.out/'temp').mkdir()
    sys.path.insert(0, str(ROOT/'extensions/yolo/scripts'))
    import numpy as np
    from test_deployment_cpu import Tensor, Op
    sw = a.source_dir.resolve()/'yolo/software'
    cc = a.cc.resolve()
    env = os.environ.copy()
    env['PATH'] = str(cc.parent)+os.pathsep+env.get('PATH', '')
    env['TMP'] = env['TEMP'] = str(a.out/'temp')
    env['ZIG_GLOBAL_CACHE_DIR'] = str(a.out/'zig-cache')
    rng = np.random.default_rng(20261113)

    def rounded(x):
        return np.clip(np.sign(x)*((np.abs(x)+(1 << 23)) >> 24), -128, 127).astype(np.int8)

    cases = []
    # All 65,536 signed byte pairs, including positive/negative half ties.
    grid = np.arange(-128, 128, dtype=np.int64)
    left = np.repeat(grid, 256).reshape(16, 256, 16).astype(np.int8)
    right = np.tile(grid, 256).reshape(left.shape).astype(np.int8)
    deployed = json.loads((a.source_dir.resolve()/'yolo/model/memory_map.json').read_text(encoding='utf8'))
    actual_ratios = [tuple(op['ratios']) for op in deployed['ops'] if op['kind']=='YOLO_ADD']
    for ratios in [(1 << 23, 1 << 23), (14618280, 11736629),
                   (1 << 24, 1 << 24), (0, 0), (0xffffffff, 1),
                   ((1 << 24)+1,1 << 24), ((1 << 24)-1,1 << 24),
                   (0,1 << 24), (1,1), *actual_ratios]:
        expect = rounded(left.astype(np.int64)*ratios[0]+right.astype(np.int64)*ratios[1])
        cases.append(('ADD', [left, right], ratios, expect))
    for channels in [(8, 16), (16, 16), (32, 64), (128, 128), (256, 256, 256, 256)]:
        inputs = [rng.integers(-128, 128, (3, 37, c), dtype=np.int16).astype(np.int8) for c in channels]
        ratios = [16777216, 13693892, 7201221, 1 << 23][:len(inputs)]
        expect = np.concatenate([rounded(x.astype(np.int64)*r) for x, r in zip(inputs, ratios)], axis=2)
        cases.append(('CONCAT', inputs, ratios, expect))
    for channels in (8, 32, 128, 256):
        x = rng.integers(-128, 128, (3, 37, channels), dtype=np.int16).astype(np.int8)
        for ratio in (16777216, 9838601, 1 << 23):
            expect = np.repeat(np.repeat(rounded(x.astype(np.int64)*ratio), 2, axis=0), 2, axis=1)
            cases.append(('UPSAMPLE', [x], [ratio], expect))
    # Row sizes straddle the compact 768-byte cache boundary and original
    # 1536-byte limit. Include real 20x20x128 SPP rows and negative padding.
    for h,w,c in ((1,1,8),(5,95,8),(5,96,8),(5,97,8),(5,192,8),(20,20,128)):
        x=rng.integers(-128,128,(h,w,c),dtype=np.int16).astype(np.int8)
        padded=np.pad(x,((2,2),(2,2),(0,0)),constant_values=-128)
        expect=np.full_like(x,-128)
        for dy in range(5):
            for dx in range(5):expect=np.maximum(expect,padded[dy:dy+h,dx:dx+w])
        cases.append(('POOL',[x],[1<<24],expect))
    results = []
    for optimized, packed in ((False,False),(True,False),(False,True),(True,True)):
        dll = a.out/f'linear_o2{int(optimized)}_packed{int(packed)}.dll'
        command = [str(cc), '-std=c11', '-Os', '-Wall', '-Wextra', '-Werror',
                   '-Wno-unused-function', '-shared', '-I'+str(sw)]
        if a.compact_scratch:command.append('-DYOLO_COMPACT_SCRATCH')
        if optimized:
            command.append('-DYOLO_LINEAR_O2')
        if packed:
            command.append('-DYOLO_PACKED_ADD')
        command += [str(sw/'yolo_runtime.c'), str(ROOT/'extensions/yolo/tb/deployment_native.c'), '-lm', '-o', str(dll)]
        r = subprocess.run(command, env=env, capture_output=True, text=True)
        (a.out/(dll.stem+'.log')).write_text(r.stdout+r.stderr, encoding='utf8')
        r.check_returncode()
        lib = C.CDLL(str(dll))
        lib.native_put.argtypes = lib.native_get.argtypes = [C.c_uint32, C.c_void_p, C.c_uint32]
        lib.native_op.argtypes = [C.POINTER(Op), C.POINTER(Tensor)]
        lib.native_set_options.argtypes = [C.c_uint32]
        checked = 0
        for kind, inputs, ratios, expect in cases:
            ts = [Tensor(0x1000+i*0x20000, x.shape[2], x.shape[2], x.shape[0], x.shape[1], 1) for i, x in enumerate(inputs)]
            ts += [Tensor(0x100000, expect.shape[2], expect.shape[2], expect.shape[0], expect.shape[1], 1)]
            tensors = (Tensor*len(ts))(*ts)
            op = Op(kind={'ADD':4, 'CONCAT':3, 'UPSAMPLE':2,'POOL':1}[kind], count=len(inputs),kernel=5 if kind=='POOL' else 0,stride=1,
                    inputs=(C.c_uint16*4)(*range(len(inputs))), output=len(inputs), ratios=(C.c_uint32*4)(*ratios))
            for mode in (0, 4 if kind=='POOL' else 2):
                for t, x in zip(ts, inputs):
                    assert lib.native_put(t.address, x.ctypes.data, x.nbytes) == 0
                guard = np.full(expect.nbytes+32, 0xa5, dtype=np.uint8)
                assert lib.native_put(0x100000-16, guard.ctypes.data, guard.nbytes) == 0
                lib.native_set_options(mode)
                assert lib.native_op(C.byref(op), tensors) == 0, (kind, mode)
                actual = np.empty_like(guard)
                assert lib.native_get(0x100000-16, actual.ctypes.data, actual.nbytes) == 0
                np.testing.assert_array_equal(actual[16:-16].view(np.int8).reshape(expect.shape), expect,
                                              err_msg=str((optimized, kind, mode, ratios)))
                np.testing.assert_array_equal(actual[:16], guard[:16])
                np.testing.assert_array_equal(actual[-16:], guard[-16:])
                checked += 1
        results.append(dict(linear_o2=optimized, packed_add=packed, checked=checked, compiler_command=command))
    report = dict(status='PASS_HOST_ARITHMETIC_NOT_BOARD_SPEED', builds=results,
                  runtime_sha256=hashlib.sha256((sw/'yolo_runtime.c').read_bytes()).hexdigest(),
                  script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  includes='all signed ADD pairs, half ties/saturation, chunk boundaries, guard bytes, CONCAT up to 4 inputs, UPSAMPLE, POOL cache/fallback boundaries')
    (a.out/'result.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print('TEST_PASS linear Os/O2 with exact Q24 oracle', flush=True)


if __name__ == '__main__':
    main()
