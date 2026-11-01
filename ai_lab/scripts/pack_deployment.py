"""Pack the graph-aware arithmetic bundle for CPU + conv_band_rt.

Tensors do not alias: explicit ownership takes priority over DDR optimization.
Addresses are byte addresses at the accelerator.
"""
import argparse
import hashlib
import json
import zlib
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
KINDS = {"CONV": "YOLO_CONV", "ADD": "YOLO_ADD", "CONCAT": "YOLO_CONCAT",
         "MAXPOOL": "YOLO_POOL", "UPSAMPLE": "YOLO_UPSAMPLE"}


def align(n, boundary=256):
    return (n + boundary - 1) // boundary * boundary


def pack(source, output, base=0x01000000, tensor_base=0x02000000):
    graph = json.loads((source / "bundle.json").read_text())
    arrays = np.load(source / "parameters.npz")
    blob, regions = bytearray(), []

    def append(name, array):
        offset = align(len(blob))
        blob.extend(bytes(offset - len(blob)))
        payload = array.tobytes(order="C")
        address = base + offset
        blob.extend(payload)
        regions.append(dict(name=name, address=address, length=len(payload), load=True))
        return address

    cursor, tensors = tensor_base, []
    for idx in range(-1, len(graph["ops"])):
        op = graph["ops"][idx] if idx >= 0 else None
        c, h, w = op["out_shape"] if op else (3, graph["size"], graph["size"])
        pc = align(c, 8)
        fp32 = op is not None and op["execution"] == "cpu_fp32_head"
        length = pc*h*w*(4 if fp32 else 1)
        tensors.append(dict(address=cursor, c=c, padded_c=pc, h=h, w=w,
                            scale=float(op["scale"] if op else graph["input_scale"]),
                            fp32=fp32))
        regions.append(dict(name=f"tensor{idx+1}", address=cursor, length=length, load=False))
        cursor = align(cursor + length)
    ops = []
    for original in graph["ops"]:
        idx = original["idx"]
        prefix = f"op{idx}_"
        item = dict(kind=KINDS[original["name"]], count=len(original["inputs"]),
                    inputs=[r+1 for r in original["inputs"]], output=idx+1,
                    kernel=original.get("k", 0), stride=original.get("stride", 0),
                    ratios=[int(np.floor(s/original["scale"]*(1 << 24)+0.5))
                            for s in original["input_scales"]])
        if any(r < 0 or r > 0xffffffff for r in item["ratios"]):
            raise ValueError(f"Q24 scale ratio overflow at op {idx}")
        if original["execution"] == "cpu_fp32_head":
            item["kind"] = "YOLO_HEAD"
            item["head_weight"] = append(prefix+"weight", arrays[prefix+"weight"].astype("<f4"))
            item["head_bias"] = append(prefix+"bias", arrays[prefix+"bias"].astype("<f4"))
        elif original["name"] == "CONV":
            incoming, outgoing = tensors[item["inputs"][0]], tensors[idx+1]
            ci, co, k = incoming["padded_c"], outgoing["padded_c"], original["k"]
            if co != original["cout"] or ci % 8:
                raise ValueError("Hardware convolution requires complete output tiles")
            weight = np.zeros((co, k, k, ci), dtype=np.int8)
            weight[..., :original["cin"]] = arrays[prefix+"weight"].transpose(0, 2, 3, 1)
            w = append(prefix+"weight", weight)
            q = append(prefix+"quant", np.concatenate(
                [arrays[prefix+"bias"], arrays[prefix+"multiplier"]]).astype("<i4"))
            t = append(prefix+"lut", arrays[prefix+"lut"])
            cfg = dict(a_base=incoming["address"], w_base=w, q_base=q, t_base=t,
                       y_base=outgoing["address"], cin=ci, cout=co,
                       in_w=original["in_w"], in_h=original["in_h"],
                       out_w=original["out_w"], out_h=original["out_h"],
                       k=k, stride=original["stride"], pad=original["pad"], act=2)
            valid_tr = [tr for tr in range(1, min(8, cfg["out_h"])+1)
                        if ((tr-1)*cfg["stride"]+k)*(cfg["in_w"]+2*cfg["pad"])*
                        (ci//8) <= 7168]
            if not valid_tr or k*k*(ci//8) > 576:
                raise ValueError(f"op {idx} exceeds real engine buffer capacity")
            cfg["tr"] = max(valid_tr)
            item["conv"] = cfg
        ops.append(item)
    blob.extend(bytes(align(len(blob), 8)-len(blob)))
    if base < 0 or base+len(blob) > tensor_base or cursor >= 0x10000000:
        raise ValueError("DDR map exceeds conservative 256 MiB aperture")
    result = dict(blob_base=base, blob_length=len(blob), tensor_end=cursor,
                  checkpoint_sha256=graph["checkpoint_sha256"],
                  blob_sha256=hashlib.sha256(blob).hexdigest(),
                  blob_crc32=zlib.crc32(blob),
                  outputs=[r+1 for r in graph["outputs"]], tensors=tensors,
                  ops=ops, regions=regions, board_verified=False)
    output.mkdir(parents=True, exist_ok=True)
    (output / "model.bin").write_bytes(blob)
    (output / "memory_map.json").write_text(json.dumps(result, indent=1), encoding="utf-8")
    lines = ["/* Generated by pack_deployment.py. Do not hand edit. */",
             "#ifndef DEPLOYMENT_MODEL_H", "#define DEPLOYMENT_MODEL_H",
             '#include "yolo_runtime.h"',
             f"#define YOLO_BLOB_BASE 0x{base:08x}u",
             f"#define YOLO_BLOB_LENGTH {len(blob)}u",
             f"#define YOLO_BLOB_CRC32 0x{result['blob_crc32']:08x}u",
             f"#define YOLO_N_TENSORS {len(tensors)}u",
             f"#define YOLO_N_OPS {len(ops)}u",
             "static const yolo_tensor_t yolo_tensors[] = {"]
    for t in tensors:
        lines.append(" {%su,%su,%su,%su,%su,%.10ef}," % (
            t["address"], t["c"], t["padded_c"], t["h"], t["w"], t["scale"]))
    lines.extend(["};", "static const yolo_op_t yolo_ops[] = {"])
    for op in ops:
        fields = [f".kind={op['kind']}", f".count={op['count']}",
                  f".kernel={op['kernel']}", f".stride={op['stride']}",
                  ".inputs={"+",".join(map(str, op["inputs"]))+"}",
                  f".output={op['output']}",
                  ".ratios={"+",".join(str(r)+"u" for r in op["ratios"])+"}"]
        if "conv" in op:
            fields.append(".conv={"+",".join(f".{k}={v}u" for k,v in op["conv"].items())+"}")
        for key in ("head_weight", "head_bias"):
            if key in op:
                fields.append(f".{key}={op[key]}u")
        lines.append(" {"+",".join(fields)+"},")
    lines.extend(["};", "static const uint16_t yolo_outputs[3] = {"+
                  ",".join(map(str, result["outputs"]))+"};", "#endif", ""])
    (output / "deployment_model.h").write_text("\n".join(lines), encoding="ascii")
    print(f"PACK_PASS ops={len(ops)} blob={len(blob)} tensors_end=0x{cursor:x}")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT/"gen/integration/deployment")
    parser.add_argument("--out", type=Path, default=ROOT/"gen/integration/packed")
    args = parser.parse_args()
    pack(args.source, args.out)
