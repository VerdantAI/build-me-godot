# Agent setup guide

Build Me Godot exposes the same local, read-only environment report used by its editor dock. An agent should discover first, propose only actions present in the returned plan, apply one explicitly authorized action, and then verify.

## Discover

```sh
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/environment_cli.gd -- check --capability all --format json --support-report
```

> Inspect this Build Me Godot project using its environment CLI. Parse the JSON report, preserve stable check and remediation IDs, and summarize required failures separately from optional warnings. Do not install or modify anything.

## Plan

```sh
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/environment_cli.gd -- plan --capability canonical_generation --format json --comfyui-root /path/to/ComfyUI
```

> Generate the Build Me Godot installation plan. Explain each action's paths, reversibility, license, and verification check. Do not apply an action until I select its exact ID.

## Apply and verify

```sh
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/environment_cli.gd -- apply --capability project_workspace --format json --action create.project.workspace
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/environment_cli.gd -- verify --capability project_workspace --format json
```

> Apply only the selected action ID from the current plan. Report changed paths and verification. Stop if the action is absent, manual, would overwrite a file, or would modify system Python, model weights, external packages, or an unselected dependency.

Exit code `0` means ready or successfully applied, `1` means required checks are not ready, `2` means invalid invocation or action selection, and `3` means an explicit action or its verification failed. JSON stdout is machine-readable; diagnostics use stderr.

CLI path flags are invocation-local and take precedence over `BUILD_ME_GODOT_*` environment variables, the gitignored `res://build_me_godot.local.cfg`, and global Editor Settings. An agent may read the local file for diagnosis but should change it only when the artist requests project-local configuration. Use the dock's **Save for this project** or copy the packaged example; never edit Godot's global editor settings file directly.

## Field-engineer conformance

After a reference version is completed and approved, agents can prepare the
non-destructive conformance plan without running external inference:

```sh
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- \
  prepare-conformance --character-id field_engineer --version v1
godot --no-header --headless --path . --script res://addons/build_me_godot/cli/character_cli.gd -- \
  inspect-conformance --character-id field_engineer --version v1
```

The plan is written under
`res://build_me_godot/characters/<character_id>/conformance/<version>/` and
records source references, rigged meshes, provider provenance,
field-engineer targets, validation constraints, and changed paths. A manually
reviewed proxy mesh can be recorded with `--proxy-mesh`, but it remains an
immutable reference and is not production topology.
