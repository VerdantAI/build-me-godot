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

## Optional last-mile editing

[Gator Model Studio](https://store.godotengine.org/asset/blackwater-gator-studios/gator-model-studio/) by Blackwater Gator Studios can provide an in-Godot last-mile refinement path for generated meshes, UVs, materials, rigs, weights, animations, and collisions. It is an optional, independently installed addon and is not redistributed by Build Me Godot. Blender remains the default automated processing path.

See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for reviewed dependency and license information.

See [LICENSES.md](LICENSES.md) before installing model weights or adding another reconstruction, rigging, animation, or refinement provider.

See [Installation and environment checks](docs/environment-checks.md) for the editor workflow and deterministic agent/CLI interface.
See [Agent setup guide](docs/agent-setup.md) for safe, copyable automation prompts and commands.
See [Developer handoff](docs/handoff.md) for repository boundaries, current capabilities, and the next independent milestones.

See [Store listing](docs/store-listing.md) for distribution copy and [Release checklist](docs/release-checklist.md) for the publishing gate.

The optional [TripoSR adapter](integrations/reconstruction/triposr/README.md) supports a user-managed, isolated local reconstruction environment. It is single-image reconstruction and is never presented as joint multiview generation.

## License

This project is distributed under the [MIT License](LICENSE).
