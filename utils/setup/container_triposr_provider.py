#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONTAINER_CONFIG = PROJECT_ROOT / "utils" / "check-local-container.local.env"


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        try:
            parts = shlex.split(value, comments=False, posix=True)
        except ValueError:
            parts = [value.strip()]
        values[key.strip()] = parts[0] if parts else ""
    return values


def build_run_command(config: dict[str, str], mode: str, extra: list[str]) -> list[str]:
    runtime = config.get("BUILD_ME_GODOT_CONTAINER_RUNTIME", "podman")
    image = config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev")
    runtime_path = shutil.which(runtime)
    if not runtime_path:
        raise SystemExit(f"Container runtime not found: {runtime}")
    command = [runtime_path, "run", "--rm"]
    command.extend(shlex.split(config.get("BUILD_ME_GODOT_CONTAINER_GPU_ARGS", "")))
    project_root = Path(config.get("BUILD_ME_GODOT_CONTAINER_PROJECT_ROOT", PROJECT_ROOT)).expanduser()
    if project_root.exists():
        command.extend(["-v", f"{project_root}:{project_root}:rw"])
        command.extend(["-e", f"BUILD_ME_GODOT_PROJECT_ROOT={project_root}"])
        command.extend(["-w", str(project_root)])
    for source, target in container_mounts(config):
        command.extend(["-v", f"{source}:{target}:rw"])
    command.extend([image, mode, *extra])
    return command


def container_mounts(config: dict[str, str]) -> list[tuple[Path, str]]:
    mounts: list[tuple[Path, str]] = []
    seen: set[str] = set()
    for root_text in shlex.split(config.get("BUILD_ME_GODOT_CONTAINER_MODEL_ROOTS", "")):
        source = Path(root_text).expanduser()
        if not source.exists():
            continue
        target = str(source)
        source_parts = source.parts
        if source.name == "models" and "ComfyUI" in source_parts:
            target = "/opt/ComfyUI/models"
        elif source.name == "custom_nodes" and "ComfyUI" in source_parts:
            target = "/opt/ComfyUI/custom_nodes"
        elif source.name == "output" and "ComfyUI" in source_parts:
            target = "/opt/ComfyUI/output"
        elif source.name == "triposr":
            target = "/models/triposr"
        elif source.name == "comfyui_nodes":
            target = "/models/comfyui_nodes"
        elif source.name == "models" and ".ollama" in source_parts:
            target = "/models/ollama"
        key = f"{source}:{target}"
        if key not in seen:
            seen.add(key)
            mounts.append((source, target))
    return mounts


def main() -> int:
    parser = argparse.ArgumentParser(description="Run containerized TripoSR through the Build Me Godot provider contract")
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--metadata-output", type=Path)
    parser.add_argument("--config", type=Path, default=Path(os.environ.get("BUILD_ME_GODOT_CONTAINER_CONFIG", DEFAULT_CONTAINER_CONFIG)))
    args = parser.parse_args()
    if args.version:
        print("build-me-godot-container-triposr-provider 1")
        return 0
    if args.input is None or args.output is None or args.metadata_output is None:
        parser.error("--input, --output, and --metadata-output are required")
    config = parse_env_file(args.config.expanduser())
    command = build_run_command(config, "triposr-job", [
        "--input", str(args.input.resolve()),
        "--output", str(args.output.resolve()),
        "--metadata-output", str(args.metadata_output.resolve()),
    ])
    result = subprocess.run(command, check=False)
    if result.returncode != 0 and not args.metadata_output.exists():
        args.metadata_output.parent.mkdir(parents=True, exist_ok=True)
        args.metadata_output.write_text(json.dumps({
            "schema_version": 1,
            "provider": "container_triposr",
            "ok": False,
            "exit_code": result.returncode,
            "command": command,
        }, indent=2) + "\n", encoding="utf-8")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
