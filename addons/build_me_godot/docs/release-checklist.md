# Release checklist

## Automated gate

Run from the repository root:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_character_store.gd
bash tests/test_environment_cli.sh
bash tests/test_local_tools.sh
openspec validate add-installation-environment-utilities --strict
git diff --check
```

- Confirm the addon copy contains no model weights, generated characters, credentials, machine-specific reports, or external animation assets.
- Recheck every exact external version and model artifact in `LICENSES.md` before release.
- Confirm plugin activation and `check`/`plan` remain local, read-only, and free of downloads.

## Manual Godot editor gate

- Verify keyboard focus reaches every dock field, button, character selector, and technical-details toggle in a useful order.
- Test the dock at its narrowest practical width and at 100%, 150%, and 200% display scaling; prompts and reports must remain usable without horizontal clipping.
- Confirm every check shows a textual `PASS`, `FAIL`, `WARNING`, `UNKNOWN`, or `SKIPPED` cue independent of color.
- Run normal and deep checks, expand technical details, copy a report, and save a report.
- Confirm Build Me Godot entries appear in global Editor Settings, **Save for me** updates them, and **Save for this project** writes the gitignored local file.
- Confirm environment and CLI overrides take precedence, every field reports its effective source, and a headless check reads the local file without `EditorInterface`.
- Exercise a clean project and a configured project without changing external dependencies.
- Exercise the companion example project at https://github.com/VerdantAI/godot-addons-example-project as a normal consuming project before release.

## Store media gate

- Capture a clean dock overview with the Field Engineer example selected.
- Capture capability-grouped environment results and the redacted technical report.
- Capture saved character files and a ComfyUI workflow refinement view without exposing local paths or credentials.
- Capture a generated turnaround and Blender/Godot result only when its asset license permits redistribution.
- Prefer consumer-project screenshots from `godot-addons-example-project`; do not include generated characters, rigs, or model outputs whose licenses are not cleared for redistribution.
- Review screenshots at Store thumbnail and full-size presentation before publishing.
