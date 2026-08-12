# Godot Asset Store listing draft

## Build Me Godot

Build Me Godot is a local-first Godot 4 editor addon for repeatable AI-assisted game-character production. Artists save versioned character prompts in the project, queue packaged ComfyUI canonical and multiview workflows, and hand resulting assets to a declared Blender humanoid-build pipeline. Human-readable setup checks and a deterministic JSON CLI help artists, CI, and coding agents reproduce the environment safely.

### Features

- Project-owned, versioned character manifests and editable prompts
- Packaged ComfyUI workflow JSON for canonical and consistent multiview images
- Explicit local ComfyUI queueing with no hosted inference dependency
- Machine-readable workflow and Blender compatibility declarations
- Blender proxy, standard humanoid rig, animation-library, and GLB build scripts
- Capability-specific environment checks, redacted support reports, and agent-friendly exit codes
- Read-only installation plans and narrowly scoped, explicit safe actions
- Optional detection and acknowledgement of Gator Model Studio for in-Godot last-mile refinement

### Requirements

- Godot 4.x
- A separately installed local ComfyUI and explicitly installed, license-compatible model weights for image stages
- Blender 4.2+ for the humanoid builder
- A separately obtained commercially usable reconstruction provider and animation asset for those stages

The addon does not bundle model weights, Blender, ComfyUI, reconstruction providers, animation libraries, or Gator Model Studio. Enabling it does not download packages, contact hosted inference services, or modify external installations.

Runnable example project: https://github.com/VerdantAI/godot-addons-example-project. The example is a separate consumer project, not part of the addon package.

### Important limitation

Generated reconstruction geometry is an immutable reference/proxy. Automated decimation, fitting, and weights do not create production-ready deformation topology; artists must inspect and refine topology, weights, equipment, materials, and animations before shipping.

License: MIT. External component licenses and rejected dependencies are documented in `LICENSES.md`; acknowledgements are in `ATTRIBUTIONS.md`.
