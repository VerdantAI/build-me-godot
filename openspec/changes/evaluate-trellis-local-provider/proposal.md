## Why

TripoSR produced poor proxy meshes for the field-engineer references. TRELLIS
is the next local image-to-3D candidate because the original Microsoft TRELLIS
repo and image model are MIT, can export GLB meshes, and are designed for
image-conditioned reconstruction. It still needs a strict local-provider
boundary because its setup compiles CUDA submodules and its model files live
outside this addon.

## What Changes

- Promote original TRELLIS from candidate-only documentation to an
  experimental user-managed proxy provider.
- Add packaged provider requirements and command-contract metadata.
- Add a local wrapper that runs only against a configured TRELLIS checkout and
  local model folder, with Hugging Face offline mode enabled by default.
- Update setup/install utilities to detect TRELLIS root/model readiness and
  provide manual remediation instead of cloning repos, installing Python
  packages, or downloading weights.
- Keep TRELLIS outputs as immutable proxy references only.

## Out Of Scope

- TRELLIS.2 is not promoted in this slice because the current best wrappers
  depend on additional CUDA/rendering packages whose licenses must be reviewed
  separately.
- No automatic model download, Python package install, ComfyUI custom-node
  install, or container image rebuild is added.
