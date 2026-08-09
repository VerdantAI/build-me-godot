#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Run a local TripoSR checkout on one or more character views")
    parser.add_argument("sources", nargs="*", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--model", default="stabilityai/TripoSR")
    parser.add_argument("--mc-resolution", type=int, default=256)
    parser.add_argument("--chunk-size", type=int, default=4096)
    parser.add_argument("--texture-resolution", type=int, default=2048)
    parser.add_argument("--bake-texture", action="store_true")
    args = parser.parse_args()

    if args.version:
        print("build-me-godot-triposr-adapter 1")
        return
    if not args.sources or args.output_dir is None or args.repo is None:
        parser.error("sources, --output-dir, and --repo are required for generation")

    repo = args.repo.resolve()
    runner = repo / "run.py"
    if not runner.is_file():
        raise SystemExit(f"TripoSR run.py not found in {repo}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index in range(len(args.sources)):
        (args.output_dir / str(index)).mkdir(exist_ok=True)
    command = [
        sys.executable, str(runner), *(str(path.resolve()) for path in args.sources),
        "--output-dir", str(args.output_dir.resolve()),
        "--pretrained-model-name-or-path", args.model,
        "--model-save-format", "glb", "--mc-resolution", str(args.mc_resolution),
        "--chunk-size", str(args.chunk_size), "--no-remove-bg",
    ]
    if args.bake_texture:
        command.extend(("--bake-texture", "--texture-resolution", str(args.texture_resolution)))
    started = time.monotonic()
    subprocess.run(command, cwd=repo, check=True)
    report = {
        "schema_version": 1,
        "provider": "triposr",
        "sources": [str(path.resolve()) for path in args.sources],
        "repository": str(repo),
        "model": args.model,
        "seconds": time.monotonic() - started,
        "mc_resolution": args.mc_resolution,
        "chunk_size": args.chunk_size,
        "bake_texture": args.bake_texture,
    }
    try:
        import torch
        report["device"] = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu"
        report["peak_vram_bytes"] = torch.cuda.max_memory_allocated() if torch.cuda.is_available() else 0
    except ImportError:
        pass
    (args.output_dir / "generation.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
