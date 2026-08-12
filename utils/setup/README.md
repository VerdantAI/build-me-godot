# Build Me Godot Setup Assistant

`build_me_godot_setup.py` is the implementation behind
`../check-local-requirements.sh`. It is designed for both humans and coding
agents:

- `setup` is the default command. It checks the machine, prints detail/help
  commands, shows a prominent `AGENT HANDOFF` command block, lists ready
  actions, and asks before applying each action.
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
```

Do not run `apply` actions unless the user has approved the specific action ID.
Without `--yes`, interactive `setup` and `apply` commands show the planned file
operation and ask before proceeding. Model downloads are staged first; moving
them into ComfyUI is a separate action. Terminal downloads show a progress bar;
`--json` keeps progress output silent for agents. Incomplete downloads use a
`.part` suffix and are removed after cancellation or failure.

Machine-readable reports include:

- `ready`: whether every required check passed.
- `checks[]`: current diagnostics with stable check IDs.
- `actions[]`: available remediation actions with `mutates` and `ready` flags.
- `changed_paths[]`: files touched by an `apply` command.
