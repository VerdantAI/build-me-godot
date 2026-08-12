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

Character manifests and generated work are stored under `res://build_me_godot/`. They are project data and are not removed or overwritten when the addon is updated. Model weights, Python environments, and Blender installations are external dependencies; enabling the addon never downloads or installs them.

Machine configuration resolves from command-line overrides, `BUILD_ME_GODOT_*` environment variables, the gitignored project file `res://build_me_godot.local.cfg`, global Godot Editor Settings, then packaged defaults. Copy the packaged [`build_me_godot.local.cfg.example`](addons/build_me_godot/build_me_godot.local.cfg.example) to the project root or use **Save for this project** in the dock when headless tools need the same local model and executable paths as the editor.

## Repository layout

- `addons/build_me_godot/` is the distributable Godot plugin. Keep everything required by the Asset Store package self-contained there.
- `build_me_godot/` is project-local data for this repository: artist workflows, Blender scenes, generated manifests, and outputs. It is not copied as part of the plugin package.
- `utils/` is for repository-level Linux helper scripts that inspect or prepare the local workstation. These scripts are not part of the Godot addon and should not be copied into consuming games unless the user explicitly wants them.

The plugin can run with only `addons/build_me_godot/` installed in a Godot project, plus user-configured external tools such as ComfyUI and Blender. The top-level `build_me_godot/` and `utils/` folders support this repository's local asset-production workflow.

## Local setup utilities

Run the local requirement helper from this repository when preparing a Linux workstation:

```bash
utils/check-local-requirements.sh \
  --comfyui-root "$HOME/src/ComfyUI" \
  --ollama-model llama3.1:8b
```

The helper checks for common local requirements such as Godot, Blender, ComfyUI reachability, the Build Me Godot ComfyUI helper node, declared workflow model filenames, and explicitly requested Ollama models. It prints missing requirements and suggested commands, but it does not install packages, download model weights, modify ComfyUI, or change system configuration. Treat every suggested install or model-pull command as a separate user action.

## Optional last-mile editing

[Gator Model Studio](https://store.godotengine.org/asset/blackwater-gator-studios/gator-model-studio/) by Blackwater Gator Studios is a promising in-Godot last-mile option for interactively refining generated assets. Its modelling, UV, material, rigging, weight-painting, animation, collision, remeshing, and GLB tools complement Build Me Godot's orchestration and validation goals. It is optional, independently installed, and is not bundled with this addon. Blender remains the default automated processing path.

See [Attributions](addons/build_me_godot/ATTRIBUTIONS.md) for the reviewed version and license information.

The broader dependency review, including rejected model families, is recorded in [LICENSES.md](addons/build_me_godot/LICENSES.md).

## Development

Open this repository directly in Godot to exercise the addon. A character is represented by a portable, versioned JSON manifest under `res://build_me_godot/characters/<character_id>/character.json`. The same manifest is intended for Godot, Blender automation, command-line workers, and development agents.

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_character_store.gd
PYTHONPYCACHEPREFIX=/tmp/build-me-godot-pycache python3 -m py_compile \
  addons/build_me_godot/integrations/comfyui/character_turnaround_output.py \
  addons/build_me_godot/integrations/blender/build_humanoid_character.py \
  addons/build_me_godot/integrations/blender/validate_deformation.py
bash tests/test_environment_cli.sh
bash tests/test_local_tools.sh
bash tests/test_repository_separation.sh
openspec validate add-installation-environment-utilities --strict
```

Store release copy and the manual publishing gate are maintained in [Store listing](addons/build_me_godot/docs/store-listing.md) and [Release checklist](addons/build_me_godot/docs/release-checklist.md).

## License

This project is distributed under the [MIT License](LICENSE).
