"""Build a clean 4-class training set from the 40-class source.

What it fixes, each of which was measured in the audit (logs/t5_dataset_audit.log):
  * 89 train/val leaks: a val image whose content hash also appears in train is
    dropped from val, otherwise validation accuracy is inflated.
  * 16,877 orphan label files in val (and 2,188 in train) that have no image.
    Only images that actually exist are emitted.
  * 40 class ids collapse to the four bins given by category_mapping.

Images are not copied (1.4 GB); the manifest lists their original absolute
paths, and the remapped labels live in data/g4/labels/{train,val}. A custom
loader reads the manifest, so the standard ultralytics layout is not needed.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from collections import Counter, defaultdict

IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
CAT_ORDER = ["Recyclables", "KitchenWaste", "HazardousWaste", "OtherGarbage"]
CAT_NAME = {
    "Recyclables": "recyclable",
    "KitchenWaste": "kitchen",
    "HazardousWaste": "hazardous",
    "OtherGarbage": "other",
}


def load_yaml(path):
    names, mapping, cur = [], {}, None
    in_names = False
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if re.match(r"^\s*nc\s*:", line):
            continue
        if re.match(r"^\s*names\s*:\s*$", line):
            in_names = True
            continue
        m = re.match(r"^\s*-\s*([A-Za-z0-9_]+)\s*$", line)
        if in_names and m:
            names.append(m.group(1))
            continue
        if line and not line.startswith(" ") and line.endswith(":"):
            in_names = False
            continue
        m2 = re.match(r"^\s{2}([A-Za-z]+):\s*$", line)
        if m2:
            cur = m2.group(1)
            mapping[cur] = []
            continue
        m3 = re.match(r"^\s{4}-\s*([A-Za-z0-9_]+)\s*$", line)
        if m3 and cur:
            mapping[cur].append(m3.group(1))
    return names, mapping


def qhash(path, limit=65536):
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read(limit))
    return h.hexdigest()


def main():
    root = "data/garbage_datasets"
    out = "data/g4"
    os.makedirs(f"{out}/labels/train", exist_ok=True)
    os.makedirs(f"{out}/labels/val", exist_ok=True)

    names, mapping = load_yaml(f"{root}/data.yaml")
    idx_of = {n: i for i, n in enumerate(names)}
    cls2four = {}
    for four, lst in mapping.items():
        for n in lst:
            cls2four[idx_of[n]] = CAT_ORDER.index(four)

    # ---- hashes, to find leaks ----
    def scan(split):
        imgdir = f"{root}/datasets/images/{split}"
        res = {}
        for f in os.listdir(imgdir):
            if os.path.splitext(f)[1].lower() not in IMG_EXT:
                continue
            p = os.path.join(imgdir, f)
            res[os.path.splitext(f)[0]] = (p, qhash(p), os.path.getsize(p))
        return res

    tr = scan("train")
    va = scan("val")
    tr_hashes = {v[1] for v in tr.values()}
    leak_stems = {k for k, v in va.items() if v[1] in tr_hashes}

    def emit(split, table, drop):
        stem2four = {}
        box_cnt = Counter()
        kept = 0
        dropped_leak = 0
        for stem, (img, _h, _s) in table.items():
            if stem in drop:
                dropped_leak += 1
                continue
            lp = f"{root}/datasets/labels/{split}/{stem}.txt"
            if not os.path.exists(lp):
                continue
            lines = []
            for line in open(lp, encoding="utf-8", errors="ignore"):
                p = line.split()
                if len(p) < 5:
                    continue
                try:
                    cid = int(float(p[0]))
                    vals = [float(x) for x in p[1:5]]
                except ValueError:
                    continue
                if cid < 0 or cid >= len(names):
                    continue
                four = cls2four.get(cid)
                if four is None:
                    continue
                lines.append(f"{four} " + " ".join(f"{v:.6f}" for v in vals))
                box_cnt[four] += 1
            if not lines:
                continue
            with open(f"{out}/labels/{split}/{stem}.txt", "w") as f:
                f.write("\n".join(lines) + "\n")
            stem2four[stem] = {"img": img, "labels": f"{out}/labels/{split}/{stem}.txt"}
            kept += 1
        with open(f"{out}/{split}.json", "w") as f:
            json.dump(stem2four, f)
        return kept, dropped_leak, box_cnt

    k_tr, d_tr, c_tr = emit("train", tr, set())
    k_va, d_va, c_va = emit("val", va, leak_stems)

    print(f"classes 40 -> 4   order={CAT_ORDER}")
    print(f"train: kept {k_tr} images (dropped {d_tr}), boxes {dict(sorted(c_tr.items()))}")
    print(f"val  : kept {k_va} images (dropped {d_va} leaked), boxes {dict(sorted(c_va.items()))}")

    with open(f"{out}/names.txt", "w") as f:
        f.write("\n".join(CAT_NAME[c] for c in CAT_ORDER) + "\n")
    total = sum(c_tr.values())
    print("train share per class: " +
          ", ".join(f"{CAT_NAME[CAT_ORDER[i]]}={c_tr.get(i,0)/total:.1%}" for i in range(4)))


if __name__ == "__main__":
    main()
