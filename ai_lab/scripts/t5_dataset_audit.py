"""Dataset audit: the four-class mapping, integrity, duplicates and leakage.

Answers, from the actual files rather than from blog posts:
  * how many classes, and which of them land in each of the four bins
  * which images have no label and which labels have no image
  * per-class instance counts (the long tail, especially HazardousWaste)
  * duplicate images, including any that appear in both train and val

Duplicate detection uses size + a hash of the first 64 KiB, which is fast enough
for ~19k files and catches the realistic case (same file copied twice).
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
from collections import Counter, defaultdict

IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def load_yaml(path):
    """Tiny reader for the two structures we need: nc/names and category_mapping."""
    names, mapping = [], {}
    cur_cat = None
    in_names = False
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if re.match(r"^\s*nc\s*:\s*\d+", line):
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
                cur_cat = line[:-1].strip() if line.strip() != "category_mapping:" else None
                continue
            m2 = re.match(r"^\s{2}([A-Za-z]+):\s*$", line)
            if m2:
                cur_cat = m2.group(1)
                mapping[cur_cat] = []
                continue
            m3 = re.match(r"^\s{4}-\s*([A-Za-z0-9_]+)\s*$", line)
            if m3 and cur_cat:
                mapping[cur_cat].append(m3.group(1))
    return names, mapping


def quick_hash(path, limit=65536):
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read(limit))
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="data/garbage_datasets")
    a = ap.parse_args()
    root = a.root
    ds = os.path.join(root, "datasets")

    names, mapping = load_yaml(os.path.join(root, "data.yaml"))
    print(f"classes in data.yaml names: {len(names)}")
    print(f"category_mapping groups: {len(mapping)}")
    for cat, lst in mapping.items():
        print(f"  {cat:<16} {len(lst):>2}  {' '.join(lst)}")

    # class id -> category, using the order in `names`
    idx_of = {n: i for i, n in enumerate(names)}
    cls2cat = {}
    for cat, lst in mapping.items():
        for n in lst:
            if n in idx_of:
                cls2cat[idx_of[n]] = cat
    unmapped = [n for n in names if n not in {x for l in mapping.values() for x in l}]
    if unmapped:
        print(f"!! names not present in category_mapping: {unmapped}")

    for split in ("train", "val"):
        imgdir = os.path.join(ds, "images", split)
        lbldir = os.path.join(ds, "labels", split)
        imgs = {os.path.splitext(f)[0]: os.path.join(imgdir, f)
                for f in os.listdir(imgdir) if os.path.splitext(f)[1].lower() in IMG_EXT}
        lbls = {os.path.splitext(f)[0]: os.path.join(lbldir, f)
                for f in os.listdir(lbldir) if f.endswith(".txt")}
        only_img = sorted(set(imgs) - set(lbls))
        only_lbl = sorted(set(lbls) - set(imgs))

        per_cls = Counter()
        per_cat = Counter()
        empty = 0
        bad_ids = 0
        for stem, lp in lbls.items():
            n_box = 0
            with open(lp, encoding="utf-8", errors="ignore") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) < 5:
                        continue
                    try:
                        cid = int(float(parts[0]))
                    except ValueError:
                        continue
                    if cid < 0 or cid >= len(names):
                        bad_ids += 1
                        continue
                    per_cls[cid] += 1
                    per_cat[cls2cat.get(cid, "UNMAPPED")] += 1
                    n_box += 1
            if n_box == 0:
                empty += 1

        print(f"\n[{split}] images={len(imgs)} labels={len(lbls)} "
              f"images_without_label={len(only_img)} labels_without_image={len(only_lbl)} "
              f"empty_labels={empty} bad_class_ids={bad_ids}")
        if only_img[:5]:
            print(f"  e.g. image without label: {only_img[:5]}")
        if only_lbl[:5]:
            print(f"  e.g. label without image: {only_lbl[:5]}")

        print(f"  per-category boxes: " +
              ", ".join(f"{k}={v}" for k, v in sorted(per_cat.items())))

        if split == "train":
            print("  per-class boxes (train), sorted ascending -- the long tail:")
            for cid, n in per_cls.most_common()[::-1][:12]:
                print(f"    {names[cid]:<18} id={cid:<3} {n}")
            globals()["_train_cls"] = per_cls

    # duplicates / leakage
    seen = defaultdict(list)
    for split in ("train", "val"):
        imgdir = os.path.join(ds, "images", split)
        for f in os.listdir(imgdir):
            if os.path.splitext(f)[1].lower() not in IMG_EXT:
                continue
            p = os.path.join(imgdir, f)
            key = (os.path.getsize(p), quick_hash(p))
            seen[key].append((split, f))
    dup_pairs = {k: v for k, v in seen.items() if len(v) > 1}
    cross = {k: v for k, v in dup_pairs.items()
             if len({s for s, _ in v}) > 1}
    print(f"\nduplicate groups: {len(dup_pairs)}   train/val leakage groups: {len(cross)}")
    for k, v in list(cross.items())[:3]:
        print(f"  leaked: {v}")


if __name__ == "__main__":
    main()
