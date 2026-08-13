#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def command_version(command: list[str]) -> str:
    try:
        result = subprocess.run(command, check=False, text=True, capture_output=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return str(exc)
    output = (result.stdout or result.stderr).strip().splitlines()
    return output[0] if output else f"exit {result.returncode}"


def main() -> int:
    report = {
        "schema_version": 1,
        "mode": "doctor",
        "python": sys.version.split()[0],
        "executables": {
            "python3": shutil.which("python3") or "",
            "comfyui_python": os.environ.get("COMFYUI_PYTHON", ""),
            "triposr_python": os.environ.get("TRIPOSR_PYTHON", ""),
            "blender": shutil.which("blender") or "",
            "git": shutil.which("git") or "",
        },
        "versions": {
            "blender": command_version(["blender", "--version"]) if shutil.which("blender") else "missing",
        },
        "paths": {
            "project_root": os.environ.get("BUILD_ME_GODOT_PROJECT_ROOT", ""),
            "comfyui_root": os.environ.get("COMFYUI_ROOT", ""),
            "triposr_root": os.environ.get("TRIPOSR_ROOT", ""),
        },
        "path_exists": {},
        "torch": {},
    }
    for key, value in report["paths"].items():
        report["path_exists"][key] = bool(value and Path(value).exists())
    try:
        import torch

        report["torch"] = {
            "version": torch.__version__,
            "cuda_available": bool(torch.cuda.is_available()),
            "device": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "",
        }
    except Exception as exc:
        report["torch"] = {"error": str(exc)}
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
