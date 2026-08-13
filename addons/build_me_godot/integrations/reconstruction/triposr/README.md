# TripoSR external reconstruction adapter

This optional adapter invokes a user-managed local TripoSR checkout. It does
not download weights at generation time, clone repositories, install Python
packages, or modify ComfyUI/system Python. The repository setup utility detects
expected local TripoSR model paths, but it no longer downloads or installs
`config.yaml`, `model.ckpt`, or reconstruction runtime files. Reuse existing
user-owned model files directly or mount them into the local container
toolchain.

When ComfyUI is the orchestration surface, prefer the external
`flowtyone/ComfyUI-Flowty-TripoSR` node before writing a custom wrapper. The
setup utility detects an already installed native node, but does not stage or
install the GPL-3.0 node archive. The node code remains external and is not
bundled with Build Me Godot. Prefer the container toolchain when the runtime
dependencies are not already available in the user's ComfyUI environment.

Validated source and weight combination:

- Code: `VAST-AI-Research/TripoSR` commit `107cefdc244c39106fa830359024f6a2f1c78871`, MIT
- Weights: `stabilityai/TripoSR` revision `5b521936b01fbe1890f6f9baed0254ab6351c04a`, MIT
- Model SHA-256 observed during validation: `429e2c6b22a0923967459de24d67f05962b235f79cde6b032aa7ed2ffcd970ee`

TripoSR is a single-image reconstructor. Passing several sources produces independent candidates; it does not jointly condition on a turnaround. Compare front and front-three-quarter candidates and retain provenance rather than claiming multiview reconstruction.

Use an isolated environment compatible with the machine's GPU. On the validated AMD ROCm workstation, apply `requirements/rocm-isosurface.patch` to the pinned checkout and install `requirements/rocm-direct.txt` into that environment. The patch moves marching cubes to CPU because upstream `torchmcubes` assumes CUDA; neural inference remains on ROCm.

```sh
python split_turnaround.py turnaround_sheet.png work/views
python prepare_input.py work/views/front.png work/views/front_3q.png --output-dir work/reconstruction
python run_triposr.py work/reconstruction/front_tripo.png \
  --repo /path/to/TripoSR --output-dir work/generated/front --mc-resolution 256
```

The generated GLB remains an immutable reference/proxy, not production topology.
