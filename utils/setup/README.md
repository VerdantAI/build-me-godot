# Build Me Godot Setup Assistant

`build_me_godot_setup.py` is the implementation behind
`../check-local-requirements.sh`. It is designed for both humans and coding
agents:

- `check` is read-only and reports current state.
- `plan` is read-only and reports available remediation action IDs.
- `doctor` is a human-readable alias for `plan`.
- `apply <action_id>` is the only command that mutates local files or pulls
  external artifacts.
- `--json` emits a stable machine-readable report on stdout.

Recommended agent flow:

```bash
utils/check-local-requirements.sh check --json
utils/check-local-requirements.sh plan --json
utils/check-local-requirements.sh apply write.local.config
utils/check-local-requirements.sh apply install.comfyui.helper
utils/check-local-requirements.sh apply download.models
utils/check-local-requirements.sh apply move.models
```

Do not run `apply` actions unless the user has approved the specific action ID.
Model downloads are staged first; moving them into ComfyUI is a separate action.

Machine-readable reports include:

- `ready`: whether every required check passed.
- `checks[]`: current diagnostics with stable check IDs.
- `actions[]`: available remediation actions with `mutates` and `ready` flags.
- `changed_paths[]`: files touched by an `apply` command.
