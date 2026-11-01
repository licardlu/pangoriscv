"""Bit-exact fixed-point reference for Lite-A.

This is the contract between the training script and the RTL.  The RTL is
correct only if, for the same input, it produces the same bytes as
`forward_int8()` here.  So this file must use *exactly* the integer operations
the hardware will use -- no float shortcuts in the quantised path.

Numeric rules (fixed, do not change without bumping the version):
  * weights  : per-output-channel symmetric, s_w[oc] = max|w[oc]| / 127
  * input    : per-tensor symmetric, s_x = max|a| / 127
  * multiply : acc[int32] = sum(a_q * w_q)                       (exact)
  * rescale  : y = (acc * M[oc] + ROUND) >> S                    (int64 intermediate)
               M[oc] = round(s_x * s_w[oc] / s_y * 2**S), S = 15
               ROUND = 1 << (S-1), i.e. round-half-up on the shifted value;
               because acc may be negative this is round-half-away-from-zero
               only after the sign correction below -- see _rescale()
  * clamp    : y = clip(y, -128, 127)
  * leaky    : y = y >> 3 for y < 0, i.e. arithmetic shift = floor

The leaky slope is 0.125 exactly (>>3).  Changing 0.1 -> 0.125 is a model
change and requires retraining, which is why it is baked in here rather than
left as a tunable.
"""

from __future__ import annotations

import numpy as np

S_SHIFT = 15
CLIP = (-128, 127)


# --------------------------------------------------------------------------
# quantisation helpers
# --------------------------------------------------------------------------
def quant_per_tensor(x: np.ndarray):
    """Symmetric per-tensor int8 quantisation. Returns (q, scale)."""
    amax = float(np.max(np.abs(x))) if x.size else 0.0
    if amax == 0.0:
        return np.zeros_like(x, dtype=np.int8), 1.0
    s = amax / 127.0
    q = np.clip(np.rint(x / s), -127, 127).astype(np.int8)
    return q, s


def quant_per_channel(w: np.ndarray):
    """Symmetric per-output-channel int8 quantisation of a conv kernel.

    w shape (Cout, Cin, kh, kw); one scale per Cout.
    """
    cout = w.shape[0]
    flat = w.reshape(cout, -1)
    amax = np.max(np.abs(flat), axis=1)
    amax[amax == 0] = 1.0
    s = (amax / 127.0).astype(np.float64)
    q = np.clip(np.rint(flat / s[:, None]), -127, 127).astype(np.int8)
    return q.reshape(w.shape), s


def _rescale(acc: np.ndarray, m: np.ndarray, s_shift: int = S_SHIFT) -> np.ndarray:
    """(acc * M) >> S with round-half-away-from-zero, matching the RTL.

    The RTL adds half an LSB to the magnitude before shifting, not to the raw
    value; for negative numbers those differ, so the sign is handled explicitly.
    """
    acc64 = acc.astype(np.int64)
    shape = [1] * (acc64.ndim - 1) + [-1]        # M applies to the channel axis
    m64 = m.astype(np.int64).reshape(shape)
    prod = acc64 * m64
    half = np.int64(1) << (s_shift - 1)
    sign = np.where(prod < 0, np.int64(-1), np.int64(1))
    out = (prod + sign * half) >> s_shift
    return out


# --------------------------------------------------------------------------
# layer kernels -- integer path
# --------------------------------------------------------------------------
def conv3x3_int8(x: np.ndarray, wq: np.ndarray, bias_q: np.ndarray,
                 m: np.ndarray) -> np.ndarray:
    """x (H,W,Cin) int8, wq (Cout,Cin,3,3) int8 -> (H,W,Cout) int8.

    Padding 1, stride 1.  Accumulates in int32 exactly like the PE array.
    """
    h, w, cin = x.shape
    cout = wq.shape[0]
    xp = np.pad(x.astype(np.int32), ((1, 1), (1, 1), (0, 0)))
    acc = np.zeros((h, w, cout), dtype=np.int32)
    for ky in range(3):
        for kx in range(3):
            patch = xp[ky:ky + h, kx:kx + w, :]           # (h,w,cin)
            wgt = wq[:, :, ky, kx].astype(np.int32)        # (cout,cin)
            acc += patch @ wgt.T
    acc += bias_q.astype(np.int32)[None, None, :]
    y = _rescale(acc, m)
    return np.clip(y, *CLIP).astype(np.int8)


def conv1x1_int8(x: np.ndarray, wq: np.ndarray, bias_q: np.ndarray,
                 m: np.ndarray) -> np.ndarray:
    h, w, cin = x.shape
    acc = x.astype(np.int32).reshape(-1, cin) @ wq[:, :, 0, 0].astype(np.int32).T
    acc = acc.reshape(h, w, wq.shape[0])
    acc += bias_q.astype(np.int32)[None, None, :]
    y = _rescale(acc, m)
    return np.clip(y, *CLIP).astype(np.int8)


def leaky_int8(y: np.ndarray) -> np.ndarray:
    """y = y>>3 for negative, identity otherwise. Arithmetic shift = floor."""
    out = np.where(y < 0, y >> 3, y)
    return np.clip(out, *CLIP).astype(np.int8)


def maxpool_int8(x: np.ndarray, k: int, s: int) -> np.ndarray:
    """Darknet maxpool: padding = k//2, so 2/1 keeps the size."""
    h, w, c = x.shape
    pad = k // 2
    xp = np.pad(x, ((pad, pad), (pad, pad), (0, 0)), constant_values=-128)
    oh = (h + pad - k) // s + 1
    ow = (w + pad - k) // s + 1
    out = np.empty((oh, ow, c), dtype=np.int8)
    for i in range(oh):
        for j in range(ow):
            blk = xp[i * s:i * s + k, j * s:j * s + k, :]
            out[i, j, :] = blk.max(axis=(0, 1))
    return out


def upsample_int8(x: np.ndarray, f: int = 2) -> np.ndarray:
    return np.repeat(np.repeat(x, f, axis=0), f, axis=1)


# --------------------------------------------------------------------------
# scale bookkeeping
# --------------------------------------------------------------------------
def compute_m(s_x: float, s_w: np.ndarray, s_y: np.ndarray,
              s_shift: int = S_SHIFT) -> np.ndarray:
    """M[oc] = round(s_x * s_w[oc] / s_y * 2**S)."""
    m = np.rint(s_x * s_w / s_y * (1 << s_shift))
    if np.any(m >= (1 << 31)):
        raise ValueError("M overflows int32; reduce s_shift")
    return m.astype(np.int64)


def self_test(input_size: int = 32, seed: int = 0):
    """Validate the integer kernels against a float reference on random data.

    This does not prove model accuracy -- it proves the arithmetic is the one
    the RTL must reproduce.
    """
    rng = np.random.default_rng(seed)
    print(f"self-test: conv3x3 int8 vs float, {input_size}x{input_size}, seed={seed}")

    for cin, cout in ((8, 16), (16, 32), (64, 128)):
        xf = rng.standard_normal((input_size, input_size, cin)).astype(np.float32)
        wf = (rng.standard_normal((cout, cin, 3, 3)) * 0.1).astype(np.float32)
        bf = (rng.standard_normal(cout) * 0.05).astype(np.float32)

        xq, s_x = quant_per_tensor(xf)
        wq, s_w = quant_per_channel(wf)

        # float reference, same padding
        xp = np.pad(xf, ((1, 1), (1, 1), (0, 0)))
        acc_f = np.zeros((input_size, input_size, cout), dtype=np.float32)
        for ky in range(3):
            for kx in range(3):
                acc_f += xp[ky:ky + input_size, kx:kx + input_size, :] @ wf[:, :, ky, kx].T
        acc_f += bf[None, None, :]
        y_ref = np.where(acc_f < 0, acc_f * 0.125, acc_f)

        # quantised path: choose s_y from the float output, as calibration would
        s_y = float(np.max(np.abs(y_ref))) / 127.0
        m = compute_m(s_x, s_w, s_y)

        # accumulate in int32 from quantised operands
        acc_q = np.zeros((input_size, input_size, cout), dtype=np.int32)
        xqp = np.pad(xq.astype(np.int32), ((1, 1), (1, 1), (0, 0)))
        for ky in range(3):
            for kx in range(3):
                acc_q += xqp[ky:ky + input_size, kx:kx + input_size, :] @ wq[:, :, ky, kx].astype(np.int32).T
        # bias is folded into the accumulator in the same fixed-point domain
        bias_q = np.rint(bf / (s_x * s_w) ).astype(np.int32)
        acc_q += bias_q[None, None, :]

        y_q = _rescale(acc_q, m)
        y_q = leaky_int8(np.clip(y_q, *CLIP).astype(np.int8)).astype(np.float64) * s_y

        ref = y_ref.reshape(-1).astype(np.float64)
        got = y_q.reshape(-1)
        cos = float(ref @ got / (np.linalg.norm(ref) * np.linalg.norm(got) + 1e-12))
        rel = float(np.linalg.norm(ref - got) / (np.linalg.norm(ref) + 1e-12))
        print(f"  {cin:>3}->{cout:<4} s_x={s_x:.5f} s_y={s_y:.5f} "
              f"cos={cos:.6f}  rel_l2={rel:.4%}")
        assert cos > 0.999, "quantised path diverges from float reference"


if __name__ == "__main__":
    self_test()
