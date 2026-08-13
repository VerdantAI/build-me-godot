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

## Example project

Use the companion [godot-addons-example-project](https://github.com/VerdantAI/godot-addons-example-project) to exercise Build Me Godot as a normal consuming project. It is the preferred place for runnable scenes, sample rig placeholders, sample character manifests, and end-to-end manual workflow checks.

The example project is intentionally separate from this addon repository. Do not copy this repository's top-level `utils/` or local `build_me_godot/` workflow data into games; install only `addons/build_me_godot/` and keep project-owned character data under that game's `res://build_me_godot/`.

For local addon development, either copy the addon package into the example project's `addons/` folder or symlink exactly to this repository's addon package directory:

```bash
cd /home/buddha/verdant/godot-addons-example-project
mkdir -p addons
ln -s /home/buddha/verdant/build-me-godot/addons/build_me_godot addons/build_me_godot
```

The installed shape must be `addons/build_me_godot/plugin.cfg`. Do not link or copy the repository root, the top-level `build_me_godot/` data folder, or a nested `addons/` folder. Keep development symlinks out of release packages and normal user installs; Store testing should still verify a normal copied/exported addon install.

## Godot-first character workflow

Open the Build Me Godot dock inside the target Godot project. The addon records project context, two rigged mesh slots, character metadata, positive/negative prompts, generation settings, and later outputs in `res://build_me_godot/characters/<character_id>/character.json`.

The intended loop is:

1. Create or select a character draft in Godot.
2. Confirm the primary and secondary rigged mesh inputs for the project.
3. Enter the character name, role/style metadata, and prompts.
4. Queue a local ComfyUI reference workflow from the dock.
5. Review the generated version, iterate prompts into `v1`, `v2`, and later runs, then approve one version.
6. Explicitly continue the downstream pipeline. This writes `blender/<version>/reference_inputs.json` for Blender automation and advances the manifest stage.
7. Register the final Godot scene, animations, and secondary assets back into the same character manifest when downstream work completes.

The setup tab shows Godot-style local status indicators for ComfyUI found/running, ComfyUI nodes/models, Blender, Ollama, animation assets, and the base character scene. The scene field defaults to `res://scenes/base_characters.tscn`; use **Load base character scene** when a consuming project provides that scene with its mannequin characters for rigged-mesh inspection. This is separate from the project's normal `main.tscn` entry scene.

Headless agents can inspect and apply approved manifest transitions without running external setup or downloads:

```bash
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- inspect --character-id field_engineer
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- queue --character-id field_engineer
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- approve --character-id field_engineer --version v1
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- continue --character-id field_engineer --version v1
```

With `--no-header`, these commands emit JSON on stdout. Mutating commands only update project-local files under `res://build_me_godot/`; they do not install ComfyUI nodes, download model weights, run Blender, or start unrelated pipeline stages.

Godot remains the source of truth for prompts and run metadata. If a prompt is tuned directly in ComfyUI, import the workflow JSON back into the dock or with the `import-workflow` CLI command, review the fields, and save the draft before queueing another run. When Godot queues a workflow, it records the returned ComfyUI `prompt_id` and saves the configured API workflow snapshot under `res://build_me_godot/characters/<character_id>/workflows/<version>_api.json`; headless agents should replay or inspect that snapshot instead of trying to infer state from the ComfyUI editor.

```bash
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- import-workflow --character-id field_engineer --workflow-path res://addons/build_me_godot/workflows/character_turnaround_open.json
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- queue --character-id field_engineer --workflow-path res://addons/build_me_godot/workflows/canonical_only_api.json
```

## Local setup utilities

Run the local requirement helper from this repository when preparing a Linux workstation:

```bash
utils/check-local-requirements.sh
```

With no command, the helper checks the machine, reviews missing ComfyUI custom nodes and model downloads, lists ready setup actions, and asks before applying each one. It also prints detail/help commands and a prominent `AGENT HANDOFF` command block.

The helper can also write a reusable, gitignored local config:

```bash
utils/check-local-requirements.sh apply write.local.config
```

Use [utils/check-local-requirements.conf.example](utils/check-local-requirements.conf.example) as the checked-in template. The generated `utils/check-local-requirements.local.conf` records ComfyUI URL/root, model staging directory, Blender executable, companion example project path, and Ollama host/model paths for later runs. Pass overrides such as `--comfyui-root "$HOME/src/ComfyUI"`, `--example-project "$HOME/verdant/godot-addons-example-project"`, or `--ollama-model llama3.1:8b` when needed.

The helper is a Python setup app with a shell wrapper. Use `check` for read-only diagnostics, `doctor` for human-readable details, `plan --json` to hand setup to an agent, and `apply <action_id>` for explicit mutations:

```bash
utils/check-local-requirements.sh doctor
utils/check-local-requirements.sh check --json
utils/check-local-requirements.sh plan --json
utils/check-local-requirements.sh apply install.comfyui.helper
utils/check-local-requirements.sh apply download.models
utils/check-local-requirements.sh apply move.models
utils/check-local-requirements.sh apply link.example.addon
utils/check-local-requirements.sh apply write.container.config
```

The helper checks for common local requirements such as Godot, Blender, ComfyUI reachability, the Build Me Godot ComfyUI helper node, declared workflow model filenames, the companion example-project addon symlink, and explicitly requested Ollama models. If `--comfyui-root` is omitted, it tries to infer the root from the running local ComfyUI process. `check` and `plan` are read-only; only `apply <action_id>` installs helpers, downloads model files, moves staged files, links the example project, pulls Ollama models, or writes config. Mutating `apply` commands explain the planned change and ask for confirmation by default; use `--yes` only after a specific action has already been approved for non-interactive or JSON automation.

The setup helper also reports optional container readiness for an isolated local
ComfyUI/TripoSR/Blender toolchain. It prefers reusing user-owned model stores by
mounting existing ComfyUI models, custom nodes, outputs, staged model downloads,
and Ollama model caches into the container. `apply write.container.config`
writes a gitignored env file describing those mounts; it does not build, pull,
or run a container image.

The reviewed local image recipe lives in `containers/local-toolchain/`. It
exposes `doctor`, `comfyui-server`, `triposr-job`, and `blender-job` modes and
keeps model weights outside the image. Build and run it only through explicit
setup actions such as `container.build.local_toolchain` and `container.doctor`.

For the companion example project, `apply link.example.addon` creates only the package-level development symlink: `godot-addons-example-project/addons/build_me_godot -> build-me-godot/addons/build_me_godot`. The setup app verifies that `addons/build_me_godot/plugin.cfg` is visible through the link.

If the Build Me Godot helper file exists but ComfyUI has not loaded its node classes, the helper offers `refresh.comfyui.helper`; restart ComfyUI after running it.

When declared workflow model files are missing, the helper prints a download review with the declared license, source repository, URL, staging path, and target ComfyUI directory, plus `curl` commands for the reviewed Apache-2.0 artifacts. `apply download.models` downloads files into the configured staging directory with a terminal progress bar, writes in-progress downloads to `.part` files, and removes partial downloads after cancellation or failure. `apply move.models` moves staged files into the correct ComfyUI `models/` subdirectory without overwriting existing files.

## Optional last-mile editing

[Gator Model Studio](https://store.godotengine.org/asset/blackwater-gator-studios/gator-model-studio/) by Blackwater Gator Studios is a promising in-Godot last-mile option for interactively refining generated assets. Its modelling, UV, material, rigging, weight-painting, animation, collision, remeshing, and GLB tools complement Build Me Godot's orchestration and validation goals. It is optional, independently installed, and is not bundled with this addon. Blender remains the default automated processing path.

See [Attributions](addons/build_me_godot/ATTRIBUTIONS.md) for the reviewed version and license information.

The broader dependency review, including rejected model families, is recorded in [LICENSES.md](addons/build_me_godot/LICENSES.md).

## Development

Open this repository directly in Godot to exercise the addon. A character is represented by a portable, versioned JSON manifest under `res://build_me_godot/characters/<character_id>/character.json`. The same manifest is intended for Godot, Blender automation, command-line workers, and development agents.

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_character_store.gd
bash tests/test_character_cli.sh
bash tests/test_comfyui_client.sh
godot --headless --editor --path . --script res://tests/test_build_me_godot_dock_smoke.gd --quit
PYTHONPYCACHEPREFIX=/tmp/build-me-godot-pycache python3 -m py_compile \
  tests/mock_comfyui_server.py \
  addons/build_me_godot/integrations/comfyui/character_turnaround_output.py \
  addons/build_me_godot/integrations/blender/build_humanoid_character.py \
  addons/build_me_godot/integrations/blender/validate_deformation.py \
  build_me_godot/blender/tools/prepare_rigify_face_experiment.py \
  build_me_godot/blender/tools/fit_rigify_face_baseline.py \
  build_me_godot/blender/tools/generate_rigify_face_controls.py \
  build_me_godot/blender/tools/integrate_rigify_face_layer.py \
  build_me_godot/blender/tools/split_face_working_files.py
bash tests/test_environment_cli.sh
bash tests/test_local_tools.sh
bash tests/test_setup_services.sh
bash tests/test_repository_separation.sh
openspec validate add-installation-environment-utilities --strict
```

Store release copy and the manual publishing gate are maintained in [Store listing](addons/build_me_godot/docs/store-listing.md) and [Release checklist](addons/build_me_godot/docs/release-checklist.md).

## License

This project is distributed under the [MIT License](LICENSE).
