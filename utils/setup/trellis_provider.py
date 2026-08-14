#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
RUNNER = PROJECT_ROOT / "addons" / "build_me_godot" / "integrations" / "reconstruction" / "trellis" / "trellis_image_to_glb.py"


def trellis_root() -> Path | None:
    value = os.environ.get("BUILD_ME_GODOT_TRELLIS_ROOT") or os.environ.get("TRELLIS_ROOT", "")
    return Path(value).expanduser() if value else None


def trellis_model() -> Path | None:
    value = os.environ.get("BUILD_ME_GODOT_TRELLIS_MODEL_PATH", "")
    return Path(value).expanduser() if value else None


def validate() -> list[str]:
    errors: list[str] = []
    root = trellis_root()
    model = trellis_model()
    if root is None:
        errors.append("BUILD_ME_GODOT_TRELLIS_ROOT or TRELLIS_ROOT is not set")
    elif not (root / "trellis" / "pipelines").is_dir():
        errors.append(f"TRELLIS checkout does not look valid: {root}")
    if model is None:
        errors.append("BUILD_ME_GODOT_TRELLIS_MODEL_PATH is not set")
    elif not model.exists():
        errors.append(f"TRELLIS model path does not exist: {model}")
    if not RUNNER.is_file():
        errors.append(f"Build Me Godot TRELLIS runner is missing: {RUNNER}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Run user-managed TRELLIS through the Build Me Godot provider contract")
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--metadata-output", type=Path)
    args = parser.parse_args()

    errors = validate()
    if args.version:
        print("build-me-godot-trellis-provider 1")
        if errors:
            print("not configured: " + "; ".join(errors), file=sys.stderr)
            return 1
        return 0

    if args.input is None or args.output is None or args.metadata_output is None:
        parser.error("--input, --output, and --metadata-output are required")
    if errors:
        args.metadata_output.parent.mkdir(parents=True, exist_ok=True)
        args.metadata_output.write_text(json.dumps({
            "schema_version": 1,
            "provider": "trellis",
            "ok": False,
            "errors": errors,
            "automatic_downloads_allowed": False,
        }, indent=2) + "\n", encoding="utf-8")
        return 1

    python = os.environ.get("BUILD_ME_GODOT_TRELLIS_PYTHON", sys.executable)
    command = [
        python,
        str(RUNNER),
        "--trellis-root",
        str(trellis_root()),
        "--model",
        str(trellis_model()),
        "--input",
        str(args.input.resolve()),
        "--output",
        str(args.output.resolve()),
        "--metadata-output",
        str(args.metadata_output.resolve()),
    ]
    env = os.environ.copy()
    env.setdefault("HF_HUB_OFFLINE", "1")
    result = subprocess.run(command, check=False, env=env)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
