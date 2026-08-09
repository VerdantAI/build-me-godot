# TripoSR external reconstruction adapter

This optional adapter invokes a user-managed local TripoSR checkout. It does not download weights, clone repositories, install Python packages, or modify ComfyUI/system Python.

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
