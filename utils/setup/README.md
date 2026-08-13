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
utils/check-local-requirements.sh apply link.example.addon --yes --json
```

Do not run `apply` actions unless the user has approved the specific action ID.
Without `--yes`, interactive `setup` and `apply` commands show the planned file
operation and ask before proceeding. Model downloads are staged first; moving
them into ComfyUI is a separate action. Terminal downloads show a progress bar;
`--json` keeps progress output silent for agents. Incomplete downloads use a
`.part` suffix and are removed after cancellation or failure.

Human output includes review sections for missing ComfyUI custom node classes
and model downloads. Model reviews include the declared license, source
repository, download URL, staging path, and target ComfyUI model directory.
If the Build Me Godot helper file exists but ComfyUI has not loaded its node
classes, setup offers `refresh.comfyui.helper`; restart ComfyUI after running
that action.

When the companion `godot-addons-example-project` is present next to this
repository, setup checks whether its `addons/build_me_godot` path is a symlink
to this checkout. If it is missing, `link.example.addon` offers to create the
development symlink. Override the project location with
`--example-project /path/to/project` or `BUILD_ME_GODOT_EXAMPLE_PROJECT`.

Machine-readable reports include:

- `ready`: whether every required check passed.
- `checks[]`: current diagnostics with stable check IDs.
- `actions[]`: available remediation actions with `mutates` and `ready` flags.
- `changed_paths[]`: files touched by an `apply` command.
