# Build Me Godot

An opinionated AI workflow addon for Godot 4 that orchestrates [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [Blender](https://www.blender.org/), and Godot to streamline character and asset creation for game development.

## Features

- Integrates ComfyUI image generation pipelines directly into the Godot editor workflow.
- Automates Blender asset processing (rigging, LOD generation, export) via scripted pipelines.
- Imports and organizes generated assets into your Godot project.
- Provides an opinionated, end-to-end workflow from concept art to game-ready characters.

## Requirements

- Godot 4.x
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) running locally or on a reachable server.
- [Blender](https://www.blender.org/) 4.2 or newer installed and accessible from the command line.

## Installation

1. Copy the `addons/build_me_godot` folder into your Godot project's `addons/` directory.
2. In the Godot editor, open **Project → Project Settings → Plugins** and enable **Build Me Godot**.

Alternatively, install it from the [Godot Asset Store](https://store.godotengine.org/) when a release is available.

The addon stores character manifests and generated work under `res://build_me_godot/`, outside the addon directory. Updating or removing the addon does not remove that project data. External dependencies are detected but never installed automatically.

Machine configuration resolves from CLI overrides, `BUILD_ME_GODOT_*` environment variables, `res://build_me_godot.local.cfg`, global Editor Settings, then packaged defaults. The local file is gitignored and readable headlessly. Copy [the example](build_me_godot.local.cfg.example) to the project root or create it with **Save for this project** in the dock; **Save for me** writes global editor defaults.

## Example project

For a runnable consumer-project setup, use the companion [godot-addons-example-project](https://github.com/VerdantAI/godot-addons-example-project). It is separate from the Asset Store addon package and is the right place for project-specific sample scenes, character manifests, and end-to-end manual workflow checks.

The addon package remains self-contained under `addons/build_me_godot/`. Project-owned data belongs under each game's `res://build_me_godot/`.

## Character workflow

Build Me Godot is driven from the target Godot project. Open the dock, create or select a character, confirm the two rigged mesh inputs, enter character metadata and prompts, then queue a local ComfyUI reference run. Runs are stored as sequential `v1`, `v2`, and later versions in `res://build_me_godot/characters/<character_id>/character.json`.

The setup tab shows colored local status indicators for ComfyUI found/running, ComfyUI nodes/models, Blender, Ollama, animation assets, and the base character scene. The scene field defaults to the packaged onboarding scene at `res://addons/build_me_godot/examples/base_characters.tscn`; use **Load base character scene** to inspect the two CC0 rigged Quaternius mannequins and their shared animation library before replacing them with project-specific rigged meshes. This is separate from the project's normal `main.tscn` entry scene.

After reviewing generated references, approve one completed version and explicitly continue the pipeline. Continuation writes `res://build_me_godot/characters/<character_id>/blender/<version>/reference_inputs.json` and `mesh_guidance.json` for the Blender stage, then advances the manifest to `pipeline_enabled`. Final character scenes, animations, and secondary assets are registered back into the same manifest when downstream work completes.

For field-engineer characters, an approved reference can also prepare a
non-destructive conformance plan under
`res://build_me_godot/characters/<character_id>/conformance/<version>/`.
The plan records source references, rigged meshes, TripoSR/manual proxy
provenance, high-visibility workwear targets, material/color targets, prop
socket candidates, and validation constraints. Generated or reconstructed
meshes are immutable references; they are not production topology.

Prompts are project data owned by Godot, not by the ComfyUI editor. You can still tune in ComfyUI: export the workflow JSON, import its prompt fields back into the dock or CLI, save the character draft, then queue from Godot. Queued runs record the ComfyUI `prompt_id` when available and save the configured API workflow snapshot under `res://build_me_godot/characters/<character_id>/workflows/<version>_api.json` for later agent or headless replay.

For agent or CI use, the addon exposes deterministic JSON commands:

```bash
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- import-workflow --character-id field_engineer --workflow-path res://addons/build_me_godot/workflows/character_turnaround_open.json
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- inspect --character-id field_engineer
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- queue --character-id field_engineer --workflow-path res://addons/build_me_godot/workflows/canonical_only_api.json
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- approve --character-id field_engineer --version v1
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- prepare-conformance --character-id field_engineer --version v1
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- generate-proxy --character-id field_engineer --version v1 --provider triposr
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- inspect-conformance --character-id field_engineer --version v1
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- continue --character-id field_engineer --version v1
```

With `--no-header`, these commands write only project-local manifest and handoff files and emit JSON on stdout. They do not install external tools, download model weights, run Blender, or launch unrelated stages.

## Optional last-mile editing

[Gator Model Studio](https://store.godotengine.org/asset/blackwater-gator-studios/gator-model-studio/) by Blackwater Gator Studios can provide an in-Godot last-mile refinement path for generated meshes, UVs, materials, rigs, weights, animations, and collisions. It is an optional, independently installed addon and is not redistributed by Build Me Godot. Blender remains the default automated processing path.

See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for reviewed dependency and license information.

See [LICENSES.md](LICENSES.md) before installing model weights or adding another reconstruction, rigging, animation, or refinement provider.

See [Installation and environment checks](docs/environment-checks.md) for the editor workflow and deterministic agent/CLI interface.
See [Agent setup guide](docs/agent-setup.md) for safe, copyable automation prompts and commands.
See [Developer handoff](docs/handoff.md) for repository boundaries, current capabilities, and the next independent milestones.

See [Store listing](docs/store-listing.md) for distribution copy and [Release checklist](docs/release-checklist.md) for the publishing gate.

The optional [TripoSR adapter](integrations/reconstruction/triposr/README.md)
supports user-managed local reconstruction. Because ComfyUI is already part of
the Build Me Godot stack, the preferred local path is the external
`flowtyone/ComfyUI-Flowty-TripoSR` node when it is already installed or
provided by the local container toolchain. The setup utility detects native
Flowty/TripoSR availability, but does not download the GPL node, install
Python packages, download TripoSR weights, or copy checkpoints into ComfyUI. A
direct `BUILD_ME_GODOT_RECONSTRUCTION_COMMAND` wrapper remains available as a
fallback when the Comfy node path is not suitable.

The optional TRELLIS path is experimental and intended for evaluating better
local proxy meshes when TripoSR output is not useful. It requires a
user-installed `microsoft/TRELLIS` checkout, a local
`microsoft/TRELLIS-image-large` model folder, and a CUDA-compatible Python
environment. Configure `BUILD_ME_GODOT_TRELLIS_ROOT`,
`BUILD_ME_GODOT_TRELLIS_MODEL_PATH`, optionally
`BUILD_ME_GODOT_TRELLIS_PYTHON`, then use `bash utils/run-trellis.sh` as the
reconstruction command in this development repository. The wrapper runs Hugging
Face in offline mode by default and never downloads weights automatically.

Ollama can help with optional vision-language review of references and target
JSON, but it is not used as the TripoSR wrapper. Ollama's supported model
surface is LLM/vision inference, not arbitrary image-to-3D reconstruction
execution.

Field-engineer image-to-mesh best practices: use a clean front view and
matching side/back references, keep the full body centered, normalize alpha or
background before reconstruction, avoid occluded tools and cropped feet, keep
view labels stable, prompt explicit safety workwear, and retain artist review
before any downstream mesh edits.

Rigging smoke tests bind generated proxy meshes to the local Quaternius
humanoid rig only to prove GLB import, skinning, deformation, and animation
export. The generated `Rig_Test` action is a deliberately small shoulder/limb
motion; it is not a walk cycle. Full locomotion exposed donor-weight artifacts
on generated clothing and accessories, so production use still requires better
weights, accessory separation, or an AI rigger such as a separately reviewed
Make-It-Animatable/UniRig setup.

The packaged Blender handoff command
`integrations/blender/prepare_conformance_handoff.py` reads a conformance plan
or continuation `mesh_guidance.json`,
creates reference-only image/source/proxy collections, duplicates editable work
meshes only into generated files, and writes a handoff report with changed
paths. It also records deterministic `neutral_a_pose_30deg_v1` alignment
metadata and writes front/right/back silhouette overlay JSON plus SVG previews.
It also writes `conformance_guidance.json` with bounds/silhouette deltas,
field-engineer clothing shell candidates, prop/socket candidates, material and
color targets, warnings, and changed paths. It does not convert proxy meshes
into production topology.

## License

This project is distributed under the [MIT License](LICENSE).
