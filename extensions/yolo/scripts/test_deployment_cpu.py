"""Compare every C CPU operator with the exact deployment arithmetic oracle.

Convolutions are supplied by the Python oracle here; their RTL is separately
tested. This does not claim a full RTL network simulation.
Run inside WSL with a Python that has torch, or use --export on Windows and
--native in WSL (the native side only requires numpy).
"""
import argparse
import ctypes as C
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]


class Tensor(C.Structure):
    _fields_ = [("address", C.c_uint32), ("c", C.c_uint16), ("padded_c", C.c_uint16),
                ("h", C.c_uint16), ("w", C.c_uint16), ("scale", C.c_float)]


class Layer(C.Structure):
    _fields_ = [(n, C.c_uint32) for n in ("a_base", "w_base", "q_base", "t_base", "y_base")] + [
        (n, C.c_uint16) for n in ("cin", "cout", "in_w", "in_h", "out_w", "out_h")] + [
        (n, C.c_uint8) for n in ("k", "stride", "pad", "act", "tr")]


class Op(C.Structure):
    _fields_ = [(n, C.c_uint8) for n in ("kind", "count", "kernel", "stride")] + [
        ("inputs", C.c_uint16*4), ("output", C.c_uint16), ("ratios", C.c_uint32*4),
        ("conv", Layer), ("head_weight", C.c_uint32), ("head_bias", C.c_uint32)]


def export(path):
    import torch
    from deployment_bundle import Deployment
    torch.set_num_threads(4)
    deployment = Deployment(ROOT/"gen/integration/deployment")
    rng = np.random.default_rng(193)
    image = torch.from_numpy(rng.random((1, 3, 320, 320), dtype=np.float32))
    outputs = {}
    with torch.no_grad():
        deployment.execute(image, lambda op, value: outputs.update({f'op{op["idx"]}': value}))
    np.savez(path, **outputs)
    graph = json.loads((ROOT/"gen/integration/packed/memory_map.json").read_text())
    packed_input = np.zeros((320, 320, 8), dtype=np.int8)
    packed_input[..., :3] = np.floor(
        image.numpy()[0].transpose(1, 2, 0)*127+0.5).astype(np.int8)
    path.with_suffix(".input.bin").write_bytes(packed_input.tobytes())
    tensors = (Tensor*len(graph["tensors"]))(
        *[Tensor(**{k:v for k,v in t.items() if k != "fp32"}) for t in graph["tensors"]])
    import struct
    with path.with_suffix(".bin").open("wb") as handle:
        handle.write(struct.pack("<4I", len(tensors), len(graph["ops"]), C.sizeof(Tensor), C.sizeof(Op)))
        handle.write(bytes(tensors))
        for index, item in enumerate(graph["ops"]):
            keys = {k:v for k,v in item.items()
                    if k not in ("kind", "inputs", "ratios", "conv")}
            op = Op(kind=["YOLO_CONV", "YOLO_POOL", "YOLO_UPSAMPLE", "YOLO_CONCAT",
                          "YOLO_ADD", "YOLO_HEAD"].index(item["kind"]),
                    inputs=(C.c_uint16*4)(*item["inputs"]),
                    ratios=(C.c_uint32*4)(*item["ratios"]),
                    conv=Layer(**item.get("conv", {})), **keys)
            oracle = outputs[f"op{index}"][0].transpose(1, 2, 0)
            t = graph["tensors"][item["output"]]
            expected = np.zeros((t["h"], t["w"], t["padded_c"]), oracle.dtype)
            expected[..., :t["c"]] = oracle
            handle.write(bytes(op))
            handle.write(struct.pack("<I", expected.nbytes))
            handle.write(expected.tobytes())
    print(f"ORACLE_EXPORTED {len(outputs)} operator outputs")


def native(library, vectors):
    graph = json.loads((ROOT/"gen/integration/packed/memory_map.json").read_text())
    lib = C.CDLL(str(library.resolve()))
    lib.native_put.argtypes = [C.c_uint32, C.c_void_p, C.c_uint32]
    lib.native_get.argtypes = [C.c_uint32, C.c_void_p, C.c_uint32]
    lib.native_op.argtypes = [C.POINTER(Op), C.POINTER(Tensor)]
    data = np.load(vectors)
    blob = (ROOT/"gen/integration/packed/model.bin").read_bytes()
    assert lib.native_put(graph["blob_base"], blob, len(blob)) == 0
    tensors = (Tensor*len(graph["tensors"]))(
        *[Tensor(**{k:v for k,v in t.items() if k != "fp32"}) for t in graph["tensors"]])
    passed = 0
    for index, item in enumerate(graph["ops"]):
        output = graph["tensors"][item["output"]]
        oracle = data[f"op{index}"][0].transpose(1, 2, 0)
        expected = np.zeros((output["h"], output["w"], output["padded_c"]), oracle.dtype)
        expected[..., :output["c"]] = oracle
        if item["kind"] != "YOLO_CONV":
            keys = {k:v for k,v in item.items()
                    if k not in ("kind", "inputs", "ratios", "conv")}
            op = Op(kind=["YOLO_CONV", "YOLO_POOL", "YOLO_UPSAMPLE", "YOLO_CONCAT",
                          "YOLO_ADD", "YOLO_HEAD"].index(item["kind"]),
                    inputs=(C.c_uint16*4)(*item["inputs"]),
                    ratios=(C.c_uint32*4)(*item["ratios"]), **keys)
            assert lib.native_op(C.byref(op), tensors) == 0, index
            actual = np.empty_like(expected)
            assert lib.native_get(output["address"], actual.ctypes.data, actual.nbytes) == 0
            if item["kind"] == "YOLO_HEAD":
                np.testing.assert_allclose(actual, expected, atol=3e-5, rtol=2e-5,
                                           err_msg=f"op {index}")
            else:
                np.testing.assert_array_equal(actual, expected, err_msg=f"op {index}")
            passed += 1
        assert lib.native_put(output["address"], expected.ctypes.data, expected.nbytes) == 0
    print(f"CPU_GRAPH_PASS {passed} CPU operators; convolution outputs supplied by oracle")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--vectors", type=Path, default=ROOT/"gen/integration/cpu_oracle.npz")
    args = parser.parse_args()
    if args.export:
        export(args.export)
    if args.native:
        native(args.native, args.vectors)
