#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def isolate(image):
    pixels = np.asarray(image.convert("RGB"), dtype=np.float32)
    border = np.concatenate((pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]))
    background = np.median(border, axis=0)
    distance = np.linalg.norm(pixels - background, axis=2)
    mask = distance > 72
    floor_start = round(image.height * 0.84)
    mask[floor_start:] &= (distance[floor_start:] > 105) & (pixels[floor_start:].mean(axis=2) < 145)
    mask = ndimage.binary_dilation(mask, iterations=2)
    labels, count = ndimage.label(mask)
    if count:
        label = labels[image.height // 2, image.width // 2]
        if label == 0:
            label = int(np.argmax(ndimage.sum(mask, labels, range(1, count + 1)))) + 1
        mask = labels == label
    mask = ndimage.binary_fill_holes(mask)
    mask = ndimage.binary_closing(mask, iterations=5)
    alpha = ndimage.gaussian_filter(mask.astype(np.float32), sigma=1.2)[..., None]
    composited = pixels * alpha + np.full_like(pixels, 127.5) * (1.0 - alpha)
    return Image.fromarray(np.clip(composited, 0, 255).astype(np.uint8)), Image.fromarray((alpha[..., 0] * 255).astype(np.uint8))


def main():
    parser = argparse.ArgumentParser(description="Remove a neutral turnaround background without model weights")
    parser.add_argument("sources", nargs="+", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for source in args.sources:
        image, mask = isolate(Image.open(source))
        image.save(args.output_dir / f"{source.stem}_tripo.png")
        mask.save(args.output_dir / f"{source.stem}_mask.png")


if __name__ == "__main__":
    main()
