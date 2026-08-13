## Runtime Choice

Use an OCI image contract as the primary implementation target. The setup app
should prefer Podman on Linux because it supports rootless operation and can
consume NVIDIA CDI device declarations. Docker remains a compatible fallback
because many users already have Docker Compose GPU support configured.
Apptainer is a documented alternate runtime for machines where users prefer
single-file images or HPC-style execution, but it should not be the first build
target for the repository helper.

## GPU Best Practices

For NVIDIA machines, prefer Container Device Interface (CDI) when available.
NVIDIA documents CDI as a runtime-agnostic GPU device abstraction, and Podman
can request all NVIDIA GPUs with `--device nvidia.com/gpu=all`. Docker Compose
also supports GPU reservations through service device declarations and newer
Compose `gpus` syntax. The setup utility should detect CDI specs and surface
the exact next operator action instead of trying to install GPU tooling.

AMD/ROCm support should be modeled separately once tested. The first
implementation may report it as unknown rather than claiming support.

## Image Modes

The eventual image should support distinct entry modes:

- `comfyui-server`: long-running ComfyUI API/UI service on port 8188.
- `triposr-job`: one-shot proxy reconstruction job that accepts input image,
  output mesh, metadata output, and provider ID.
- `blender-job`: one-shot headless Blender run for conformance handoff,
  validation, and export scripts.
- `doctor`: read-only runtime probe for GPU, Python packages, ComfyUI nodes,
  Blender executable, and mounted paths.

The image may contain reviewed source code and Python packages. It must not
contain default model weights, generated character references, user prompts, or
project outputs.

## Mount Strategy

The container config should mount:

- the project checkout read/write, so Godot manifests and reports stay in
  `res://build_me_godot/`;
- existing ComfyUI model folders, preferably read-only when running generation;
- existing ComfyUI custom-node folders when the user wants to reuse already
  installed nodes;
- ComfyUI output and temp/cache directories read/write;
- the model staging directory read/write for explicitly downloaded artifacts;
- Ollama model caches read-only for analysis jobs if mounted into a compatible
  service.

This keeps expensive downloads reusable across native and container execution
and makes container recreation low risk.

## License Boundary

The repository may ship container recipes and helper scripts, but distributed
images require a separate release review because ComfyUI and Flowty TripoSR are
GPL-3.0 external dependencies. The default local image recipe shall avoid
embedding model weights. Any action that pulls source, installs GPL code, or
downloads model artifacts must display license notices and require explicit
user approval.

## Current Implementation Slice

The first implementation adds read-only runtime/GPU/mount checks, an explicit
`write.container.config` setup action, a reviewed local toolchain container
recipe, and opt-in `container.*` actions for build, doctor, start, and stop.
The setup assistant must not build or run the image during guided setup; those
actions remain explicit operator choices.
