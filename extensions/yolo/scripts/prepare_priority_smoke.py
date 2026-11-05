"""Prepare a small two-class bring-up set; never an accuracy certificate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
CLASSES = ("biodegradable", "cardboard")


def select_records(records, per_class=5):
    if per_class < 1:
        raise ValueError("per_class must be positive")
    chosen = []
    for category in CLASSES:
        # Selection uses annotations and filename only, never predicted success.
        candidates = sorted(
            (r for r in records if r["gt"]
             and {g["class"] for g in r["gt"]} == {category}),
            key=lambda r: r["image"],
        )
        if len(candidates) < per_class:
            raise ValueError(f"Not enough annotated images for {category}")
        chosen.extend(candidates[:per_class])
    return chosen


def prepare(predictions, images, out, per_class=5):
    records = json.loads(predictions.read_text(encoding="utf-8"))
    selected = select_records(records, per_class)
    paths = [images / Path(r["image"]).name for r in selected]
    if any(not p.is_file() for p in paths):
        raise FileNotFoundError("A selected source image is missing")
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise FileExistsError(f"Refusing to overwrite {out}")
    entries = []
    for record, source in zip(selected, paths):
        shutil.copy2(source, out / source.name)
        entries.append(dict(image=source.name, ground_truth=record["gt"],
                            cached_predictions=record["dets"],
                            sha256=hashlib.sha256(source.read_bytes()).hexdigest()))
    manifest = dict(
        purpose="Two-class bring-up smoke only, not accuracy acceptance",
        board_verified=False, classes=list(CLASSES),
        selection="Ground truth and filename only; predictions not used to select",
        predictions_source=str(predictions.resolve()), images=entries,
    )
    (out / "smoke_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (out / "run.ps1").write_text(
        """param(
    [Parameter(Mandatory=$true)][string]$Package,
    [Parameter(Mandatory=$true)][string]$Port,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$Package = (Resolve-Path -LiteralPath $Package).Path
$Manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'smoke_manifest.json') -Raw | ConvertFrom-Json
# Load and CRC-check the model once before the per-image commands.
& $Python (Join-Path $Package 'board_loader.py') --package-dir $Package --port $Port
if ($LASTEXITCODE -ne 0) { throw 'Model load/CRC failed' }
foreach ($Entry in $Manifest.images) {
    Write-Host ('Testing ' + $Entry.image)
    & $Python (Join-Path $Package 'board_loader.py') --package-dir $Package --port $Port --skip-model --image (Join-Path $PSScriptRoot $Entry.image)
    if ($LASTEXITCODE -ne 0) { throw ('Board command failed: ' + $Entry.image) }
}
Write-Host 'Commands finished. Compare boxes and classes with smoke_manifest.json; this is not an accuracy PASS.'
""", encoding="ascii")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions", type=Path, default=ROOT /
                        "results/yolov5n_deployment_q15_conf005/predictions.json")
    parser.add_argument("--images", type=Path, default=ROOT /
                        "data/garbage_datasets/datasets/images/val")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--per-class", type=int, default=5)
    args = parser.parse_args()
    manifest = prepare(args.predictions, args.images, args.out, args.per_class)
    print(f"PRIORITY_SMOKE_READY images={len(manifest['images'])} "
          f"board_verified=false out={args.out}")


if __name__ == "__main__":
    main()
