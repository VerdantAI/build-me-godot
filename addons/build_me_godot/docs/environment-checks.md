# Installation and environment checks

Build Me Godot uses one versioned environment report for the editor setup view, command-line users, CI, and development agents. Checks are local and read-only. They never install, download, overwrite, or reconfigure dependencies.

## Agent and CLI use

Run from a Godot project containing the addon:

```bash
godot --no-header --headless --path /path/to/project \
  --script res://addons/build_me_godot/cli/environment_cli.gd -- \
  check --capability all --format json
```

`--no-header` is required when a caller expects stdout to contain only JSON. Supported capabilities are:

- `project_workspace`
- `canonical_generation`
- `multiview_generation`
- `reconstruction`
- `blender_humanoid_build`
- `godot_character_import`
- `last_mile_refinement`
- `all`

Optional overrides:

```text
--comfyui-url http://127.0.0.1:8188
--comfyui-root /path/to/ComfyUI
--blender /path/to/blender
--reconstruction-command /path/to/provider
--animation-asset res://path/to/animations.glb
--support-report
--deep-check
```

Configuration resolves in this order:

1. command-line options;
2. `BUILD_ME_GODOT_*` environment variables;
3. `res://build_me_godot.local.cfg` for this project and machine;
4. global **Editor > Editor Settings > Build Me Godot** values when an editor is running;
5. packaged defaults.

The project-local file is gitignored and is the shared configuration source for editor and headless runs. Start from `build_me_godot.local.cfg.example` or write it with **Save for this project** in the dock. **Save for me** writes global editor defaults instead. The dock reports the effective source for each field. Available environment variables are `BUILD_ME_GODOT_COMFYUI_URL`, `BUILD_ME_GODOT_COMFYUI_ROOT`, `BUILD_ME_GODOT_BLENDER_PATH`, `BUILD_ME_GODOT_RECONSTRUCTION_COMMAND`, and `BUILD_ME_GODOT_ANIMATION_ASSET`.

Use `--support-report` when sharing JSON with another developer or agent. It replaces the user home directory with `<home>` and project-local absolute paths with `res://`. Check IDs, statuses, schema versions, and ordering are unchanged.

`--deep-check` explicitly starts Blender with factory settings in background mode and verifies the operators declared by the packaged humanoid builder. Normal checks only run `blender --version`.

Exit codes:

| Code | Meaning |
| ---: | --- |
| 0 | All required checks passed. |
| 1 | A required check failed or is unknown. |
| 2 | Invalid invocation or report-generation error. |
| 3 | Reserved for an explicit apply or verification failure. |

`plan` returns ordered remediation without changing the machine. `apply` requires one explicit `--action ID`; it never means “fix everything.” Initial apply-capable actions are `create.project.workspace` and, when `--comfyui-root` identifies an existing installation, `install.comfyui.turnaround_helper`. Helper overwrite is deliberately refused. `verify` reruns checks without mutation.

## Human use

Open the Build Me Godot dock, configure the local ComfyUI URL and Blender executable, then choose **Check dependencies**. The dock renders the same results and readiness rules as the CLI.

The addon itself is installed and enabled per project. Machine-specific ComfyUI, Blender, reconstruction, and animation-library locations can be saved globally with **Save for me** or in the gitignored project-local configuration with **Save for this project**. Character prompts, workflow selections, and generated-asset records remain versioned project data under `res://build_me_godot/`.

Missing Gator Model Studio is optional and does not block image generation. Missing reconstruction or animation configuration remains an explicit unknown requirement for the stages that need it.

## Privacy

Reports do not contain character prompts, generated images, authorization headers, environment-variable dumps, or arbitrary directory listings. Service evidence uses a credential-free origin. Reports are not uploaded.

See [Agent setup guide](agent-setup.md) for copyable discovery, planning, explicit apply, and verification prompts.
