# Build Me Godot Local Toolchain Container

This container is an optional local runtime for ComfyUI, TripoSR proxy
generation, and headless Blender jobs. It intentionally does not include model
weights or project outputs. Mount existing user-owned model/cache folders from
`utils/check-local-container.local.env`.

Modes:

- `doctor`: read-only runtime probe.
- `comfyui-server`: run ComfyUI on `0.0.0.0:8188`.
- `triposr-job`: run the provider command contract with `--input`, `--output`,
  and `--metadata-output`.
- `blender-job`: run Blender headlessly with pass-through arguments.

The image recipe fetches ComfyUI and TripoSR source at build time. Do not
distribute built images until GPL-3.0 and third-party source obligations have
been reviewed for that release.

The base image uses the CUDA `devel` variant because TripoSR dependencies build
native CUDA/PyTorch extension wheels during `pip install`. Model weights are
still host-mounted and are not copied into the image.

ComfyUI and TripoSR install into separate Python virtual environments. This
prevents TripoSR's pinned dependencies from downgrading packages required by
current ComfyUI workflows.

The TripoSR environment intentionally omits the upstream Gradio demo dependency.
Build Me Godot uses TripoSR through `triposr-job`, not the TripoSR web UI, and
skipping Gradio avoids unnecessary resolver churn and ComfyUI package conflicts.
