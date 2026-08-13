## Summary

Add an optional local container toolchain for ComfyUI, local TripoSR proxy
reconstruction, and headless Blender automation. The container path shall reuse
model weights and creative outputs that already exist on the user's machine by
mounting host directories, not by baking weights into images.

## Motivation

The local TripoSR path introduces Python dependency risk inside the user's
existing ComfyUI virtual environment. A reviewed container path provides a
cleaner boundary for PyTorch/CUDA/ROCm, custom-node dependencies, and Blender
headless execution while preserving the addon policy that downloads and
external mutations are explicit user actions.

## Scope

- Detect Podman, Docker, and Apptainer availability without mutation.
- Prefer Podman-compatible OCI workflows on Linux, with Docker-compatible
  commands where possible and Apptainer documented for environments that favor
  SIF/HPC-style execution.
- Detect NVIDIA CDI readiness when NVIDIA GPUs are present.
- Write a gitignored local container env file with project, model, custom-node,
  output, and cache mounts.
- Define a future image contract with separate modes for ComfyUI server,
  TripoSR proxy jobs, Blender jobs, and smoke tests.

## Out of Scope

- Building, pulling, or running a container image by default.
- Baking ComfyUI model weights, TripoSR checkpoints, Ollama models, generated
  references, or project outputs into a distributed image.
- Installing GPU drivers, Python packages, ComfyUI nodes, Blender extensions, or
  system packages automatically.
- Replacing the existing non-container local setup path.
