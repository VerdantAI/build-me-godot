## Context

Build Me Godot currently has a small editor-side dependency probe. It can run
`blender --version`, call ComfyUI's local `system_stats` endpoint, and detect a
Gator Model Studio manifest. The production workflow needs a deeper answer:
whether the selected operation—canonical generation, multiview generation,
reconstruction, Blender humanoid build, or Godot import—is ready on this
machine.

The addon is intended for the Godot Asset Store. Enabling a Store addon must
not unexpectedly modify ComfyUI, Blender, Python environments, model folders,
other addons, or system packages. At the same time, setup must not become a
collection of prose steps that agents cannot verify and artists cannot
diagnose.

## Goals / Non-Goals

**Goals**

- Produce one authoritative local readiness report for a selected workflow.
- Give artists concise status, explanations, and explicit repair actions.
- Give agents stable JSON, check IDs, exit codes, paths, and direct argv-style
  commands without requiring UI automation.
- Keep passive checking read-only, bounded, local, and safe to run repeatedly.
- Make every mutation deliberate, previewable, attributable, and auditable.
- Support Linux first without baking Linux-only assumptions into the schema.

**Non-goals**

- A general package manager, Python environment manager, model marketplace, or
  replacement for ComfyUI Manager, Blender Extensions, or the Godot Asset
  Store.
- Silent model downloads, background update checks, telemetry, analytics, or
  remote configuration.
- Installing system packages as root.
- Writing into Gator Model Studio or another addon as an implicit side effect.
- Guaranteeing that a technically loadable AI model produces acceptable art
  or production topology.

## Decisions

### One report model, multiple renderers

Check providers return plain dictionaries conforming to a versioned schema.
The editor UI, text renderer, JSON renderer, CI, and agents consume the same
results. They do not reimplement readiness rules.

Each check result contains at least:

```json
{
  "id": "comfyui.nodes.turnaround",
  "capability": "canonical_generation",
  "status": "fail",
  "importance": "required",
  "summary": "Turnaround output nodes are missing",
  "detected": [],
  "expected": ["TurnaroundNormalize", "TurnaroundSaveImage"],
  "evidence": {"endpoint": "http://127.0.0.1:8188/object_info"},
  "remediation_ids": ["install.comfyui.turnaround_helper"]
}
```

Stable values are used for `id`, `capability`, `status`, `importance`, and
remediation IDs. Human prose may improve without breaking automation.
Supported statuses are `pass`, `fail`, `warning`, `skipped`, and `unknown`.

### Readiness is workflow-specific

There is no single useful “installed” boolean. The checker accepts a target
capability, initially:

- `project_workspace`
- `canonical_generation`
- `multiview_generation`
- `reconstruction`
- `blender_humanoid_build`
- `godot_character_import`
- `last_mile_refinement`
- `all`

A missing optional Gator installation cannot block canonical generation. A
missing Qwen edit model blocks multiview but not a Blender build that already
has source images and a reconstruction mesh.

### Providers own narrow checks

Providers inspect only the systems they own:

- Godot/project provider: engine version, addon enabled state, project path,
  workspace writability, schema compatibility, and import support.
- ComfyUI provider: configured URL, local reachability, server metadata,
  `/object_info` node availability, workflow-declared loader choices, and
  device/RAM/VRAM information exposed by the server.
- Blender provider: executable resolution, version, background startup,
  Python/`bpy`, glTF import/export operators, and builder script compatibility.
- Reconstruction provider: explicitly configured command, version probe,
  local model path, output-format capability, and provider-specific license
  record.
- Asset provider: animation library existence, expected format, optional hash,
  license record, and configured output paths.
- Optional-addon provider: Gator manifest, version, enabled state, and public
  extension API compatibility.

Providers return normalized results and do not mutate installations.

### Observation and installation are separate phases

The setup system exposes these operations:

1. `check`: read-only discovery and readiness evaluation.
2. `plan`: produce ordered remediation actions without applying them.
3. `apply`: execute only explicitly selected safe actions.
4. `verify`: rerun the relevant checks and record the post-action result.

The default for both editor and CLI is `check`. `plan` is also read-only.
`apply` requires the action IDs and cannot mean “fix everything” implicitly.

Initial apply-capable actions are intentionally narrow:

- create `res://build_me_godot/` workspace directories;
- resolve machine-specific tool settings from CLI overrides, environment,
  a gitignored project-local file, global Godot Editor Settings, then defaults;
  expose explicit editor controls for saving either local or global scope;
- copy the bundled MIT turnaround helper to an explicitly selected existing
  ComfyUI `custom_nodes` destination after previewing source and target;
- create or update a project-local character manifest from a bundled template.

Model downloads, Python/package installation, system packages, and companion
addon installation remain instructions with exact expected destinations and
license information. They may gain providers only through later proposals.

### Agent contract

The repository supplies a headless entry point with commands equivalent to:

```text
godot --no-header --headless --path <project> --script \
  res://addons/build_me_godot/cli/environment_cli.gd -- \
  check --capability all --format json
```

The JSON document goes to standard output. Human diagnostics and progress go
to standard error when JSON is selected so stdout remains parseable. The CLI
uses these exit codes:

| Code | Meaning |
| ---: | --- |
| 0 | All required checks for the requested capability passed. |
| 1 | One or more required checks failed or remain unknown. |
| 2 | Invalid arguments, malformed configuration, or report generation error. |
| 3 | An explicitly requested apply action failed or verification did not pass. |

Headless commands read `res://build_me_godot.local.cfg` without requiring an
`EditorInterface`. This gives the editor and local automation one project-level
machine configuration while global Editor Settings remain reusable defaults.

The report includes `schema_version`, addon version, Godot version, requested
capability, timestamp, overall status, check results, and remediation plans.
Array ordering is stable by check ID. JSON output never includes ANSI color.

### Human contract

The editor setup view groups checks by workflow stage and shows:

- Ready, Needs attention, Optional, or Not checked;
- one-line evidence such as detected version or endpoint;
- why a failure matters for the selected workflow;
- a copyable/manual instruction or explicit safe action;
- “Copy report” and “Save JSON report” actions;
- a rerun control that does not modify the environment.

Technical stack traces and raw server bodies stay behind a details disclosure.
Warnings must be actionable and must not repeat every editor frame.

### Local-only and redacted by default

Checks contact only endpoints the user configured, normally loopback ComfyUI.
No report is uploaded. Exported reports omit authorization headers, URL query
credentials, environment-variable dumps, prompt text, generated images, and
arbitrary directory listings. Paths under the user's home directory are
represented project-relatively where possible and can be redacted in support
mode.

### Compatibility declarations live with workflow templates

Workflow packages declare required node class names, expected model loader
inputs, recommended memory class, helper version, and optional model hashes in
sidecar metadata. The environment checker reads declarations; it does not
hard-code Qwen filenames throughout UI code. Blender and reconstruction
providers use the same pattern for minimum versions and output contracts.

## Risks / Trade-offs

- Deep checks can become slow or start expensive applications. Default checks
  use version and capability probes; a Blender smoke start is explicit or
  cached for the editor session.
- ComfyUI endpoints and node metadata can change. The provider normalizes at
  its boundary and reports unsupported responses as `unknown`, not ready.
- A green environment report cannot establish artistic quality or legal
  fitness. Reports distinguish technical detection from recorded license
  provenance and retain manual acceptance gates.
- Copying a helper into ComfyUI modifies another project. The action therefore
  requires an explicit source, target preview, confirmation, backup/overwrite
  policy, and post-copy restart instruction.
- Supporting every operating system immediately would dilute reliability.
  The schema remains portable while implementation and CI begin with Linux.

## Migration Plan

1. Introduce report types and wrap the existing probes without changing dock
   behavior.
2. Add workflow metadata and deeper read-only ComfyUI/Blender checks.
3. Add text/JSON renderers and the headless CLI.
4. Replace the current dependency labels with the shared human renderer.
5. Add plan generation and the narrow safe local actions.
6. Add fixtures, integration tests, report redaction tests, and Store-facing
   setup documentation.

Existing editor settings remain valid as global defaults. A local file takes
precedence only after the user creates it. No external installation is changed
as part of migration.

## Open Questions

- Should support-mode path redaction preserve stable hashes so two reports can
  correlate the same installation without revealing its path?
- Should the optional Blender background capability test run automatically
  after an executable changes, or remain a separate “Deep check” action?
- Should separately distributed reconstruction adapters define their checks
  through JSON metadata, GDScript provider scripts, or both? The first release
  can support built-in providers only while keeping the report schema stable.
