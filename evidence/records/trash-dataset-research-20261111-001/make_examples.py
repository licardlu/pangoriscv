"""Render real validation images with selected COCO ground-truth boxes."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "evidence/records/validation_20261104/dataset/valid"
OUTPUT = ROOT / "docs/verification/assets/trash-dataset-examples.png"
labels = {
    "biodegradable": "可生物降解 → 绿色桶（现有映射）",
    "cardboard": "纸板 → 合并后：纸张 / 蓝色桶",
    "glass": "玻璃 → 蓝色桶",
    "metal": "金属 → 蓝色桶",
    "paper": "纸张 → 合并后：纸张 / 蓝色桶",
    "plastic": "塑料 → 蓝色桶",
}
font_path = "C:/Windows/Fonts/msyh.ttc"
title_font = ImageFont.truetype(font_path, 32)
body_font = ImageFont.truetype(font_path, 20)
small_font = ImageFont.truetype(font_path, 16)
coco = json.loads((DATA / "_annotations.coco.json").read_text(encoding="utf8"))
images = {item["id"]: item for item in coco["images"]}
canvas = Image.new("RGB", (1356, 1000), "#edf2f5")
draw = ImageDraw.Draw(canvas)
draw.text((28, 18), "现有数据集样例：原六类中的纸板、纸张将合并", font=title_font, fill="#152d3b")
draw.text((28, 65), "来源：本地 valid 集；绿色框为人工标注（GT），不是模型预测。每图仅突出一个对应类别的框。",
          font=body_font, fill="#40525d")
selected = []
for index, (name, caption) in enumerate(labels.items()):
    ids = {item["id"] for item in coco["categories"] if item["name"] == name}
    candidates = []
    for ann in coco["annotations"]:
        if ann["category_id"] not in ids:
            continue
        info = images[ann["image_id"]]
        x, y, w, h = ann["bbox"]
        fraction = w * h / (info["width"] * info["height"])
        if .10 <= fraction <= .80 and (DATA / info["file_name"]).is_file():
            candidates.append((abs(fraction - .45), info["file_name"], ann, info))
    _, _, ann, info = min(candidates, key=lambda row: (row[0], row[1]))
    image = Image.open(DATA / info["file_name"]).convert("RGB")
    x, y, w, h = ann["bbox"]
    ImageDraw.Draw(image).rectangle((x, y, x + w, y + h), outline="#12e36b", width=4)
    image.thumbnail((410, 332), Image.Resampling.LANCZOS)
    left, top = 20 + (index % 3) * 446, 112 + (index // 3) * 422
    draw.rounded_rectangle((left, top, left + 428, top + 404), radius=12, fill="white")
    canvas.paste(image, (left + (428 - image.width) // 2, top + 10 + (332 - image.height) // 2))
    draw.text((left + 12, top + 350), caption, font=body_font, fill="#173848")
    draw.text((left + 12, top + 378), f"GT: {name} | image ID {info['id']}", font=small_font, fill="#566775")
    selected.append(dict(category=name, image=info, annotation=ann))
draw.text((28, 967), "展示数据内容与标签，不代表当前识别准确率；桶分类仍需依据具体物品及当地规则。",
          font=small_font, fill="#40525d")
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUTPUT)
Path(__file__).with_name("selected_examples.json").write_text(
    json.dumps(selected, ensure_ascii=False, indent=2), encoding="utf8")
print(OUTPUT)
