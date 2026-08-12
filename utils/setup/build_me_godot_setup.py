#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONFIG = PROJECT_ROOT / "utils" / "check-local-requirements.local.conf"
EXAMPLE_CONFIG = PROJECT_ROOT / "utils" / "check-local-requirements.conf.example"
HELPER_SOURCE = PROJECT_ROOT / "addons" / "build_me_godot" / "integrations" / "comfyui" / "character_turnaround_output.py"
WORKFLOW_REQUIREMENTS = [
    PROJECT_ROOT / "addons" / "build_me_godot" / "workflows" / "canonical_only_api.requirements.json",
    PROJECT_ROOT / "addons" / "build_me_godot" / "workflows" / "multiview_only_api.requirements.json",
    PROJECT_ROOT / "build_me_godot" / "workflows" / "qwen_blender_reference_set_ui.requirements.json",
]


MODEL_PATHS = {
    "CLIPLoader": ["models/text_encoders", "models/clip"],
    "VAELoader": ["models/vae"],
    "UNETLoader": ["models/diffusion_models", "models/unet"],
    "LoraLoaderModelOnly": ["models/loras"],
}

PRIMARY_MODEL_PATH = {
    "CLIPLoader": "models/text_encoders",
    "VAELoader": "models/vae",
    "UNETLoader": "models/diffusion_models",
    "LoraLoaderModelOnly": "models/loras",
}

MODEL_URLS = {
    ("Comfy-Org/Qwen-Image_ComfyUI", "qwen_2.5_vl_7b_fp8_scaled.safetensors"):
        "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
    ("Comfy-Org/Qwen-Image_ComfyUI", "qwen_image_vae.safetensors"):
        "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors",
    ("Comfy-Org/Qwen-Image_ComfyUI", "qwen_image_2512_fp8_e4m3fn.safetensors"):
        "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors",
    ("Comfy-Org/Qwen-Image-Edit_ComfyUI", "qwen_image_edit_2511_fp8mixed.safetensors"):
        "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors",
    ("lightx2v/Qwen-Image-Edit-2511-Lightning", "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"):
        "https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
    ("Wuli-art/Qwen-Image-2512-Turbo-LoRA-2-Steps", "Wuli-Qwen-Image-2512-Turbo-LoRA-2steps-V1.0-bf16.safetensors"):
        "https://huggingface.co/Wuli-art/Qwen-Image-2512-Turbo-LoRA-2-Steps/resolve/main/Wuli-Qwen-Image-2512-Turbo-LoRA-2steps-V1.0-bf16.safetensors",
}


@dataclass
class Check:
    id: str
    status: str
    summary: str
    required: bool = True
    details: dict[str, Any] = field(default_factory=dict)


@dataclass
class Action:
    id: str
    summary: str
    mutates: bool
    ready: bool = True
    details: dict[str, Any] = field(default_factory=dict)


@dataclass
class Context:
    config_path: Path
    comfyui_url: str
    comfyui_root: Path | None
    comfyui_root_source: str
    model_download_dir: Path
    blender: str
    ollama_host: str
    ollama_models_dir: Path
    ollama_models: list[str]
    json_output: bool
    assume_yes: bool
    non_interactive: bool
    checks: list[Check] = field(default_factory=list)
    actions: list[Action] = field(default_factory=list)
    missing_models: list[dict[str, str]] = field(default_factory=list)
    missing_nodes: list[str] = field(default_factory=list)
    changed_paths: list[str] = field(default_factory=list)


def parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        try:
            parts = shlex.split(value, comments=False, posix=True)
        except ValueError:
            parts = [value.strip()]
        values[key] = parts[0] if parts else ""
    return values


def shell_value(value: str) -> str:
    return shlex.quote(value)


def command_path(command: str) -> str | None:
    if "/" in command:
        path = Path(command).expanduser()
        return str(path) if path.exists() and os.access(path, os.X_OK) else None
    return shutil.which(command)


def http_json(url: str, timeout: float = 3.0) -> tuple[bool, Any]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            data = response.read().decode("utf-8")
        return True, json.loads(data)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        return False, {"error": str(exc)}


def is_comfyui_root(path: Path | None) -> bool:
    if path is None:
        return False
    return (path / "custom_nodes").is_dir() and ((path / "models").is_dir() or (path / "main.py").is_file() or (path / "user").is_dir())


def comfy_port(url: str) -> str | None:
    match = re.match(r"^[a-zA-Z]+://(?:\[[^]]+\]|[^/:]+):([0-9]+)", url)
    return match.group(1) if match else None


def discover_comfy_root(url: str) -> tuple[Path | None, str]:
    port = comfy_port(url)
    if port and shutil.which("ss"):
        try:
            output = subprocess.run(["ss", "-ltnp"], check=False, text=True, capture_output=True).stdout
            for line in output.splitlines():
                if not re.search(rf":{re.escape(port)}\s", line):
                    continue
                pid_match = re.search(r"pid=([0-9]+)", line)
                if not pid_match:
                    continue
                pid = pid_match.group(1)
                try:
                    cwd = Path(f"/proc/{pid}/cwd").resolve()
                except OSError:
                    continue
                for candidate, source in [(cwd, f"running process cwd for pid {pid}"), (cwd.parent, f"parent of running process cwd for pid {pid}")]:
                    if is_comfyui_root(candidate):
                        return candidate, source
        except OSError:
            pass

    for candidate in [
        Path.cwd() / "ComfyUI",
        Path.home() / "ComfyUI",
        Path.home() / "src" / "ComfyUI",
        Path.home() / "verdant" / "ComfyUI",
        Path.home() / ".local" / "share" / "ComfyUI",
    ]:
        if is_comfyui_root(candidate):
            return candidate, "common path"
    return None, ""


def load_model_artifacts() -> list[dict[str, str]]:
    artifacts: dict[tuple[str, str], dict[str, str]] = {}
    for path in WORKFLOW_REQUIREMENTS:
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        for artifact in data.get("model_artifacts", []):
            key = (artifact["loader"], artifact["value"])
            artifacts[key] = {
                "loader": artifact["loader"],
                "value": artifact["value"],
                "repository": artifact.get("repository", ""),
                "license": artifact.get("weight_license", ""),
            }
    return sorted(artifacts.values(), key=lambda item: item["value"])


def load_required_nodes() -> list[str]:
    nodes: set[str] = set()
    for path in WORKFLOW_REQUIREMENTS:
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        nodes.update(data.get("required_node_classes", []))
    return sorted(nodes)


def model_url(artifact: dict[str, str]) -> str:
    key = (artifact["repository"], artifact["value"])
    return MODEL_URLS.get(key, f"https://huggingface.co/{artifact['repository']}/resolve/main/{artifact['value']}")


def model_sha256(_artifact: dict[str, str]) -> str:
    return ""


def model_dest_dir(comfy_root: Path, loader: str) -> Path:
    return comfy_root / PRIMARY_MODEL_PATH.get(loader, "models")


def find_model(comfy_root: Path, artifact: dict[str, str]) -> Path | None:
    for rel in MODEL_PATHS.get(artifact["loader"], ["models"]):
        candidate = comfy_root / rel / artifact["value"]
        if candidate.exists():
            return candidate
    return None


def build_context(args: argparse.Namespace) -> Context:
    config_path = Path(args.config).expanduser() if args.config else Path(os.environ.get("BUILD_ME_GODOT_SETUP_CONFIG", DEFAULT_CONFIG)).expanduser()
    config = parse_env_file(config_path)

    def setting(key: str, default: str) -> str:
        return os.environ.get(key, config.get(key, default))

    comfyui_url = args.comfyui_url or setting("BUILD_ME_GODOT_COMFYUI_URL", "http://127.0.0.1:8188")
    comfyui_root_text = args.comfyui_root or setting("BUILD_ME_GODOT_COMFYUI_ROOT", "")
    comfyui_root = Path(comfyui_root_text).expanduser() if comfyui_root_text else None
    model_download_dir = Path(args.model_download_dir or setting("BUILD_ME_GODOT_MODEL_DOWNLOAD_DIR", str(Path.cwd()))).expanduser()
    blender = args.blender or setting("BUILD_ME_GODOT_BLENDER_PATH", "blender")
    ollama_host = setting("BUILD_ME_GODOT_OLLAMA_HOST", os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434"))
    ollama_models_dir = Path(setting("BUILD_ME_GODOT_OLLAMA_MODELS_DIR", os.environ.get("OLLAMA_MODELS", str(Path.home() / ".ollama" / "models")))).expanduser()
    configured_models = setting("BUILD_ME_GODOT_OLLAMA_MODELS", "")
    ollama_models = configured_models.split() if configured_models else []
    ollama_models.extend(args.ollama_model or [])

    return Context(
        config_path=config_path,
        comfyui_url=comfyui_url,
        comfyui_root=comfyui_root,
        comfyui_root_source="configured path" if comfyui_root else "",
        model_download_dir=model_download_dir,
        blender=blender,
        ollama_host=ollama_host,
        ollama_models_dir=ollama_models_dir,
        ollama_models=ollama_models,
        json_output=bool(args.json),
        assume_yes=bool(args.yes),
        non_interactive=bool(args.non_interactive),
    )


def add_check(ctx: Context, check: Check) -> None:
    ctx.checks.append(check)
    if not ctx.json_output:
        print(f"[{check.status}] {check.summary}")


def add_action(ctx: Context, action: Action) -> None:
    if all(existing.id != action.id for existing in ctx.actions):
        ctx.actions.append(action)


def run_checks(ctx: Context) -> None:
    add_check(ctx, Check("project.file", "ok" if (PROJECT_ROOT / "project.godot").exists() else "missing", "Godot project file"))
    add_check(ctx, Check("addon.source", "ok" if (PROJECT_ROOT / "addons" / "build_me_godot").is_dir() else "missing", "Build Me Godot addon source"))

    godot = command_path("godot")
    add_check(ctx, Check("tool.godot", "ok" if godot else "missing", f"Godot executable: {godot or 'missing'}", details={"path": godot}))
    blender = command_path(ctx.blender)
    add_check(ctx, Check("tool.blender", "ok" if blender else "missing", f"Blender executable: {blender or 'missing'}", details={"path": blender}))

    ok, stats = http_json(ctx.comfyui_url.rstrip("/") + "/system_stats")
    add_check(ctx, Check("comfyui.server", "ok" if ok else "missing", f"ComfyUI server at {ctx.comfyui_url}", details={"response": stats if not ok else "reachable"}))

    if not is_comfyui_root(ctx.comfyui_root):
        discovered, source = discover_comfy_root(ctx.comfyui_url)
        ctx.comfyui_root, ctx.comfyui_root_source = discovered, source
    add_check(ctx, Check(
        "comfyui.root",
        "ok" if is_comfyui_root(ctx.comfyui_root) else "skip",
        f"ComfyUI root: {ctx.comfyui_root} ({ctx.comfyui_root_source})" if ctx.comfyui_root else "ComfyUI root not configured or discovered",
        required=False,
    ))

    if ctx.comfyui_root:
        helper = ctx.comfyui_root / "custom_nodes" / "character_turnaround_output.py"
        if helper.exists():
            add_check(ctx, Check("comfyui.helper", "ok", "ComfyUI turnaround helper", details={"path": str(helper)}))
        else:
            add_check(ctx, Check("comfyui.helper", "missing", "ComfyUI turnaround helper", details={"target": str(helper)}))
            add_action(ctx, Action("install.comfyui.helper", "Copy the Build Me Godot ComfyUI helper into custom_nodes.", True, details={"target": str(helper), "source": str(HELPER_SOURCE), "restart_required": True}))

    ok, object_info = http_json(ctx.comfyui_url.rstrip("/") + "/object_info")
    if ok:
        missing_nodes = [node for node in load_required_nodes() if node not in object_info]
        ctx.missing_nodes = missing_nodes
        add_check(ctx, Check("comfyui.nodes", "ok" if not missing_nodes else "missing", "ComfyUI required workflow nodes", details={"missing": missing_nodes}))
    else:
        add_check(ctx, Check("comfyui.nodes", "skip", "ComfyUI node metadata unavailable", details=object_info))

    if ctx.comfyui_root:
        for artifact in load_model_artifacts():
            if find_model(ctx.comfyui_root, artifact) is None:
                row = artifact | {
                    "url": model_url(artifact),
                    "sha256": model_sha256(artifact),
                    "staged_path": str(ctx.model_download_dir / artifact["value"]),
                    "target_dir": str(model_dest_dir(ctx.comfyui_root, artifact["loader"])),
                }
                ctx.missing_models.append(row)
        add_check(ctx, Check("comfyui.models", "ok" if not ctx.missing_models else "missing", "ComfyUI declared model files", details={"missing": ctx.missing_models}))
        if ctx.missing_models:
            add_action(ctx, Action("download.models", "Download missing reviewed model files into the staging directory.", True, details={"directory": str(ctx.model_download_dir), "models": ctx.missing_models}))
            staged = [row for row in ctx.missing_models if Path(row["staged_path"]).exists()]
            add_action(ctx, Action("move.models", "Move staged model files into the correct ComfyUI model directories.", True, ready=bool(staged), details={"staged_ready": staged, "requires_staged_files": True}))
    else:
        add_check(ctx, Check("comfyui.models", "skip", "ComfyUI model files require ComfyUI root", required=False))

    if ctx.ollama_models:
        ollama = command_path("ollama")
        add_check(ctx, Check("tool.ollama", "ok" if ollama else "missing", f"Ollama executable: {ollama or 'missing'}", required=False, details={"path": ollama}))
        if ollama:
            result = subprocess.run(["ollama", "list"], check=False, text=True, capture_output=True)
            installed = {line.split()[0] for line in result.stdout.splitlines()[1:] if line.split()}
            missing = [model for model in ctx.ollama_models if model not in installed]
            add_check(ctx, Check("ollama.models", "ok" if not missing else "missing", "Ollama requested models", required=False, details={"missing": missing}))
            for model in missing:
                add_action(ctx, Action(f"pull.ollama.{model}", f"Pull Ollama model {model}.", True, details={"model": model}))
    else:
        add_check(ctx, Check("ollama.models", "skip", "Ollama models not requested", required=False))

    add_action(ctx, Action("write.local.config", "Write reusable gitignored local setup config.", True, details={"target": str(ctx.config_path)}))
    add_action(ctx, Action("open.comfy", "Print the configured ComfyUI URL for opening in a browser.", False, details={"url": ctx.comfyui_url}))


def write_config(ctx: Context) -> Path:
    ctx.config_path.parent.mkdir(parents=True, exist_ok=True)
    models = " ".join(ctx.ollama_models)
    blender = command_path(ctx.blender) or ctx.blender
    content = "\n".join([
        "# Build Me Godot local setup configuration.",
        "# This file is machine-local and intentionally gitignored.",
        "",
        f"BUILD_ME_GODOT_COMFYUI_URL={shell_value(ctx.comfyui_url)}",
        f"BUILD_ME_GODOT_COMFYUI_ROOT={shell_value(str(ctx.comfyui_root or ''))}",
        f"BUILD_ME_GODOT_MODEL_DOWNLOAD_DIR={shell_value(str(ctx.model_download_dir))}",
        f"BUILD_ME_GODOT_BLENDER_PATH={shell_value(blender)}",
        f"BUILD_ME_GODOT_OLLAMA_HOST={shell_value(ctx.ollama_host)}",
        f"BUILD_ME_GODOT_OLLAMA_MODELS_DIR={shell_value(str(ctx.ollama_models_dir))}",
        f"BUILD_ME_GODOT_OLLAMA_MODELS={shell_value(models)}",
        "",
        "# ComfyUI model placement guide:",
        "# text encoders: $BUILD_ME_GODOT_COMFYUI_ROOT/models/text_encoders/",
        "# diffusion models: $BUILD_ME_GODOT_COMFYUI_ROOT/models/diffusion_models/",
        "# VAEs: $BUILD_ME_GODOT_COMFYUI_ROOT/models/vae/",
        "# LoRAs: $BUILD_ME_GODOT_COMFYUI_ROOT/models/loras/",
        "",
    ])
    ctx.config_path.write_text(content, encoding="utf-8")
    ctx.changed_paths.append(str(ctx.config_path))
    return ctx.config_path


def action_detail_lines(action: Action) -> list[str]:
    details = action.details
    if action.id == "write.local.config":
        return [f"Write local setup config: {details.get('target', '')}"]
    if action.id == "install.comfyui.helper":
        return [
            f"Copy: {details.get('source', '')}",
            f"Into: {details.get('target', '')}",
            "Restart ComfyUI after installation so the helper nodes are loaded.",
        ]
    if action.id == "download.models":
        models = details.get("models", [])
        lines = [f"Download {len(models)} model file(s) into: {details.get('directory', '')}"]
        lines.extend(f"- {row.get('value', '')}" for row in models)
        return lines
    if action.id == "move.models":
        staged = details.get("staged_ready", [])
        lines = [f"Move {len(staged)} staged model file(s) into ComfyUI model directories."]
        lines.extend(f"- {row.get('staged_path', '')} -> {row.get('target_dir', '')}" for row in staged)
        return lines
    if action.id.startswith("pull.ollama."):
        return [f"Run: ollama pull {details.get('model', action.id.removeprefix('pull.ollama.'))}"]
    return [action.summary]


def confirm_action(ctx: Context, action: Action) -> None:
    if not action.mutates or ctx.assume_yes:
        return
    if ctx.json_output or ctx.non_interactive or not sys.stdin.isatty():
        raise SystemExit(f"Action {action.id} requires confirmation. Rerun with --yes after explicit approval.")

    print("\nAbout to apply action:")
    print(f"  {action.id}: {action.summary}")
    for line in action_detail_lines(action):
        print(f"  {line}")
    print("\nHelp: run `doctor` to list actions, use `--yes` for approved automation, or press Enter to cancel.")
    answer = input("Proceed? [y/N] ").strip().lower()
    if answer not in {"y", "yes"}:
        raise SystemExit("Cancelled.")


def apply_action(ctx: Context, action_id: str) -> None:
    run_checks(ctx)
    actions = {action.id: action for action in ctx.actions}
    if action_id not in actions:
        raise SystemExit(f"Unknown or unavailable action: {action_id}")
    action = actions[action_id]
    if not action.ready:
        raise SystemExit(f"Action is not ready: {action_id}")
    confirm_action(ctx, action)

    def emit(message: str) -> None:
        if ctx.json_output:
            return
        stream = sys.stderr if ctx.json_output else sys.stdout
        print(message, file=stream)

    if action_id == "write.local.config":
        path = write_config(ctx)
        emit(f"Wrote {path}")
    elif action_id == "install.comfyui.helper":
        if not ctx.comfyui_root:
            raise SystemExit("ComfyUI root is required.")
        target = ctx.comfyui_root / "custom_nodes" / "character_turnaround_output.py"
        if target.exists():
            raise SystemExit(f"Refusing to overwrite existing helper: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(HELPER_SOURCE, target)
        ctx.changed_paths.append(str(target))
        emit(f"Installed helper: {target}")
        emit("Restart ComfyUI before rechecking nodes.")
    elif action_id == "download.models":
        ctx.model_download_dir.mkdir(parents=True, exist_ok=True)
        for row in ctx.missing_models:
            target = Path(row["staged_path"])
            if target.exists():
                emit(f"Already staged: {target}")
                continue
            emit(f"Downloading {row['value']}")
            urllib.request.urlretrieve(row["url"], target)
            ctx.changed_paths.append(str(target))
    elif action_id == "move.models":
        moved = 0
        for row in ctx.missing_models:
            source = Path(row["staged_path"])
            if not source.exists():
                continue
            target_dir = Path(row["target_dir"])
            target = target_dir / row["value"]
            if target.exists():
                raise SystemExit(f"Refusing to overwrite existing model: {target}")
            target_dir.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), target)
            ctx.changed_paths.append(str(target))
            moved += 1
            emit(f"Moved {target}")
        if moved == 0:
            raise SystemExit("No staged model files were found to move.")
    elif action_id.startswith("pull.ollama."):
        model = action_id.removeprefix("pull.ollama.")
        subprocess.run(["ollama", "pull", model], check=True)
    elif action_id == "open.comfy":
        emit(ctx.comfyui_url)
    else:
        raise SystemExit(f"Action is not implemented: {action_id}")


def report(ctx: Context) -> dict[str, Any]:
    ready = all(check.status == "ok" for check in ctx.checks if check.required)
    return {
        "schema_version": 1,
        "ready": ready,
        "project_root": str(PROJECT_ROOT),
        "config_path": str(ctx.config_path),
        "comfyui_url": ctx.comfyui_url,
        "comfyui_root": str(ctx.comfyui_root) if ctx.comfyui_root else "",
        "model_download_dir": str(ctx.model_download_dir),
        "checks": [check.__dict__ for check in ctx.checks],
        "actions": [action.__dict__ for action in ctx.actions],
        "changed_paths": ctx.changed_paths,
    }


def print_human(ctx: Context, include_actions: bool) -> None:
    if include_actions:
        print("\nAvailable actions:")
        for action in ctx.actions:
            marker = "ready" if action.ready else "blocked"
            print(f"- {action.id} [{marker}]: {action.summary}")
    if ctx.missing_models:
        print("\nModel download commands:")
        for row in ctx.missing_models:
            print(f"curl --location --fail --continue-at - --output './{row['value']}' '{row['url']}'")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Build Me Godot local setup assistant.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Agent-safe flow:
  check --json              Read-only diagnostics; exits 0 only when required checks pass.
  plan --json               Read-only diagnostics plus remediation action IDs.
  doctor                    Human-readable alias for plan.
  apply <action_id>         Explain one explicit action, ask, then apply it.
  apply <action_id> --yes --json
                            Run an approved action and report changed paths.

Mutating actions are never run by check, plan, or doctor. Use apply only after
the user has approved the specific action ID shown in the plan output.
""",
    )
    parser.add_argument("command", nargs="?", default="check", choices=["check", "plan", "doctor", "apply", "write-config", "open-comfy"], help="Command to run.")
    parser.add_argument("action_id", nargs="?", help="Action ID for apply.")
    parser.add_argument("--config")
    parser.add_argument("--comfyui-url")
    parser.add_argument("--comfyui-root")
    parser.add_argument("--blender")
    parser.add_argument("--model-download-dir")
    parser.add_argument("--ollama-model", action="append")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--yes", action="store_true", help="Apply the selected action without prompting after explicit approval.")
    parser.add_argument("--non-interactive", action="store_true", help="Do not prompt; mutating apply actions require --yes.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    ctx = build_context(args)

    if args.command == "apply":
        if not args.action_id:
            parser.error("apply requires an action ID")
        apply_action(ctx, args.action_id)
    elif args.command == "write-config":
        run_checks(ctx)
        actions = {action.id: action for action in ctx.actions}
        confirm_action(ctx, actions["write.local.config"])
        path = write_config(ctx)
        if not args.json:
            print(f"Wrote {path}")
    elif args.command == "open-comfy":
        if not args.json:
            print(ctx.comfyui_url)
    else:
        run_checks(ctx)
        if not args.json:
            if args.command in {"plan", "doctor"}:
                print_human(ctx, include_actions=True)
            else:
                print_human(ctx, include_actions=False)

    data = report(ctx)
    if args.json:
        print(json.dumps(data, indent=2, sort_keys=True))
    if args.command in {"apply", "write-config", "open-comfy"}:
        return 0
    return 0 if data["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
