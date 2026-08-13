# Build Me Godot Setup Assistant

`build_me_godot_setup.py` is the implementation behind
`../check-local-requirements.sh`. It is designed for both humans and coding
agents:

- `setup` is the default command. It checks the machine, prints detail/help
  commands, shows a prominent `AGENT HANDOFF` command block, lists ready
  actions, reviews missing custom nodes/model downloads, and asks before
  applying each action.
- `check` is read-only and reports current state.
- `plan` is read-only and reports available remediation action IDs.
- `doctor` is a human-readable alias for `plan`.
- `apply <action_id>` is the only command that mutates local files or pulls
  external artifacts.
- Mutating `apply` commands explain the planned change and ask for confirmation
  in an interactive shell.
- Use `--yes` only after the user has approved the specific action ID.
- `--json` emits a stable machine-readable report on stdout.

Recommended agent flow:

```bash
utils/check-local-requirements.sh plan --json
utils/check-local-requirements.sh check --json
utils/check-local-requirements.sh apply write.local.config --yes --json
utils/check-local-requirements.sh apply install.comfyui.helper --yes --json
utils/check-local-requirements.sh apply download.models --yes --json
utils/check-local-requirements.sh apply move.models --yes --json
utils/check-local-requirements.sh apply write.container.config --yes --json
utils/check-local-requirements.sh apply container.build.local_toolchain --yes --json
utils/check-local-requirements.sh apply container.doctor --yes --json
utils/check-local-requirements.sh apply container.start.comfyui --yes --json
utils/check-local-requirements.sh apply container.stop.comfyui --yes --json
utils/check-local-requirements.sh apply link.example.addon --yes --json
utils/check-local-requirements.sh apply start.comfyui --yes --json
utils/check-local-requirements.sh apply stop.comfyui --yes --json
utils/check-local-requirements.sh apply start.ollama --yes --json
utils/check-local-requirements.sh apply stop.ollama --yes --json
utils/check-local-requirements.sh apply start.blender --yes --json
utils/check-local-requirements.sh apply stop.blender --yes --json
```

Do not run `apply` actions unless the user has approved the specific action ID.
Without `--yes`, interactive `setup` and `apply` commands show the planned file
operation and ask before proceeding. ComfyUI model downloads are staged first;
moving them into ComfyUI is a separate action. Terminal downloads show a
progress bar; `--json` keeps progress output silent for agents. Incomplete
downloads use a `.part` suffix and are removed after cancellation or failure.

For local ComfyUI TripoSR, the setup app detects an already installed external
`flowtyone/ComfyUI-Flowty-TripoSR` custom node and local TripoSR checkpoint,
but it no longer downloads or installs those reconstruction runtime pieces.
The container toolchain is expected to provide runtime dependencies, while
model weights are reused from user-owned mounted folders.

Containerized local toolchains are optional. The setup app detects Podman,
Docker, or Apptainer, checks for NVIDIA CDI GPU wiring when an NVIDIA GPU is
present, and can write `utils/check-local-container.local.env` with the
existing model, custom node, output, and cache folders that should be mounted
into a future ComfyUI/TripoSR/Blender container. Model weights stay in
user-owned host directories; Build Me Godot does not bake them into container
images. Building or running the image remains a separate explicit action after
the image recipe has been reviewed. The recipe is in
`containers/local-toolchain/` and exposes `doctor`, `comfyui-server`,
`triposr-job`, and `blender-job` modes.

Use `utils/run-container-triposr.sh` as a reconstruction provider command after
the image is built. It implements `--version`, `--input`, `--output`, and
`--metadata-output`, and calls the containerized `triposr-job` without changing
the provider contract.

When an NVIDIA GPU is visible but no CDI spec is detected, setup reports
`container.gpu.nvidia_cdi` as a warning and exposes
`manual.configure.nvidia.cdi`. That action prints operator commands for
generating/listing NVIDIA CDI specs and smoke-testing Podman GPU access; it
does not install NVIDIA Container Toolkit or edit system files itself.

Start actions launch the configured application in the background and write a
PID record and log beneath the user's runtime directory (or `/tmp`). Matching
stop actions are offered only for a live process started by this utility; the
assistant never terminates an independently started ComfyUI, Ollama, or Blender
process.

Human output includes review sections for missing ComfyUI custom node classes
and model downloads. Model reviews include the declared license, source
repository, download URL, staging path, and target ComfyUI model directory
when applicable. TripoSR reviews include the exact Hugging Face revision and
expected local paths for `config.yaml` and `model.ckpt`, but no setup action is
offered to download or place those files.
If the Build Me Godot helper file exists but ComfyUI has not loaded its node
classes, setup offers `refresh.comfyui.helper`; restart ComfyUI after running
that action.

When the companion `godot-addons-example-project` is present next to this
repository, setup checks whether its `addons/build_me_godot` path is a symlink
to this checkout's addon package directory. If it is missing,
`link.example.addon` offers to create the development symlink:

```text
example/addons/build_me_godot -> build-me-godot/addons/build_me_godot
```

The resulting Godot plugin path must be
`example/addons/build_me_godot/plugin.cfg`. The setup app refuses to overwrite a
normal directory and verifies `plugin.cfg` after creating or accepting a
symlink. Override the project location with `--example-project /path/to/project`
or `BUILD_ME_GODOT_EXAMPLE_PROJECT`.

Machine-readable reports include:

- `ready`: whether every required check passed.
- `checks[]`: current diagnostics with stable check IDs.
- `actions[]`: available remediation actions with `mutates` and `ready` flags.
- `changed_paths[]`: files touched by an `apply` command.
