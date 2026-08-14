#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser(description="Run microsoft/TRELLIS image-to-GLB generation")
    parser.add_argument("--trellis-root", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata-output", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=int(os.environ.get("BUILD_ME_GODOT_TRELLIS_SEED", "1")))
    parser.add_argument("--sparse-steps", type=int, default=int(os.environ.get("BUILD_ME_GODOT_TRELLIS_SPARSE_STEPS", "12")))
    parser.add_argument("--sparse-cfg", type=float, default=float(os.environ.get("BUILD_ME_GODOT_TRELLIS_SPARSE_CFG", "7.5")))
    parser.add_argument("--slat-steps", type=int, default=int(os.environ.get("BUILD_ME_GODOT_TRELLIS_SLAT_STEPS", "12")))
    parser.add_argument("--slat-cfg", type=float, default=float(os.environ.get("BUILD_ME_GODOT_TRELLIS_SLAT_CFG", "3.0")))
    parser.add_argument("--texture-size", type=int, default=int(os.environ.get("BUILD_ME_GODOT_TRELLIS_TEXTURE_SIZE", "1024")))
    parser.add_argument("--simplify", type=float, default=float(os.environ.get("BUILD_ME_GODOT_TRELLIS_SIMPLIFY", "0.95")))
    args = parser.parse_args()

    started = time.monotonic()
    args.metadata_output.parent.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    try:
        sys.path.insert(0, str(args.trellis_root))
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
        os.environ.setdefault("SPCONV_ALGO", "native")

        from trellis.pipelines import TrellisImageTo3DPipeline
        from trellis.utils import postprocessing_utils

        pipeline = TrellisImageTo3DPipeline.from_pretrained(str(args.model))
        pipeline.cuda()
        image = Image.open(args.input).convert("RGBA")
        outputs = pipeline.run(
            image,
            seed=args.seed,
            sparse_structure_sampler_params={
                "steps": args.sparse_steps,
                "cfg_strength": args.sparse_cfg,
            },
            slat_sampler_params={
                "steps": args.slat_steps,
                "cfg_strength": args.slat_cfg,
            },
        )
        glb = postprocessing_utils.to_glb(
            outputs["gaussian"][0],
            outputs["mesh"][0],
            simplify=args.simplify,
            texture_size=args.texture_size,
        )
        glb.export(str(args.output))
        report = {
            "schema_version": 1,
            "provider": "trellis",
            "ok": True,
            "input": str(args.input),
            "output": str(args.output),
            "trellis_root": str(args.trellis_root),
            "model": str(args.model),
            "seed": args.seed,
            "sparse_steps": args.sparse_steps,
            "slat_steps": args.slat_steps,
            "texture_size": args.texture_size,
            "simplify": args.simplify,
            "hf_hub_offline": os.environ.get("HF_HUB_OFFLINE", ""),
            "seconds": time.monotonic() - started,
        }
        args.metadata_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return 0
    except Exception as exc:
        report = {
            "schema_version": 1,
            "provider": "trellis",
            "ok": False,
            "error": str(exc),
            "input": str(args.input),
            "output": str(args.output),
            "trellis_root": str(args.trellis_root),
            "model": str(args.model),
            "hf_hub_offline": os.environ.get("HF_HUB_OFFLINE", ""),
            "seconds": time.monotonic() - started,
        }
        args.metadata_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
