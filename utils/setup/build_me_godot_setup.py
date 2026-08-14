#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import signal
import shlex
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ADDON_SOURCE = PROJECT_ROOT / "addons" / "build_me_godot"
DEFAULT_EXAMPLE_PROJECT = PROJECT_ROOT.parent / "godot-addons-example-project"
DEFAULT_CONFIG = PROJECT_ROOT / "utils" / "check-local-requirements.local.conf"
DEFAULT_CONTAINER_CONFIG = PROJECT_ROOT / "utils" / "check-local-container.local.env"
EXAMPLE_CONFIG = PROJECT_ROOT / "utils" / "check-local-requirements.conf.example"
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / f"build-me-godot-{os.getuid()}"
HELPER_SOURCE = PROJECT_ROOT / "addons" / "build_me_godot" / "integrations" / "comfyui" / "character_turnaround_output.py"
CONTAINER_CONTEXT_DIR = PROJECT_ROOT / "containers" / "local-toolchain"
CONTAINERFILE = CONTAINER_CONTEXT_DIR / "Containerfile"
CONTAINER_PROCESS_NAME = "container-comfyui"
WORKFLOW_REQUIREMENTS = [
    PROJECT_ROOT / "addons" / "build_me_godot" / "workflows" / "canonical_only_api.requirements.json",
    PROJECT_ROOT / "addons" / "build_me_godot" / "workflows" / "multiview_only_api.requirements.json",
    PROJECT_ROOT / "build_me_godot" / "workflows" / "qwen_blender_reference_set_ui.requirements.json",
]
HELPER_NODE_CLASSES = {
    "TurnaroundContactSheet",
    "TurnaroundLoadImage",
    "TurnaroundNormalize",
    "TurnaroundSaveImage",
}


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

TRIPOSR_MODEL_ARTIFACTS = [
    {
        "provider_id": "triposr",
        "value": "config.yaml",
        "repository": "stabilityai/TripoSR",
        "revision": "5b521936b01fbe1890f6f9baed0254ab6351c04a",
        "license": "MIT",
        "url": "https://huggingface.co/stabilityai/TripoSR/resolve/5b521936b01fbe1890f6f9baed0254ab6351c04a/config.yaml",
    },
    {
        "provider_id": "triposr",
        "value": "model.ckpt",
        "repository": "stabilityai/TripoSR",
        "revision": "5b521936b01fbe1890f6f9baed0254ab6351c04a",
        "license": "MIT",
        "url": "https://huggingface.co/stabilityai/TripoSR/resolve/5b521936b01fbe1890f6f9baed0254ab6351c04a/model.ckpt",
    },
]

FLOWTY_TRIPOSR_NODE = {
    "id": "flowty.triposr.node",
    "repository": "flowtyone/ComfyUI-Flowty-TripoSR",
    "branch": "master",
    "license": "GPL-3.0",
    "archive_name": "ComfyUI-Flowty-TripoSR-master.zip",
    "archive_url": "https://github.com/flowtyone/ComfyUI-Flowty-TripoSR/archive/refs/heads/master.zip",
    "target_dir_name": "ComfyUI-Flowty-TripoSR",
    "required_node_classes": ["TripoSRModelLoader", "TripoSRSampler", "TripoSRViewer"],
}

TRELLIS_PROVIDER_WRAPPER = PROJECT_ROOT / "utils" / "run-trellis.sh"
TRELLIS_REQUIREMENTS = ADDON_SOURCE / "integrations" / "reconstruction" / "trellis" / "trellis.requirements.json"
TRELLIS_SOURCE = {
    "repository": "microsoft/TRELLIS",
    "url": "https://github.com/microsoft/TRELLIS",
    "model_repository": "microsoft/TRELLIS-image-large",
    "model_url": "https://huggingface.co/microsoft/TRELLIS-image-large",
    "code_license": "MIT",
    "weight_license": "MIT",
    "minimum_vram_gb": 16,
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
    example_project: Path
    container_config_path: Path
    container_model_roots: list[Path]
    trellis_root: Path | None
    trellis_model_path: Path | None
    trellis_python: str
    json_output: bool
    assume_yes: bool
    non_interactive: bool
    checks: list[Check] = field(default_factory=list)
    actions: list[Action] = field(default_factory=list)
    missing_models: list[dict[str, str]] = field(default_factory=list)
    missing_triposr_models: list[dict[str, str]] = field(default_factory=list)
    missing_nodes: list[str] = field(default_factory=list)
    flowty_node_staged: Path | None = None
    changed_paths: list[str] = field(default_factory=list)
    quiet_checks: bool = False


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


def first_command(names: list[str]) -> tuple[str, str] | None:
    for name in names:
        path = command_path(name)
        if path:
            return name, path
    return None


def configured_model_roots(ctx: Context) -> list[Path]:
    roots: list[Path] = []
    roots.extend(ctx.container_model_roots)
    if ctx.trellis_model_path:
        roots.append(ctx.trellis_model_path)
    if ctx.comfyui_root:
        roots.append(ctx.comfyui_root / "models")
        roots.append(ctx.comfyui_root / "custom_nodes")
        roots.append(ctx.comfyui_root / "output")
    if ctx.model_download_dir.resolve() == PROJECT_ROOT.resolve():
        roots.append(ctx.model_download_dir / "triposr")
        roots.append(ctx.model_download_dir / "comfyui_nodes")
    else:
        roots.append(ctx.model_download_dir)
    roots.append(ctx.ollama_models_dir)

    unique: list[Path] = []
    seen: set[str] = set()
    for root in roots:
        key = str(root)
        if key not in seen:
            seen.add(key)
            unique.append(root)
    return unique


def nvidia_cdi_spec_paths() -> list[Path]:
    configured = os.environ.get("BUILD_ME_GODOT_NVIDIA_CDI_SPEC_PATHS", "")
    if configured:
        return [Path(value).expanduser() for value in shlex.split(configured)]
    return [Path("/var/run/cdi/nvidia.yaml"), Path("/etc/cdi/nvidia.yaml")]


def os_release_id() -> str:
    try:
        values = parse_env_file(Path("/etc/os-release"))
    except OSError:
        return ""
    return values.get("ID", "").lower()


def nvidia_container_toolkit_install_commands() -> list[str]:
    os_id = os_release_id()
    if os_id in {"fedora", "rhel", "centos", "rocky", "almalinux", "amzn"}:
        return [
            "sudo dnf install -y curl",
            "curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo",
            "sudo dnf install -y nvidia-container-toolkit",
        ]
    if os_id in {"ubuntu", "debian", "linuxmint", "pop"}:
        return [
            "sudo apt-get update && sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg2",
            "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg",
            "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list",
            "sudo apt-get update",
            "sudo apt-get install -y nvidia-container-toolkit",
        ]
    return [
        "Install NVIDIA Container Toolkit for your Linux distribution.",
    ]


def container_config(ctx: Context) -> dict[str, str]:
    config = parse_env_file(ctx.container_config_path)
    if "BUILD_ME_GODOT_CONTAINER_RUNTIME" not in config:
        runtime = first_command(["podman", "docker", "apptainer"])
        if runtime:
            config["BUILD_ME_GODOT_CONTAINER_RUNTIME"] = runtime[0]
    config.setdefault("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev")
    config.setdefault("BUILD_ME_GODOT_CONTAINER_PROJECT_ROOT", str(PROJECT_ROOT))
    config.setdefault("BUILD_ME_GODOT_CONTAINER_MODEL_ROOTS", " ".join(str(path) for path in configured_model_roots(ctx) if path.exists()))
    config.setdefault("BUILD_ME_GODOT_CONTAINER_GPU_ARGS", "--device nvidia.com/gpu=all --security-opt=label=disable" if command_path("nvidia-smi") else "")
    return config


def container_runtime_command(config: dict[str, str]) -> str | None:
    runtime = config.get("BUILD_ME_GODOT_CONTAINER_RUNTIME", "")
    return command_path(runtime) if runtime else None


def container_image_exists(config: dict[str, str]) -> bool:
    runtime = container_runtime_command(config)
    image = config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "")
    if not runtime or not image:
        return False
    if Path(runtime).name == "podman":
        return subprocess.run([runtime, "image", "exists", image], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if Path(runtime).name == "docker":
        return subprocess.run([runtime, "image", "inspect", image], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if Path(runtime).name == "apptainer":
        return Path(image).exists()
    return False


def container_run_base(config: dict[str, str]) -> list[str]:
    runtime = container_runtime_command(config)
    if not runtime:
        raise SystemExit("Configured container runtime was not found.")
    if Path(runtime).name == "apptainer":
        raise SystemExit("Apptainer execution is documented but not implemented by this setup action yet.")
    command = [runtime, "run", "--rm"]
    command.extend(shlex.split(config.get("BUILD_ME_GODOT_CONTAINER_GPU_ARGS", "")))
    project_root = Path(config.get("BUILD_ME_GODOT_CONTAINER_PROJECT_ROOT", PROJECT_ROOT)).expanduser()
    if project_root.exists():
        command.extend(["-v", f"{project_root}:{project_root}:rw", "-e", f"BUILD_ME_GODOT_PROJECT_ROOT={project_root}", "-w", str(project_root)])
    for source, target in container_mounts(config):
        command.extend(["-v", f"{source}:{target}:rw"])
    return command


def container_command(config: dict[str, str], mode: str, extra: list[str] | None = None) -> list[str]:
    return [*container_run_base(config), config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"), mode, *(extra or [])]


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


def http_json(url: str, timeout: float = 3.0) -> tuple[bool, Any]:
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            data = response.read().decode("utf-8")
        return True, json.loads(data)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        return False, {"error": str(exc)}


def wait_for_http(url: str, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        ok, _data = http_json(url, timeout=1.0)
        if ok:
            return True
        time.sleep(0.5)
    return False


def startup_timeout(default: float) -> float:
    try:
        return max(0.0, float(os.environ.get("BUILD_ME_GODOT_STARTUP_TIMEOUT", str(default))))
    except ValueError:
        return default


def process_record_path(name: str) -> Path:
    return RUNTIME_DIR / f"{name}.json"


def remove_process_record(name: str) -> None:
    try:
        process_record_path(name).unlink(missing_ok=True)
    except OSError:
        pass


def managed_process(name: str) -> dict[str, Any] | None:
    path = process_record_path(name)
    try:
        record = json.loads(path.read_text(encoding="utf-8"))
        pid = int(record["pid"])
        os.kill(pid, 0)
        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace")
        if record.get("marker", "") not in cmdline:
            raise ProcessLookupError
        return record
    except (FileNotFoundError, json.JSONDecodeError, KeyError, TypeError, ValueError, OSError, ProcessLookupError):
        remove_process_record(name)
        return None


def start_managed_process(name: str, command: list[str], cwd: Path | None, marker: str) -> tuple[int, Path]:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    log_path = RUNTIME_DIR / f"{name}.log"
    log = log_path.open("ab")
    try:
        process = subprocess.Popen(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    finally:
        log.close()
    record = {"pid": process.pid, "command": command, "cwd": str(cwd or ""), "marker": marker, "log": str(log_path)}
    process_record_path(name).write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    time.sleep(0.1)
    if process.poll() is not None:
        remove_process_record(name)
        raise SystemExit(f"{name} exited immediately; inspect {log_path}")
    return process.pid, log_path


def stop_managed_process(name: str) -> int:
    record = managed_process(name)
    if record is None:
        raise SystemExit(f"No running {name} process managed by this utility was found.")
    pid = int(record["pid"])
    os.killpg(pid, signal.SIGTERM)
    for _attempt in range(30):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    remove_process_record(name)
    return pid


def comfyui_start_command(ctx: Context) -> list[str] | None:
    if not is_comfyui_root(ctx.comfyui_root) or not (ctx.comfyui_root / "main.py").is_file():
        return None
    python_candidates = [ctx.comfyui_root / ".venv" / "bin" / "python", ctx.comfyui_root / "venv" / "bin" / "python"]
    python = next((str(path) for path in python_candidates if path.is_file() and os.access(path, os.X_OK)), sys.executable)
    parsed = urllib.parse.urlparse(ctx.comfyui_url)
    command = [python, "main.py"]
    if parsed.hostname:
        command.extend(["--listen", parsed.hostname])
    if parsed.port:
        command.extend(["--port", str(parsed.port)])
    return command


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


def is_trellis_root(path: Path | None) -> bool:
    if path is None:
        return False
    return (path / "trellis" / "pipelines").is_dir() and ((path / "setup.sh").exists() or (path / "app.py").exists())


def trellis_model_ready(path: Path | None) -> bool:
    if path is None or not path.exists():
        return False
    if path.is_file():
        return True
    return any((path / name).exists() for name in ["model_index.json", "pipeline.json", "config.json"]) or any(path.glob("*.safetensors"))


def trellis_manual_commands(ctx: Context) -> list[str]:
    root_arg = shlex.quote(str(ctx.trellis_root)) if ctx.trellis_root else "${HOME}/src/TRELLIS"
    model_arg = shlex.quote(str(ctx.trellis_model_path)) if ctx.trellis_model_path else "${HOME}/.cache/huggingface/hub/models--microsoft--TRELLIS-image-large/snapshots/<revision>"
    return [
        "git clone --recursive https://github.com/microsoft/TRELLIS.git " + root_arg,
        "cd " + root_arg + " && . ./setup.sh --new-env --basic --xformers --spconv --mipgaussian --kaolin --nvdiffrast",
        "Download microsoft/TRELLIS-image-large from Hugging Face after reviewing the MIT model license.",
        "export BUILD_ME_GODOT_TRELLIS_ROOT=" + root_arg,
        "export BUILD_ME_GODOT_TRELLIS_MODEL_PATH=" + model_arg,
        "export BUILD_ME_GODOT_RECONSTRUCTION_COMMAND='bash utils/run-trellis.sh'",
    ]


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
    example_project = Path(args.example_project or setting("BUILD_ME_GODOT_EXAMPLE_PROJECT", str(DEFAULT_EXAMPLE_PROJECT))).expanduser()
    container_config_path = Path(args.container_config or setting("BUILD_ME_GODOT_CONTAINER_CONFIG", str(DEFAULT_CONTAINER_CONFIG))).expanduser()
    configured_container_roots = setting("BUILD_ME_GODOT_CONTAINER_MODEL_ROOTS", "")
    container_model_roots = [Path(value).expanduser() for value in shlex.split(configured_container_roots)] if configured_container_roots else []
    trellis_root_text = args.trellis_root or setting("BUILD_ME_GODOT_TRELLIS_ROOT", os.environ.get("TRELLIS_ROOT", ""))
    trellis_model_text = args.trellis_model_path or setting("BUILD_ME_GODOT_TRELLIS_MODEL_PATH", "")
    trellis_python = args.trellis_python or setting("BUILD_ME_GODOT_TRELLIS_PYTHON", "")

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
        example_project=example_project,
        container_config_path=container_config_path,
        container_model_roots=container_model_roots,
        trellis_root=Path(trellis_root_text).expanduser() if trellis_root_text else None,
        trellis_model_path=Path(trellis_model_text).expanduser() if trellis_model_text else None,
        trellis_python=trellis_python,
        json_output=bool(args.json),
        assume_yes=bool(args.yes),
        non_interactive=bool(args.non_interactive),
    )


def add_check(ctx: Context, check: Check) -> None:
    ctx.checks.append(check)
    if not ctx.json_output and not ctx.quiet_checks:
        print(f"[{check.status}] {check.summary}")


def add_action(ctx: Context, action: Action) -> None:
    if all(existing.id != action.id for existing in ctx.actions):
        ctx.actions.append(action)


def reset_results(ctx: Context) -> None:
    ctx.checks.clear()
    ctx.actions.clear()
    ctx.missing_models.clear()
    ctx.missing_triposr_models.clear()
    ctx.missing_nodes.clear()
    ctx.flowty_node_staged = None


def run_checks(ctx: Context) -> None:
    add_check(ctx, Check("project.file", "ok" if (PROJECT_ROOT / "project.godot").exists() else "missing", "Godot project file"))
    add_check(ctx, Check("addon.source", "ok" if ADDON_SOURCE.is_dir() else "missing", "Build Me Godot addon source"))

    godot = command_path("godot")
    add_check(ctx, Check("tool.godot", "ok" if godot else "missing", f"Godot executable: {godot or 'missing'}", details={"path": godot}))
    blender = command_path(ctx.blender)
    add_check(ctx, Check("tool.blender", "ok" if blender else "missing", f"Blender executable: {blender or 'missing'}", details={"path": blender}))
    container_runtime = first_command(["podman", "docker", "apptainer"])
    all_container_runtimes = {name: command_path(name) for name in ["podman", "docker", "apptainer"]}
    add_check(ctx, Check(
        "container.runtime",
        "ok" if container_runtime else "skip",
        f"Container runtime: {container_runtime[0]} ({container_runtime[1]})" if container_runtime else "Container runtime not found",
        required=False,
        details={
            "preferred_order": ["podman", "docker", "apptainer"],
            "detected": {name: path for name, path in all_container_runtimes.items() if path},
            "purpose": "Optional isolated ComfyUI/TripoSR/Blender toolchain.",
        },
    ))
    nvidia_smi = command_path("nvidia-smi")
    nvidia_ctk = command_path("nvidia-ctk")
    cdi_paths = nvidia_cdi_spec_paths()
    cdi_spec_exists = any(path.exists() for path in cdi_paths)
    cdi_path_text = [str(path) for path in cdi_paths]
    nvidia_cdi_summary = "NVIDIA GPU not detected for container checks"
    if nvidia_smi and cdi_spec_exists:
        nvidia_cdi_summary = "NVIDIA CDI GPU spec available"
    elif nvidia_smi and not nvidia_ctk:
        nvidia_cdi_summary = "NVIDIA GPU found; nvidia-ctk missing and CDI spec not detected"
    elif nvidia_smi:
        nvidia_cdi_summary = "NVIDIA GPU found; CDI spec not detected"
    add_check(ctx, Check(
        "container.gpu.nvidia_cdi",
        "ok" if nvidia_smi and cdi_spec_exists else ("warning" if nvidia_smi else "skip"),
        nvidia_cdi_summary,
        required=False,
        details={
            "nvidia_smi": nvidia_smi or "",
            "nvidia_ctk": nvidia_ctk or "",
            "cdi_specs": [str(path) for path in cdi_paths if path.exists()],
            "expected_cdi_specs": cdi_path_text,
            "podman_device_arg": "--device nvidia.com/gpu=all",
        },
    ))
    if nvidia_smi and not cdi_spec_exists:
        toolkit_install_commands = nvidia_container_toolkit_install_commands()
        add_action(ctx, Action(
            "manual.configure.nvidia.cdi",
            "Configure NVIDIA CDI so Podman can pass the GPU into local generation containers.",
            False,
            details={
                "nvidia_smi": nvidia_smi,
                "nvidia_ctk": nvidia_ctk or "",
                "package_manager": "dnf" if os_release_id() in {"fedora", "rhel", "centos", "rocky", "almalinux", "amzn"} else ("apt-get" if os_release_id() in {"ubuntu", "debian", "linuxmint", "pop"} else ""),
                "toolkit_install_commands": toolkit_install_commands,
                "expected_cdi_specs": cdi_path_text,
                "commands": ([
                    "nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml",
                    "nvidia-ctk cdi list",
                    "podman run --rm --device nvidia.com/gpu=all --security-opt=label=disable nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi -L",
                ] if nvidia_ctk else toolkit_install_commands + [
                    "nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml",
                    "nvidia-ctk cdi list",
                    "podman run --rm --device nvidia.com/gpu=all --security-opt=label=disable nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi -L",
                ]),
                "requires_privilege": True,
                "restart_note": "Regenerate CDI after NVIDIA driver, toolkit, or MIG configuration changes.",
            },
        ))
    model_roots = configured_model_roots(ctx)
    existing_model_roots = [str(path) for path in model_roots if path.exists()]
    add_check(ctx, Check(
        "container.model_mounts",
        "ok" if existing_model_roots else "warning",
        f"Container model/cache mounts discovered: {len(existing_model_roots)}",
        required=False,
        details={
            "existing": existing_model_roots,
            "missing": [str(path) for path in model_roots if not path.exists()],
            "strategy": "Mount user-owned model, custom node, output, and cache directories; do not bake model weights into images.",
            "config_path": str(ctx.container_config_path),
        },
    ))
    if container_runtime and existing_model_roots and not ctx.container_config_path.exists():
        add_action(ctx, Action(
            "write.container.config",
            "Write a gitignored container toolchain env file that reuses existing local model folders.",
            True,
            details={
                "target": str(ctx.container_config_path),
                "runtime": container_runtime[0],
                "model_roots": existing_model_roots,
                "gpu_device_arg": "--device nvidia.com/gpu=all" if nvidia_smi else "",
                "license_boundary": "Container images must not include model weights by default.",
            },
        ))
    container_cfg = container_config(ctx)
    container_runtime_path = container_runtime_command(container_cfg)
    container_recipe_ready = CONTAINERFILE.is_file()
    container_image_ready = container_image_exists(container_cfg)
    add_check(ctx, Check(
        "container.recipe",
        "ok" if container_recipe_ready else "missing",
        f"Container toolchain recipe: {CONTAINERFILE}" if container_recipe_ready else "Container toolchain recipe missing",
        required=False,
        details={
            "context": str(CONTAINER_CONTEXT_DIR),
            "containerfile": str(CONTAINERFILE),
            "modes": ["doctor", "comfyui-server", "triposr-job", "blender-job"],
            "weights_baked": False,
        },
    ))
    add_check(ctx, Check(
        "container.image.local_toolchain",
        "ok" if container_image_ready else "missing",
        f"Container image available: {container_cfg.get('BUILD_ME_GODOT_CONTAINER_IMAGE', '')}" if container_image_ready else f"Container image not built: {container_cfg.get('BUILD_ME_GODOT_CONTAINER_IMAGE', '')}",
        required=False,
        details={
            "runtime": container_cfg.get("BUILD_ME_GODOT_CONTAINER_RUNTIME", ""),
            "runtime_path": container_runtime_path or "",
            "image": container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""),
            "config": str(ctx.container_config_path),
        },
    ))
    if container_runtime_path and container_recipe_ready and not container_image_ready:
        add_action(ctx, Action(
            "container.build.local_toolchain",
            "Build the local ComfyUI/TripoSR/Blender container image from the reviewed recipe.",
            True,
            details={
                "command": [container_runtime_path, "build", "-t", container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"), "-f", str(CONTAINERFILE), str(CONTAINER_CONTEXT_DIR)],
                "license_boundary": "Build fetches external source and Python packages; model weights are not copied into the image.",
                "image": container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""),
            },
        ))
    if container_runtime_path and container_image_ready:
        add_action(ctx, Action(
            "container.rebuild.local_toolchain",
            "Rebuild the local ComfyUI/TripoSR/Blender container image from the reviewed recipe.",
            True,
            details={
                "command": [container_runtime_path, "build", "-t", container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"), "-f", str(CONTAINERFILE), str(CONTAINER_CONTEXT_DIR)],
                "license_boundary": "Build fetches external source and Python packages; model weights are not copied into the image.",
                "image": container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""),
            },
        ))
        add_action(ctx, Action(
            "container.doctor",
            "Run the local toolchain container doctor probe.",
            True,
            details={"command": container_command(container_cfg, "doctor")},
        ))
        container_process = managed_process(CONTAINER_PROCESS_NAME)
        if container_process:
            add_action(ctx, Action("container.stop.comfyui", "Stop the ComfyUI container started by this utility.", True, details=container_process))
        else:
            add_action(ctx, Action(
                "container.start.comfyui",
                "Start ComfyUI from the local toolchain container.",
                True,
                details={"command": [*container_run_base(container_cfg), "-p", "8188:8188", container_cfg.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""), "comfyui-server"]},
            ))

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
    comfy_process = managed_process("comfyui")
    comfy_command = comfyui_start_command(ctx)
    if comfy_process:
        add_action(ctx, Action("stop.comfyui", "Stop the ComfyUI process started by this utility.", True, details=comfy_process))
    elif not ok and comfy_command:
        add_action(ctx, Action("start.comfyui", "Start the configured local ComfyUI server.", True, details={"command": comfy_command, "cwd": str(ctx.comfyui_root)}))

    helper = ctx.comfyui_root / "custom_nodes" / "character_turnaround_output.py" if ctx.comfyui_root else None
    if helper:
        if helper.exists():
            add_check(ctx, Check("comfyui.helper", "ok", "Build Me Godot custom-node helper installed on disk", details={"path": str(helper), "loaded": None if not ok else "checked below"}))
        else:
            add_check(ctx, Check("comfyui.helper", "missing", "Build Me Godot custom-node helper is not installed", details={"target": str(helper)}))
            add_action(ctx, Action("install.comfyui.helper", "Copy the Build Me Godot ComfyUI helper into custom_nodes.", True, details={"target": str(helper), "source": str(HELPER_SOURCE), "restart_required": True}))

    ok, object_info = http_json(ctx.comfyui_url.rstrip("/") + "/object_info")
    if ok:
        required_nodes = load_required_nodes()
        missing_nodes = [node for node in required_nodes if node not in object_info]
        ctx.missing_nodes = missing_nodes
        loaded_count = len(required_nodes) - len(missing_nodes)
        add_check(ctx, Check(
            "comfyui.nodes",
            "ok" if not missing_nodes else "missing",
            f"ComfyUI workflow nodes loaded: {loaded_count}/{len(required_nodes)}",
            details={"required": required_nodes, "missing": missing_nodes, "loaded_count": loaded_count},
        ))
        if helper and helper.exists() and any(node in HELPER_NODE_CLASSES for node in missing_nodes):
            add_action(ctx, Action(
                "refresh.comfyui.helper",
                "Refresh the Build Me Godot ComfyUI helper nodes, then restart ComfyUI.",
                True,
                details={
                    "target": str(helper),
                    "source": str(HELPER_SOURCE),
                    "missing_node_classes": [node for node in missing_nodes if node in HELPER_NODE_CLASSES],
                    "restart_required": True,
                },
            ))
    else:
        add_check(ctx, Check(
            "comfyui.nodes",
            "skip",
            "ComfyUI workflow nodes not yet verified; start ComfyUI and rerun",
            details=object_info,
        ))

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
        declared_model_count = len(load_model_artifacts())
        installed_model_count = declared_model_count - len(ctx.missing_models)
        add_check(ctx, Check(
            "comfyui.models",
            "ok" if not ctx.missing_models else "missing",
            f"ComfyUI model files installed: {installed_model_count}/{declared_model_count}",
            details={"missing": ctx.missing_models, "installed_count": installed_model_count, "declared_count": declared_model_count},
        ))
        if ctx.missing_models:
            add_action(ctx, Action("download.models", "Download missing reviewed model files into the staging directory.", True, details={"directory": str(ctx.model_download_dir), "models": ctx.missing_models}))
            staged = [row for row in ctx.missing_models if Path(row["staged_path"]).exists()]
            add_action(ctx, Action("move.models", "Move staged model files into the correct ComfyUI model directories.", True, ready=bool(staged), details={"staged_ready": staged, "requires_staged_files": True}))
    else:
        add_check(ctx, Check("comfyui.models", "skip", "ComfyUI model files require ComfyUI root", required=False))

    flowty_stage = ctx.model_download_dir / "comfyui_nodes" / FLOWTY_TRIPOSR_NODE["archive_name"]
    ctx.flowty_node_staged = flowty_stage if flowty_stage.exists() else None
    flowty_target = ctx.comfyui_root / "custom_nodes" / FLOWTY_TRIPOSR_NODE["target_dir_name"] if ctx.comfyui_root else None
    flowty_installed = bool(flowty_target and flowty_target.is_dir())
    add_check(ctx, Check(
        "comfyui.flowty_triposr.node",
        "ok" if flowty_installed else "missing",
        "ComfyUI Flowty TripoSR node installed" if flowty_installed else "ComfyUI Flowty TripoSR node not installed",
        required=False,
        details={
            "repository": FLOWTY_TRIPOSR_NODE["repository"],
            "license": FLOWTY_TRIPOSR_NODE["license"],
            "required_node_classes": FLOWTY_TRIPOSR_NODE["required_node_classes"],
            "target": str(flowty_target) if flowty_target else "",
            "staged_archive": str(flowty_stage),
            "staged": flowty_stage.exists(),
            "python_requirements_manual": True,
        },
    ))

    trellis_root_ok = is_trellis_root(ctx.trellis_root)
    trellis_model_ok = trellis_model_ready(ctx.trellis_model_path)
    add_check(ctx, Check(
        "trellis.root",
        "ok" if trellis_root_ok else "missing",
        f"TRELLIS checkout: {ctx.trellis_root}" if trellis_root_ok else "TRELLIS checkout not configured",
        required=False,
        details={
            "path": str(ctx.trellis_root) if ctx.trellis_root else "",
            "source": TRELLIS_SOURCE["url"],
            "license": TRELLIS_SOURCE["code_license"],
            "expected": "microsoft/TRELLIS checkout with trellis/pipelines",
            "automatic_install_allowed": False,
        },
    ))
    add_check(ctx, Check(
        "trellis.model",
        "ok" if trellis_model_ok else "missing",
        f"TRELLIS image model folder: {ctx.trellis_model_path}" if trellis_model_ok else "TRELLIS image model folder not configured",
        required=False,
        details={
            "path": str(ctx.trellis_model_path) if ctx.trellis_model_path else "",
            "source": TRELLIS_SOURCE["model_url"],
            "license": TRELLIS_SOURCE["weight_license"],
            "expected": "local microsoft/TRELLIS-image-large folder",
            "automatic_downloads_allowed": False,
        },
    ))
    trellis_provider_ok = trellis_root_ok and trellis_model_ok and TRELLIS_PROVIDER_WRAPPER.is_file()
    add_check(ctx, Check(
        "trellis.provider",
        "ok" if trellis_provider_ok else "missing",
        "TRELLIS provider wrapper is configured" if trellis_provider_ok else "TRELLIS provider wrapper is not ready",
        required=False,
        details={
            "wrapper": str(TRELLIS_PROVIDER_WRAPPER),
            "requirements": str(TRELLIS_REQUIREMENTS),
            "minimum_vram_gb": TRELLIS_SOURCE["minimum_vram_gb"],
            "output_formats": ["glb", "json"],
            "command": "bash utils/run-trellis.sh",
            "version_probe": "--version",
            "automatic_downloads_allowed": False,
        },
    ))
    if not trellis_provider_ok:
        add_action(ctx, Action(
            "manual.install.trellis.provider",
            "Configure user-managed TRELLIS for experimental local proxy reconstruction.",
            False,
            details={
                **TRELLIS_SOURCE,
                "requirements": str(TRELLIS_REQUIREMENTS),
                "wrapper": str(TRELLIS_PROVIDER_WRAPPER),
                "trellis_root": str(ctx.trellis_root) if ctx.trellis_root else "",
                "trellis_model_path": str(ctx.trellis_model_path) if ctx.trellis_model_path else "",
                "trellis_python": ctx.trellis_python,
                "commands": trellis_manual_commands(ctx),
                "configuration_keys": [
                    "BUILD_ME_GODOT_TRELLIS_ROOT",
                    "BUILD_ME_GODOT_TRELLIS_MODEL_PATH",
                    "BUILD_ME_GODOT_TRELLIS_PYTHON",
                    "BUILD_ME_GODOT_RECONSTRUCTION_COMMAND",
                ],
                "license_boundary": "Manual only: no repository clone, Python package install, or model download is performed by this setup action.",
            },
        ))

    ollama = command_path("ollama")
    ollama_ok, ollama_status = http_json(ctx.ollama_host.rstrip("/") + "/api/tags")
    add_check(ctx, Check("ollama.server", "ok" if ollama_ok else "skip", f"Ollama server at {ctx.ollama_host}", required=False, details={"response": "reachable" if ollama_ok else ollama_status}))
    ollama_process = managed_process("ollama")
    if ollama_process:
        add_action(ctx, Action("stop.ollama", "Stop the Ollama process started by this utility.", True, details=ollama_process))
    elif not ollama_ok and ollama and ctx.ollama_models:
        add_action(ctx, Action("start.ollama", "Start the local Ollama server.", True, details={"command": [ollama, "serve"]}))

    if ctx.ollama_models:
        add_check(ctx, Check("tool.ollama", "ok" if ollama else "missing", f"Ollama executable: {ollama or 'missing'}", required=False, details={"path": ollama}))
        if ollama:
            result = subprocess.run(["ollama", "list"], check=False, text=True, capture_output=True)
            installed = {line.split()[0] for line in result.stdout.splitlines()[1:] if line.split()}
            missing = [model for model in ctx.ollama_models if model not in installed]
            add_check(ctx, Check("ollama.models", "ok" if not missing else "missing", "Ollama requested models", required=False, details={"missing": missing}))
            for model in missing:
                add_action(ctx, Action(f"pull.ollama.{model}", f"Pull Ollama model {model}.", True, details={"model": model}))
    else:
        add_check(ctx, Check("ollama.models", "ok", "Ollama models: none required", required=False))

    triposr_model_dir = ctx.model_download_dir / "triposr"
    for artifact in TRIPOSR_MODEL_ARTIFACTS:
        staged = triposr_model_dir / artifact["value"]
        if not staged.exists():
            ctx.missing_triposr_models.append(artifact | {"staged_path": str(staged), "target_dir": str(triposr_model_dir)})
    installed_triposr_count = len(TRIPOSR_MODEL_ARTIFACTS) - len(ctx.missing_triposr_models)
    add_check(ctx, Check(
        "triposr.models",
        "ok" if not ctx.missing_triposr_models else "missing",
        f"TripoSR model files staged: {installed_triposr_count}/{len(TRIPOSR_MODEL_ARTIFACTS)}",
        required=False,
        details={
            "missing": ctx.missing_triposr_models,
            "staged_count": installed_triposr_count,
            "declared_count": len(TRIPOSR_MODEL_ARTIFACTS),
            "staging_dir": str(triposr_model_dir),
            "automatic_downloads_allowed": False,
        },
    ))
    if ctx.comfyui_root:
        checkpoint_dir = ctx.comfyui_root / "models" / "checkpoints"
        checkpoint_target = checkpoint_dir / "model.ckpt"
        staged_checkpoint = ctx.model_download_dir / "triposr" / "model.ckpt"
        checkpoint_ready = checkpoint_target.exists()
        add_check(ctx, Check(
            "comfyui.flowty_triposr.checkpoint",
            "ok" if checkpoint_ready else "missing",
            "TripoSR checkpoint available in ComfyUI checkpoints" if checkpoint_ready else "TripoSR checkpoint not found in ComfyUI checkpoints",
            required=False,
            details={
                "target": str(checkpoint_target),
                "staged_source": str(staged_checkpoint),
                "staged_source_exists": staged_checkpoint.exists(),
                "license": "MIT",
                "consumer": "ComfyUI-Flowty-TripoSR",
            },
        ))

    blender_process = managed_process("blender")
    if blender_process:
        add_action(ctx, Action("stop.blender", "Stop the Blender process started by this utility.", True, details=blender_process))
    elif blender:
        add_action(ctx, Action("start.blender", "Start Blender using the configured executable.", True, details={"command": [blender]}))

    check_example_project(ctx)

    if not ctx.config_path.exists():
        add_action(ctx, Action("write.local.config", "Write reusable gitignored local setup config.", True, details={"target": str(ctx.config_path)}))
    add_action(ctx, Action("open.comfy", "Print the configured ComfyUI URL for opening in a browser.", False, details={"url": ctx.comfyui_url}))


def check_example_project(ctx: Context) -> None:
    example = ctx.example_project
    addon_target = example / "addons" / "build_me_godot"
    expected_plugin = addon_target / "plugin.cfg"
    details = {
        "project": str(example),
        "target": str(addon_target),
        "source": str(ADDON_SOURCE),
        "expected_plugin": str(expected_plugin),
        "source_plugin": str(ADDON_SOURCE / "plugin.cfg"),
    }
    if not (example / "project.godot").exists():
        add_check(ctx, Check(
            "example.project",
            "skip",
            f"Companion example project not found: {example}",
            required=False,
            details=details,
        ))
        return

    if not (ADDON_SOURCE / "plugin.cfg").exists():
        details["source_valid"] = False
        add_check(ctx, Check("example.addon.symlink", "warning", "Build Me Godot addon package source is missing plugin.cfg", required=False, details=details))
        return

    if addon_target.is_symlink():
        actual = addon_target.resolve()
        details["actual"] = str(actual)
        details["actual_plugin"] = str(actual / "plugin.cfg")
        if actual == ADDON_SOURCE.resolve() and expected_plugin.exists():
            add_check(ctx, Check("example.addon.symlink", "ok", "Example project Build Me Godot addon symlink has correct package shape", required=False, details=details))
        else:
            add_check(ctx, Check("example.addon.symlink", "warning", "Example project addon symlink does not point to addons/build_me_godot with plugin.cfg", required=False, details=details))
            add_action(ctx, Action(
                "link.example.addon",
                "Replace the example project's Build Me Godot addon symlink with the addon package directory from this checkout.",
                True,
                details=details | {"replace_existing_symlink": True},
            ))
        return

    if addon_target.exists():
        add_check(ctx, Check("example.addon.symlink", "warning", "Example project addon path exists but is not a symlink", required=False, details=details))
        add_action(ctx, Action(
            "link.example.addon",
            "Create the example project Build Me Godot addon symlink to the addon package directory.",
            True,
            ready=False,
            details=details | {"blocked_by_existing_path": True},
        ))
        return

    add_check(ctx, Check("example.addon.symlink", "missing", "Example project Build Me Godot addon symlink", required=False, details=details))
    add_action(ctx, Action("link.example.addon", "Create the example project Build Me Godot addon symlink to the addon package directory.", True, details=details))


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
        f"BUILD_ME_GODOT_EXAMPLE_PROJECT={shell_value(str(ctx.example_project))}",
        f"BUILD_ME_GODOT_TRELLIS_ROOT={shell_value(str(ctx.trellis_root or ''))}",
        f"BUILD_ME_GODOT_TRELLIS_MODEL_PATH={shell_value(str(ctx.trellis_model_path or ''))}",
        f"BUILD_ME_GODOT_TRELLIS_PYTHON={shell_value(ctx.trellis_python)}",
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


def write_container_config(ctx: Context) -> Path:
    runtime = first_command(["podman", "docker", "apptainer"])
    if not runtime:
        raise SystemExit("No supported container runtime was found. Install Podman, Docker, or Apptainer first.")
    model_roots = [path for path in configured_model_roots(ctx) if path.exists()]
    if not model_roots:
        raise SystemExit("No existing model/cache roots were found to mount.")

    ctx.container_config_path.parent.mkdir(parents=True, exist_ok=True)
    nvidia_smi = command_path("nvidia-smi")
    content = "\n".join([
        "# Build Me Godot local container toolchain configuration.",
        "# This file is machine-local and intentionally gitignored.",
        "# It reuses user-owned model/cache folders instead of baking weights into images.",
        "",
        f"BUILD_ME_GODOT_CONTAINER_RUNTIME={shell_value(runtime[0])}",
        "BUILD_ME_GODOT_CONTAINER_IMAGE='localhost/build-me-godot-local-toolchain:dev'",
        f"BUILD_ME_GODOT_CONTAINER_PROJECT_ROOT={shell_value(str(PROJECT_ROOT))}",
        f"BUILD_ME_GODOT_CONTAINER_MODEL_ROOTS={shell_value(' '.join(str(path) for path in model_roots))}",
        f"BUILD_ME_GODOT_CONTAINER_COMFYUI_URL={shell_value(ctx.comfyui_url)}",
        f"BUILD_ME_GODOT_CONTAINER_GPU_ARGS={shell_value('--device nvidia.com/gpu=all --security-opt=label=disable' if nvidia_smi else '')}",
        f"BUILD_ME_GODOT_TRELLIS_ROOT={shell_value(str(ctx.trellis_root or ''))}",
        f"BUILD_ME_GODOT_TRELLIS_MODEL_PATH={shell_value(str(ctx.trellis_model_path or ''))}",
        f"BUILD_ME_GODOT_TRELLIS_PYTHON={shell_value(ctx.trellis_python)}",
        "",
        "# Suggested mounts:",
        "# project: read/write, so generated manifests and handoff reports remain in this checkout",
        "# models/custom_nodes/cache: mount existing user-owned folders; keep model weights outside the image",
        "# outputs: read/write, so ComfyUI and Blender job products survive container recreation",
        "",
    ])
    ctx.container_config_path.write_text(content, encoding="utf-8")
    ctx.changed_paths.append(str(ctx.container_config_path))
    return ctx.container_config_path


def format_bytes(value: int) -> str:
    amount = float(value)
    for unit in ["B", "KiB", "MiB", "GiB"]:
        if amount < 1024.0 or unit == "GiB":
            return f"{amount:.1f} {unit}" if unit != "B" else f"{int(amount)} B"
        amount /= 1024.0
    return f"{value} B"


class DownloadProgress:
    def __init__(self, label: str, enabled: bool) -> None:
        self.label = label
        self.enabled = enabled
        self.last_percent = -1
        self.last_bucket = -1
        self.finished = False

    def hook(self, block_count: int, block_size: int, total_size: int) -> None:
        if not self.enabled:
            return
        downloaded = block_count * block_size
        if total_size > 0:
            downloaded = min(downloaded, total_size)
            percent = int(downloaded * 100 / total_size)
            if percent == self.last_percent and percent < 100:
                return
            self.last_percent = percent
            width = 28
            filled = int(width * percent / 100)
            bar = "#" * filled + "-" * (width - filled)
            sys.stderr.write(
                f"\r  [{bar}] {percent:3d}% {format_bytes(downloaded)} / {format_bytes(total_size)} {self.label}"
            )
        else:
            bucket = downloaded // (1024 * 1024)
            if bucket == self.last_bucket:
                return
            self.last_bucket = bucket
            sys.stderr.write(f"\r  {format_bytes(downloaded)} downloaded {self.label}")
        sys.stderr.flush()

    def finish(self) -> None:
        if self.enabled and not self.finished:
            sys.stderr.write("\n")
            sys.stderr.flush()
        self.finished = True


def action_detail_lines(action: Action) -> list[str]:
    details = action.details
    if action.id.startswith("start."):
        return [f"Run in background: {shlex.join(details.get('command', []))}", f"Log: {RUNTIME_DIR / (action.id.removeprefix('start.') + '.log')}"]
    if action.id.startswith("stop."):
        return [f"Stop managed PID: {details.get('pid', '')}", "Processes not started by this utility are never stopped."]
    if action.id == "write.local.config":
        return [f"Write local setup config: {details.get('target', '')}"]
    if action.id == "write.container.config":
        lines = [
            f"Write local container config: {details.get('target', '')}",
            f"Runtime: {details.get('runtime', '')}",
            str(details.get("license_boundary", "")),
        ]
        roots = details.get("model_roots", [])
        if roots:
            lines.append("Existing model/cache roots to mount:")
            lines.extend(f"- {root}" for root in roots)
        if details.get("gpu_device_arg"):
            lines.append(f"GPU args: {details.get('gpu_device_arg', '')}")
        return lines
    if action.id == "manual.configure.nvidia.cdi":
        lines = [
            "Manual system remediation for NVIDIA CDI:",
            f"nvidia-smi: {details.get('nvidia_smi', '')}",
            f"nvidia-ctk: {details.get('nvidia_ctk', '') or 'missing'}",
            "Expected CDI spec paths:",
        ]
        lines.extend(f"- {path}" for path in details.get("expected_cdi_specs", []))
        lines.append("Suggested commands:")
        lines.extend(f"- {command}" for command in details.get("commands", []))
        lines.append(str(details.get("restart_note", "")))
        return lines
    if action.id == "manual.install.trellis.provider":
        lines = [
            "Manual TRELLIS provider setup:",
            f"source: {details.get('url', '')}",
            f"model: {details.get('model_url', '')}",
            f"code license: {details.get('code_license', '')}",
            f"weight license: {details.get('weight_license', '')}",
            f"minimum VRAM: {details.get('minimum_vram_gb', '')} GB",
            str(details.get("license_boundary", "")),
            "Suggested commands after review:",
        ]
        lines.extend(f"- {command}" for command in details.get("commands", []))
        return lines
    if action.id.startswith("container."):
        lines = [action.summary]
        command = details.get("command", [])
        if command:
            lines.append(f"Run: {shlex.join(command)}")
        if details.get("license_boundary"):
            lines.append(str(details.get("license_boundary")))
        return lines
    if action.id == "install.comfyui.helper":
        return [
            f"Copy: {details.get('source', '')}",
            f"Into: {details.get('target', '')}",
            "Restart ComfyUI after installation so the helper nodes are loaded.",
        ]
    if action.id == "refresh.comfyui.helper":
        lines = [
            f"Refresh: {details.get('source', '')}",
            f"Into: {details.get('target', '')}",
            "Restart ComfyUI after refresh so the helper nodes are loaded.",
        ]
        missing = details.get("missing_node_classes", [])
        if missing:
            lines.append(f"Missing helper classes: {', '.join(missing)}")
        return lines
    if action.id == "download.models":
        models = details.get("models", [])
        lines = [f"Download {len(models)} model file(s) into: {details.get('directory', '')}"]
        for row in models:
            lines.extend([
                f"- {row.get('value', '')}",
                f"  license: {row.get('license', '') or 'not declared'}",
                f"  source: {row.get('repository', '')}",
                f"  url: {row.get('url', '')}",
                f"  target after move: {row.get('target_dir', '')}",
            ])
        return lines
    if action.id == "move.models":
        staged = details.get("staged_ready", [])
        lines = [f"Move {len(staged)} staged model file(s) into ComfyUI model directories."]
        lines.extend(f"- {row.get('staged_path', '')} -> {row.get('target_dir', '')}" for row in staged)
        return lines
    if action.id == "link.example.addon":
        lines = [
            f"Example project: {details.get('project', '')}",
            f"Symlink path: {details.get('target', '')}",
            f"Symlink source: {details.get('source', '')}",
            f"Expected plugin: {details.get('expected_plugin', '')}",
        ]
        if details.get("replace_existing_symlink"):
            lines.append("Existing symlink will be replaced.")
        if details.get("blocked_by_existing_path"):
            lines.append("Blocked because the target path exists and is not a symlink.")
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


def execute_action(ctx: Context, action_id: str) -> None:
    def emit(message: str) -> None:
        if ctx.json_output:
            return
        stream = sys.stderr if ctx.json_output else sys.stdout
        print(message, file=stream)

    if action_id == "start.comfyui":
        command = comfyui_start_command(ctx)
        if command is None or ctx.comfyui_root is None:
            raise SystemExit("A ComfyUI root containing main.py is required.")
        pid, log = start_managed_process("comfyui", command, ctx.comfyui_root, "main.py")
        emit(f"Started ComfyUI (PID {pid}); log: {log}")
        if not wait_for_http(ctx.comfyui_url.rstrip("/") + "/system_stats", startup_timeout(30.0)):
            emit("ComfyUI is still starting; check the log or rerun the utility shortly.")
    elif action_id == "stop.comfyui":
        emit(f"Stopped managed ComfyUI process (PID {stop_managed_process('comfyui')}).")
    elif action_id == "start.ollama":
        ollama = command_path("ollama")
        if not ollama:
            raise SystemExit("Ollama executable was not found.")
        pid, log = start_managed_process("ollama", [ollama, "serve"], None, ollama)
        emit(f"Started Ollama (PID {pid}); log: {log}")
        if not wait_for_http(ctx.ollama_host.rstrip("/") + "/api/tags", startup_timeout(10.0)):
            emit("Ollama is still starting; check the log or rerun the utility shortly.")
    elif action_id == "stop.ollama":
        emit(f"Stopped managed Ollama process (PID {stop_managed_process('ollama')}).")
    elif action_id == "start.blender":
        blender = command_path(ctx.blender)
        if not blender:
            raise SystemExit("Blender executable was not found.")
        pid, log = start_managed_process("blender", [blender], None, blender)
        emit(f"Started Blender (PID {pid}); log: {log}")
    elif action_id == "stop.blender":
        emit(f"Stopped managed Blender process (PID {stop_managed_process('blender')}).")
    elif action_id == "write.local.config":
        path = write_config(ctx)
        emit(f"Wrote {path}")
    elif action_id == "write.container.config":
        path = write_container_config(ctx)
        emit(f"Wrote {path}")
    elif action_id == "manual.configure.nvidia.cdi":
        action = next((item for item in ctx.actions if item.id == action_id), None)
        if action is None:
            raise SystemExit("NVIDIA CDI remediation is not currently available.")
        for line in action_detail_lines(action):
            emit(line)
    elif action_id == "manual.install.trellis.provider":
        action = next((item for item in ctx.actions if item.id == action_id), None)
        if action is None:
            raise SystemExit("TRELLIS remediation is not currently available.")
        for line in action_detail_lines(action):
            emit(line)
    elif action_id in {"container.build.local_toolchain", "container.rebuild.local_toolchain"}:
        config = container_config(ctx)
        runtime = container_runtime_command(config)
        if not runtime:
            raise SystemExit("Configured container runtime was not found.")
        command = [runtime, "build", "-t", config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"), "-f", str(CONTAINERFILE), str(CONTAINER_CONTEXT_DIR)]
        try:
            subprocess.run(command, check=True)
        except subprocess.CalledProcessError as exc:
            raise SystemExit(f"Container image build failed with exit code {exc.returncode}: {shlex.join(command)}") from exc
        ctx.changed_paths.append(config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"))
    elif action_id == "container.doctor":
        config = container_config(ctx)
        subprocess.run(container_command(config, "doctor"), check=True)
    elif action_id == "container.start.comfyui":
        config = container_config(ctx)
        command = [*container_run_base(config), "-p", "8188:8188", config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""), "comfyui-server"]
        pid, log = start_managed_process(CONTAINER_PROCESS_NAME, command, PROJECT_ROOT, config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""))
        emit(f"Started ComfyUI container (PID {pid}); log: {log}")
    elif action_id == "container.stop.comfyui":
        emit(f"Stopped managed ComfyUI container process (PID {stop_managed_process(CONTAINER_PROCESS_NAME)}).")
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
    elif action_id == "refresh.comfyui.helper":
        if not ctx.comfyui_root:
            raise SystemExit("ComfyUI root is required.")
        target = ctx.comfyui_root / "custom_nodes" / "character_turnaround_output.py"
        if not target.exists():
            raise SystemExit(f"Helper is not installed yet: {target}")
        shutil.copy2(HELPER_SOURCE, target)
        ctx.changed_paths.append(str(target))
        emit(f"Refreshed helper: {target}")
        emit("Restart ComfyUI before rechecking nodes.")
    elif action_id == "download.models":
        ctx.model_download_dir.mkdir(parents=True, exist_ok=True)
        for row in ctx.missing_models:
            target = Path(row["staged_path"])
            partial = target.with_name(target.name + ".part")
            if target.exists():
                emit(f"Already staged: {target}")
                continue
            if partial.exists():
                partial.unlink()
            emit(f"Downloading {row['value']}")
            progress = DownloadProgress(row["value"], enabled=not ctx.json_output and sys.stderr.isatty())
            try:
                urllib.request.urlretrieve(row["url"], partial, progress.hook)
                partial.replace(target)
            except BaseException:
                if partial.exists():
                    partial.unlink()
                    emit(f"Removed partial download: {partial}")
                raise
            finally:
                progress.finish()
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
    elif action_id == "link.example.addon":
        example = ctx.example_project
        if not (example / "project.godot").exists():
            raise SystemExit(f"Example project not found: {example}")
        if not (ADDON_SOURCE / "plugin.cfg").exists():
            raise SystemExit(f"Addon package source is missing plugin.cfg: {ADDON_SOURCE}")
        target = example / "addons" / "build_me_godot"
        if target.exists() or target.is_symlink():
            if not target.is_symlink():
                raise SystemExit(f"Refusing to overwrite non-symlink path: {target}")
            if target.resolve() == ADDON_SOURCE.resolve():
                if (target / "plugin.cfg").exists():
                    emit(f"Already linked: {target} -> {ADDON_SOURCE}")
                    return
                raise SystemExit(f"Existing addon symlink does not expose plugin.cfg at expected path: {target / 'plugin.cfg'}")
            target.unlink()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(ADDON_SOURCE)
        if not (target / "plugin.cfg").exists():
            target.unlink()
            raise SystemExit(f"Created symlink did not expose plugin.cfg at expected path: {target / 'plugin.cfg'}")
        ctx.changed_paths.append(str(target))
        emit(f"Linked {target} -> {ADDON_SOURCE}")
    elif action_id.startswith("pull.ollama."):
        model = action_id.removeprefix("pull.ollama.")
        subprocess.run(["ollama", "pull", model], check=True)
    elif action_id == "open.comfy":
        emit(ctx.comfyui_url)
    else:
        raise SystemExit(f"Action is not implemented: {action_id}")


def apply_action(ctx: Context, action_id: str) -> None:
    reset_results(ctx)
    run_checks(ctx)
    actions = {action.id: action for action in ctx.actions}
    if action_id == "write.local.config" and action_id not in actions:
        action = Action("write.local.config", "Rewrite reusable gitignored local setup config.", True, details={"target": str(ctx.config_path)})
        actions[action_id] = action
        ctx.actions.append(action)
    if action_id == "write.container.config" and action_id not in actions:
        action = Action("write.container.config", "Rewrite reusable gitignored container toolchain env file.", True, details={"target": str(ctx.container_config_path)})
        actions[action_id] = action
        ctx.actions.append(action)
    if action_id in {"container.build.local_toolchain", "container.rebuild.local_toolchain"} and action_id not in actions:
        config = container_config(ctx)
        runtime = container_runtime_command(config)
        if runtime and CONTAINERFILE.is_file():
            action = Action(action_id, "Build the local ComfyUI/TripoSR/Blender container image from the reviewed recipe.", True, details={
                "command": [runtime, "build", "-t", config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", "localhost/build-me-godot-local-toolchain:dev"), "-f", str(CONTAINERFILE), str(CONTAINER_CONTEXT_DIR)],
                "license_boundary": "Build fetches external source and Python packages; model weights are not copied into the image.",
                "image": config.get("BUILD_ME_GODOT_CONTAINER_IMAGE", ""),
            })
            actions[action_id] = action
            ctx.actions.append(action)
    if action_id not in actions:
        raise SystemExit(f"Unknown or unavailable action: {action_id}")
    action = actions[action_id]
    if not action.ready:
        raise SystemExit(f"Action is not ready: {action_id}")
    confirm_action(ctx, action)
    execute_action(ctx, action_id)


def report(ctx: Context) -> dict[str, Any]:
    ready = all(check.status == "ok" for check in ctx.checks if check.required)
    return {
        "schema_version": 1,
        "ready": ready,
        "project_root": str(PROJECT_ROOT),
        "config_path": str(ctx.config_path),
        "container_config_path": str(ctx.container_config_path),
        "comfyui_url": ctx.comfyui_url,
        "comfyui_root": str(ctx.comfyui_root) if ctx.comfyui_root else "",
        "model_download_dir": str(ctx.model_download_dir),
        "example_project": str(ctx.example_project),
        "checks": [check.__dict__ for check in ctx.checks],
        "actions": [action.__dict__ for action in ctx.actions],
        "changed_paths": ctx.changed_paths,
    }


def print_human(ctx: Context, include_actions: bool) -> None:
    print_review(ctx)
    if include_actions:
        print("\nAvailable actions:")
        for action in ctx.actions:
            marker = "ready" if action.ready else "blocked"
            print(f"- {action.id} [{marker}]: {action.summary}")
    if ctx.missing_models:
        print("\nModel download commands:")
        for row in ctx.missing_models:
            print(f"curl --location --fail --continue-at - --output './{row['value']}' '{row['url']}'")


def print_review(ctx: Context) -> None:
    helper_actions = [action for action in ctx.actions if action.id in {"install.comfyui.helper", "refresh.comfyui.helper"}]
    if helper_actions or ctx.missing_nodes:
        print("\nCustom node review:")
    for action in helper_actions:
        label = "Build Me Godot helper install" if action.id == "install.comfyui.helper" else "Build Me Godot helper refresh"
        print(f"- {label}:")
        print(f"  source: {action.details.get('source', '')}")
        print(f"  target: {action.details.get('target', '')}")
        print("  restart required: yes")
        missing = action.details.get("missing_node_classes", [])
        if missing:
            print(f"  missing helper classes: {', '.join(missing)}")
    if ctx.missing_nodes:
        print("- Missing workflow node classes:")
        for node in ctx.missing_nodes:
            print(f"  - {node}")
        print("- If the Build Me Godot helper was just installed, restart ComfyUI and recheck.")
        print("- Other missing classes must be reviewed and installed explicitly in ComfyUI.")

    if ctx.missing_models:
        print("\nModel download review:")
        for row in ctx.missing_models:
            print(f"- {row['value']}")
            print(f"  license: {row.get('license') or 'not declared'}")
            print(f"  source: {row.get('repository') or 'not declared'}")
            print(f"  url: {row['url']}")
            print(f"  staging: {row['staged_path']}")
            print(f"  target after move: {row['target_dir']}")
    if ctx.missing_triposr_models:
        print("\nTripoSR model reuse review:")
        for row in ctx.missing_triposr_models:
            print(f"- {row['value']}")
            print(f"  license: {row.get('license') or 'not declared'}")
            print(f"  source: {row.get('repository') or 'not declared'}@{row.get('revision') or 'not declared'}")
            print(f"  expected local path: {row['staged_path']}")
        print("- The setup app no longer downloads these files; reuse existing user-owned files or mount them into the container toolchain.")


def print_setup_guidance(ctx: Context) -> None:
    print("\nSetup assistant:")
    print("- Details: ./utils/check-local-requirements.sh doctor")
    print("- Help: ./utils/check-local-requirements.sh --help")
    print("\nAGENT HANDOFF:")
    print("  Ask an agent to run: ./utils/check-local-requirements.sh plan --json")
    print("  Then approve specific: ./utils/check-local-requirements.sh apply <action_id> --yes --json")

    print_review(ctx)

    ready_actions = [action for action in ctx.actions if action.mutates and action.ready]
    blocked_actions = [action for action in ctx.actions if action.mutates and not action.ready]
    if ready_actions:
        print("\nReady setup actions:")
        for action in ready_actions:
            print(f"- {action.id}: {action.summary}")
    if blocked_actions:
        print("\nBlocked setup actions:")
        for action in blocked_actions:
            print(f"- {action.id}: {action.summary}")
    print_manual_remediations(ctx)


def print_optional_container_actions(ctx: Context) -> None:
    container_actions = [action for action in ctx.actions if action.id.startswith("container.") and action.ready]
    if container_actions:
        print("\nOptional container actions:")
        for action in container_actions:
            print(f"- {action.id}: {action.summary}")


def print_manual_remediations(ctx: Context) -> None:
    manual_actions = [action for action in ctx.actions if not action.mutates and action.id.startswith("manual.")]
    if manual_actions:
        print("\nManual remediation actions:")
        for action in manual_actions:
            print(f"- {action.id}: {action.summary}")
            if action.id == "manual.configure.nvidia.cdi":
                if not action.details.get("nvidia_ctk", ""):
                    package_manager = action.details.get("package_manager", "")
                    suffix = f" with `{package_manager}`" if package_manager else ""
                    print(f"  First: install NVIDIA Container Toolkit{suffix} so `nvidia-ctk` is available.")
                    toolkit_commands = action.details.get("toolkit_install_commands", [])
                    if toolkit_commands:
                        print("  Install commands:")
                        for command in toolkit_commands:
                            print(f"    {command}")
                print("  Details: ./utils/check-local-requirements.sh apply manual.configure.nvidia.cdi --non-interactive")


def run_guided_setup(ctx: Context) -> None:
    run_checks(ctx)
    if ctx.json_output:
        return
    if report(ctx)["ready"]:
        print_ready_message()
        print_optional_container_actions(ctx)
        print_manual_remediations(ctx)
        return
    print_setup_guidance(ctx)
    if ctx.non_interactive or not sys.stdin.isatty():
        return

    ready_actions = [action for action in ctx.actions if _is_guided_action(ctx, action)]
    if not ready_actions:
        return

    applied: set[str] = set()
    while True:
        progress = False
        for action in list(ctx.actions):
            if not _is_guided_action(ctx, action) or action.id in applied:
                continue
            try:
                confirm_action(ctx, action)
            except SystemExit as exc:
                if str(exc) != "Cancelled.":
                    raise
                print(f"Skipped {action.id}.")
                applied.add(action.id)
                progress = True
                break
            execute_action(ctx, action.id)
            applied.add(action.id)
            progress = True
            reset_results(ctx)
            ctx.quiet_checks = True
            run_checks(ctx)
            ctx.quiet_checks = False
            break
        if not progress:
            break
    if report(ctx)["ready"]:
        print_ready_message()
        print_optional_container_actions(ctx)


def print_ready_message() -> None:
    print("\n✓ Build Me Godot is installed and ready.")
    print("  Open your Godot project and enable the Build Me Godot addon.")


def _is_guided_action(ctx: Context, action: Action) -> bool:
    if not action.mutates or not action.ready or action.id.startswith("stop."):
        return False
    if action.id.startswith("container."):
        return False
    if action.id == "start.blender":
        return False
    if action.id == "start.ollama" and not ctx.ollama_models:
        return False
    return True


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Build Me Godot local setup assistant.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Common flows:
  setup                     Default guided setup for humans; asks before each action.
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
    parser.add_argument("command", nargs="?", default="setup", choices=["setup", "check", "plan", "doctor", "apply", "write-config", "open-comfy"], help="Command to run.")
    parser.add_argument("action_id", nargs="?", help="Action ID for apply.")
    parser.add_argument("--config")
    parser.add_argument("--comfyui-url")
    parser.add_argument("--comfyui-root")
    parser.add_argument("--blender")
    parser.add_argument("--model-download-dir")
    parser.add_argument("--example-project")
    parser.add_argument("--container-config")
    parser.add_argument("--trellis-root")
    parser.add_argument("--trellis-model-path")
    parser.add_argument("--trellis-python")
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
        action = actions.get("write.local.config", Action("write.local.config", "Rewrite reusable gitignored local setup config.", True, details={"target": str(ctx.config_path)}))
        confirm_action(ctx, action)
        path = write_config(ctx)
        if not args.json:
            print(f"Wrote {path}")
    elif args.command == "open-comfy":
        if not args.json:
            print(ctx.comfyui_url)
    else:
        if args.command == "setup":
            run_guided_setup(ctx)
        else:
            run_checks(ctx)
            if not args.json:
                if args.command in {"plan", "doctor"}:
                    print_human(ctx, include_actions=True)
                elif args.command == "check":
                    print_human(ctx, include_actions=False)

    data = report(ctx)
    if args.json:
        print(json.dumps(data, indent=2, sort_keys=True))
    if args.command in {"apply", "write-config", "open-comfy"}:
        return 0
    return 0 if data["ready"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("\nCancelled.", file=sys.stderr)
        raise SystemExit(130)
