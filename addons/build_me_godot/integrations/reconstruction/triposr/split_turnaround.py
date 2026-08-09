#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


PANEL_ORDER = (("front", "front_3q", "right"), ("back", "back_3q", "left"))


def foreground_bbox(image):
    pixels = np.asarray(image.convert("RGB"), dtype=np.int16)
    border = np.concatenate((pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]))
    background = np.median(border, axis=0)
    mask = np.max(np.abs(pixels - background), axis=2) > 22
    ys, xs = np.nonzero(mask)
    if len(xs) < 100:
        return 0, 0, image.width, image.height
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def normalize_panel(image, output_size, target_height_ratio=0.90, sole_ratio=0.965):
    width, height = output_size
    bbox = foreground_bbox(image)
    subject = image.crop(bbox)
    scale = min(round(height * target_height_ratio) / subject.height, width * 0.92 / subject.width)
    resized = subject.resize((round(subject.width * scale), round(subject.height * scale)), Image.Resampling.LANCZOS)
    pixels = np.asarray(image.convert("RGB"))
    background = tuple(np.median(np.concatenate((pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1])), axis=0).astype(np.uint8))
    canvas = Image.new("RGB", output_size, background)
    x = (width - resized.width) // 2
    y = max(0, min(round(height * sole_ratio) - resized.height, height - resized.height))
    canvas.paste(resized, (x, y))
    return canvas, {"source_bbox": bbox, "paste": [x, y, resized.width, resized.height]}


def main():
    parser = argparse.ArgumentParser(description="Split and normalize a six-panel character turnaround")
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    sheet = Image.open(args.source).convert("RGB")
    if sheet.width % 3 or sheet.height % 2:
        raise ValueError(f"Expected an exact 3x2 sheet, got {sheet.width}x{sheet.height}")
    panel_size = sheet.width // 3, sheet.height // 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    metadata = {"schema_version": 1, "source": str(args.source.resolve()), "sheet_size": sheet.size, "panel_size": panel_size, "views": {}}
    views = {}
    for row, names in enumerate(PANEL_ORDER):
        for column, name in enumerate(names):
            box = column * panel_size[0], row * panel_size[1], (column + 1) * panel_size[0], (row + 1) * panel_size[1]
            normalized, details = normalize_panel(sheet.crop(box), panel_size)
            normalized.save(args.output_dir / f"{name}.png")
            metadata["views"][name] = {"panel": [column, row], "crop": box, **details}
            views[name] = normalized
    multiview = Image.new("RGB", (panel_size[0] * 4, panel_size[1]))
    for index, name in enumerate(("front", "right", "back", "left")):
        multiview.paste(views[name], (index * panel_size[0], 0))
    multiview.save(args.output_dir / "multiview_4.png")
    (args.output_dir / "views.json").write_text(json.dumps(metadata, indent=2) + "\n")


if __name__ == "__main__":
    main()
