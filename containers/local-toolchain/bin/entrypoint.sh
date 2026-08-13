#!/usr/bin/env bash
set -euo pipefail

mode="${1:-doctor}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

case "$mode" in
  doctor)
    exec "${COMFYUI_PYTHON:-python3}" /opt/build-me-godot/bin/doctor.py "$@"
    ;;
  comfyui-server)
    cd "${COMFYUI_ROOT:-/opt/ComfyUI}"
    exec "${COMFYUI_PYTHON:-python3}" main.py --listen 0.0.0.0 --port "${COMFYUI_PORT:-8188}" "$@"
    ;;
  triposr-job)
    exec "${TRIPOSR_PYTHON:-python3}" /opt/build-me-godot/bin/triposr_job.py "$@"
    ;;
  blender-job)
    exec "${COMFYUI_PYTHON:-python3}" /opt/build-me-godot/bin/blender_job.py "$@"
    ;;
  *)
    echo "Unknown Build Me Godot container mode: $mode" >&2
    exit 2
    ;;
esac
