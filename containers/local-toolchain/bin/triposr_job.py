#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run TripoSR through the Build Me Godot provider contract")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--metadata-output", required=True, type=Path)
    parser.add_argument("--model", default=os.environ.get("TRIPOSR_MODEL", "/models/triposr"))
    parser.add_argument("--mc-resolution", type=int, default=int(os.environ.get("TRIPOSR_MC_RESOLUTION", "256")))
    parser.add_argument("--chunk-size", type=int, default=int(os.environ.get("TRIPOSR_CHUNK_SIZE", "4096")))
    parser.add_argument("--bake-texture", action="store_true")
    args = parser.parse_args()

    triposr_root = Path(os.environ.get("TRIPOSR_ROOT", "/opt/TripoSR"))
    runner = triposr_root / "run.py"
    if not runner.is_file():
        raise SystemExit(f"TripoSR runner not found: {runner}")
    if not args.input.is_file():
        raise SystemExit(f"Input image not found: {args.input}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.metadata_output.parent.mkdir(parents=True, exist_ok=True)

    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="build-me-godot-triposr-") as temp:
        temp_dir = Path(temp)
        # TripoSR's CLI exports single-image runs beneath output_dir/0 but does
        # not always create that directory before handing the path to trimesh.
        (temp_dir / "0").mkdir(parents=True, exist_ok=True)
        command = [
            sys.executable,
            str(runner),
            str(args.input),
            "--output-dir",
            str(temp_dir),
            "--pretrained-model-name-or-path",
            args.model,
            "--model-save-format",
            args.output.suffix.lstrip(".") or "glb",
            "--mc-resolution",
            str(args.mc_resolution),
            "--chunk-size",
            str(args.chunk_size),
            "--no-remove-bg",
        ]
        if args.bake_texture:
            command.append("--bake-texture")
        result = subprocess.run(command, cwd=triposr_root, check=False, text=True, capture_output=True)
        meshes = sorted(temp_dir.rglob(f"*{args.output.suffix or '.glb'}"))
        if result.returncode != 0 or not meshes:
            report = {
                "schema_version": 1,
                "provider": "container_triposr",
                "ok": False,
                "exit_code": result.returncode,
                "stdout_tail": result.stdout[-4000:],
                "stderr_tail": result.stderr[-4000:],
                "seconds": time.monotonic() - started,
            }
            args.metadata_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
            return result.returncode or 1
        shutil.copy2(meshes[0], args.output)

    report = {
        "schema_version": 1,
        "provider": "container_triposr",
        "ok": True,
        "input": str(args.input),
        "output": str(args.output),
        "model": args.model,
        "mc_resolution": args.mc_resolution,
        "chunk_size": args.chunk_size,
        "bake_texture": args.bake_texture,
        "seconds": time.monotonic() - started,
    }
    args.metadata_output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
