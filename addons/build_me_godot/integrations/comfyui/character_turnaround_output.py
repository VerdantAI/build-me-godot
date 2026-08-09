# SPDX-License-Identifier: MIT

import json
import os
import re

import numpy as np
from PIL import Image, PngImagePlugin
import torch
import torch.nn.functional as F

import folder_paths


def _safe_name(value):
    value = re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip()).strip("._")
    return value or "character"


def _resize_cover(image, width, height):
    image = image.movedim(-1, 1)
    scale = max(width / image.shape[3], height / image.shape[2])
    scaled_width = round(image.shape[3] * scale)
    scaled_height = round(image.shape[2] * scale)
    image = F.interpolate(image, size=(scaled_height, scaled_width), mode="bicubic", align_corners=False)
    left = (scaled_width - width) // 2
    top = (scaled_height - height) // 2
    return image[:, :, top:top + height, left:left + width].movedim(1, -1).clamp(0.0, 1.0)


class TurnaroundLoadImage:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "character_name": ("STRING", {"default": "field_engineer"}),
            "view_name": (["canonical", "front"],),
        }}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "load"
    CATEGORY = "character turnaround"

    def load(self, character_name, view_name):
        output_dir = os.path.realpath(folder_paths.get_output_directory())
        image_path = os.path.realpath(os.path.join(output_dir, "character_turnaround", _safe_name(character_name), f"{view_name}.png"))
        if os.path.commonpath((output_dir, image_path)) != output_dir or not os.path.isfile(image_path):
            raise FileNotFoundError(f"Turnaround source image not found: {image_path}")
        pixels = np.asarray(Image.open(image_path).convert("RGB"), dtype=np.float32) / 255.0
        return (torch.from_numpy(pixels).unsqueeze(0),)


class TurnaroundNormalize:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "image": ("IMAGE",),
            "width": ("INT", {"default": 768, "min": 256, "max": 4096, "step": 16}),
            "height": ("INT", {"default": 1024, "min": 256, "max": 4096, "step": 16}),
        }}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "normalize"
    CATEGORY = "character turnaround"

    def normalize(self, image, width, height):
        return (_resize_cover(image, width, height),)


class TurnaroundContactSheet:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "front": ("IMAGE",),
                "right": ("IMAGE",),
                "back": ("IMAGE",),
                "left": ("IMAGE",),
            },
            "optional": {
                "front_3q": ("IMAGE",),
                "back_3q": ("IMAGE",),
            },
        }

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "compose"
    CATEGORY = "character turnaround"

    def compose(self, front, right, back, left, front_3q=None, back_3q=None):
        front = front[:1]
        right = _resize_cover(right[:1], front.shape[2], front.shape[1])
        back = _resize_cover(back[:1], front.shape[2], front.shape[1])
        left = _resize_cover(left[:1], front.shape[2], front.shape[1])
        if front_3q is None or back_3q is None:
            return (torch.cat((front, right, back, left), dim=2),)
        front_3q = _resize_cover(front_3q[:1], front.shape[2], front.shape[1])
        back_3q = _resize_cover(back_3q[:1], front.shape[2], front.shape[1])
        top = torch.cat((front, front_3q, right), dim=2)
        bottom = torch.cat((back, back_3q, left), dim=2)
        return (torch.cat((top, bottom), dim=1),)


class TurnaroundSaveImage:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),
                "character_name": ("STRING", {"default": "field_engineer"}),
                "view_name": (["canonical", "front", "front_3q", "right", "back", "back_3q", "left", "turnaround_sheet"],),
            },
            "hidden": {"prompt": "PROMPT", "extra_pnginfo": "EXTRA_PNGINFO"},
        }

    RETURN_TYPES = ()
    FUNCTION = "save"
    OUTPUT_NODE = True
    CATEGORY = "character turnaround"

    def save(self, image, character_name, view_name, prompt=None, extra_pnginfo=None):
        relative_dir = os.path.join("character_turnaround", _safe_name(character_name))
        output_dir = os.path.join(folder_paths.get_output_directory(), relative_dir)
        os.makedirs(output_dir, exist_ok=True)
        filename = f"{_safe_name(view_name)}.png"
        output_path = os.path.join(output_dir, filename)

        pixels = (image[0].detach().cpu().numpy() * 255.0).clip(0, 255).astype(np.uint8)
        pnginfo = PngImagePlugin.PngInfo()
        if prompt is not None:
            pnginfo.add_text("prompt", json.dumps(prompt))
        if extra_pnginfo is not None:
            for key, value in extra_pnginfo.items():
                pnginfo.add_text(key, json.dumps(value))
        Image.fromarray(pixels).save(output_path, pnginfo=pnginfo, compress_level=4)
        return {"ui": {"images": [{"filename": filename, "subfolder": relative_dir, "type": "output"}]}}


NODE_CLASS_MAPPINGS = {
    "TurnaroundLoadImage": TurnaroundLoadImage,
    "TurnaroundNormalize": TurnaroundNormalize,
    "TurnaroundContactSheet": TurnaroundContactSheet,
    "TurnaroundSaveImage": TurnaroundSaveImage,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "TurnaroundLoadImage": "Load Saved Turnaround Image",
    "TurnaroundNormalize": "Normalize Turnaround View",
    "TurnaroundContactSheet": "Build Turnaround Contact Sheet",
    "TurnaroundSaveImage": "Save Named Turnaround Image",
}
