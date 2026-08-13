## Context

The current successful manual workflow produces a six-view reference sheet for
an industrial worker character. It is good enough to guide Blender modeling and
rigging, but it should remain a reference asset. The Godot addon must own the
workflow state: prompt, character metadata, output paths, selected images,
approval state, and next pipeline stage.

This is a Godot addon running inside a real project/game, not a standalone
asset factory. The workflow should infer what it can from the current project:
project name, configured output workspace, existing animation libraries,
available rigged base meshes, style defaults, and any project-local settings.
The user should only be asked for information the project cannot reliably
provide, primarily character name and generation prompts.

The addon is intended for Godot Asset Store distribution. Enabling it must not
start downloads, mutate ComfyUI, install models, or run Blender. All expensive
or mutating steps remain explicit user actions.

## Goals / Non-Goals

**Goals**

- Provide a Godot editor tool that gathers project/context metadata from the
  open project and asks the user for character name, positive/negative prompts,
  and missing generation settings.
- Present the two rigged meshes the pipeline needs when the addon opens, and
  let the user replace them with project-specific meshes.
- Queue the reviewed ComfyUI reference workflow using local configuration.
- Track every generation attempt as a selectable sequential versioned run
  (`v1`, `v2`, `v3`, ...), with prompt/settings/provenance.
- Let the user review outputs in Godot, open ComfyUI for deeper review, edit
  prompts, and rerun without losing previous outputs.
- Split or normalize an approved contact sheet into named reference images when
  needed for Blender reference planes.
- Require an explicit approval/continue action before Blender reconstruction,
  modeling, rigging, validation, or Godot import continues.
- Produce a final Godot scene containing the rigged character, its available
  animations, and secondary assets generated or selected for the character.
- Keep artist-created manifests and outputs under `res://build_me_godot/`.
- Give agents deterministic files and commands to inspect run state and apply
  explicitly approved transitions.

**Non-goals**

- Replacing ComfyUI's graph editor.
- Automatic production topology from generated pixels.
- Silent pipeline continuation after image generation.
- Installing ComfyUI nodes, Python packages, model weights, Blender extensions,
  or other addons.
- Editing another addon's files or ComfyUI installation without a setup action
  from the installation-environment proposal.

## Workflow

1. User opens the Build Me Godot dock inside an existing Godot project.
2. The dock discovers project context and displays the two rigged mesh slots
   required by the pipeline, using defaults when available.
3. User accepts or replaces those rigged meshes for the project.
4. User creates or selects a character draft and enters missing required data:
   - character name / display name;
   - role/archetype;
   - positive prompt;
   - negative prompt;
   - optional seed and workflow settings.
5. The dock saves prompts and context metadata for later use.
6. The dock runs readiness checks for the reference-generation capability.
7. User starts a ComfyUI generation run.
8. The addon allocates the next sequential version tag (`v1`, then `v2`, etc.)
   and records a pending run in the character manifest before queueing.
9. The addon polls ComfyUI for completion and records produced images.
10. User reviews the output:
   - in the Godot dock;
   - optionally via an “Open in ComfyUI” action;
   - with prompt/settings visible beside the image.
11. User can duplicate/edit the prompt and rerun, creating the next version tag.
12. User approves one version as the selected reference set.
13. User explicitly enables continuation of the rest of the pipeline.
14. The addon creates normalized reference inputs for Blender automation and
    advances the manifest stage.
15. Once build/import is complete, the character, animations, and secondary
    assets are available as project-local scenes/resources.

## Character Manifest Shape

The existing character manifest remains the source of truth. This change adds
or formalizes fields equivalent to:

```json
{
  "schema_version": 1,
  "character_id": "field_engineer",
  "display_name": "Field Engineer",
  "stage": "reference_review",
  "project_context": {
    "project_name": "Verdant Example Game",
    "animation_library": "res://build_me_godot/animations/humanoid_core.tres"
  },
  "rigged_meshes": {
    "primary": "res://build_me_godot/rigs/base_humanoid.glb",
    "secondary": "res://build_me_godot/rigs/reference_proxy.glb"
  },
  "metadata": {
    "role": "construction field engineer",
    "style": "realistic game character",
    "pose_contract": "neutral_a_pose_30deg_v1"
  },
  "generation": {
    "selected_version": "v1",
    "runs": [
      {
        "run_id": "run_20260812_154322",
        "version": "v1",
        "workflow_id": "qwen_blender_reference_set_ui",
        "workflow_version": "1",
        "status": "complete",
        "positive_prompt": "...",
        "negative_prompt": "...",
        "seed": 12345,
        "queued_at": "2026-08-12T15:43:22-07:00",
        "completed_at": "2026-08-12T15:46:10-07:00",
        "outputs": {
          "contact_sheet": "res://build_me_godot/characters/field_engineer/references/run_20260812_154322/contact_sheet.png",
          "front": "res://build_me_godot/characters/field_engineer/references/run_20260812_154322/front.png",
          "right": "res://build_me_godot/characters/field_engineer/references/run_20260812_154322/right.png",
          "back": "res://build_me_godot/characters/field_engineer/references/run_20260812_154322/back.png",
          "left": "res://build_me_godot/characters/field_engineer/references/run_20260812_154322/left.png"
        }
      }
    ]
  },
  "assets": {
    "character_scene": "res://build_me_godot/characters/field_engineer/field_engineer.tscn",
    "animations": [
      "res://build_me_godot/characters/field_engineer/animations/idle.res"
    ],
    "secondary_assets": [
      {
        "asset_id": "hardhat",
        "scene": "res://build_me_godot/characters/field_engineer/assets/hardhat.tscn",
        "socket": "head"
      }
    ]
  }
}
```

Exact names may follow the current manifest conventions, but the manifest must
be sufficient for a local agent to understand what was generated, what was
approved, and which stage can run next.

## Storage Rules

- Character manifests live under
  `res://build_me_godot/characters/<character_id>/character.json`.
- Generated references live under
  `res://build_me_godot/characters/<character_id>/references/<version>/`.
- Final character scenes live under
  `res://build_me_godot/characters/<character_id>/<character_id>.tscn`.
- Secondary assets live under
  `res://build_me_godot/characters/<character_id>/assets/`.
- Character-specific animation resources live under
  `res://build_me_godot/characters/<character_id>/animations/` unless they
  reference shared project animation libraries.
- Blender intermediates and validation outputs live under the same character
  folder, not under `addons/build_me_godot/`.
- Addon workflow templates and scripts remain under `addons/build_me_godot/`.
- Repository-local experimental workflows may remain under top-level
  `build_me_godot/` until promoted into the addon package.

## Review and Continuation Gates

The UI separates states:

- `draft`: metadata/prompt exists but no queued run.
- `generating`: ComfyUI run queued or polling.
- `reference_review`: at least one output is available for review.
- `reference_approved`: a run is selected as the reference set.
- `pipeline_enabled`: user explicitly allowed the next automation stage.
- `blender_building`, `godot_import_ready`, `complete`, or `failed` as later
  stages report progress.

The “continue pipeline” button is disabled until:

- a run is complete;
- required reference outputs exist;
- the user marks a run approved;
- the required rigged mesh slots are assigned;
- readiness checks for the next stage pass or warnings are acknowledged.

## Godot UI

The dock should provide:

- character draft selector / create new;
- project context summary collected from the current Godot project;
- two rigged mesh slots with replace controls;
- metadata fields;
- positive and negative prompt editors;
- seed/settings controls;
- readiness summary with a link to setup details;
- generate/rerun controls;
- run history;
- image review area for contact sheet and split views;
- buttons for approve run, open in ComfyUI, export/copy run report, and
  continue pipeline.
- final asset summary showing the generated character scene, animations, and
  secondary assets once available.

The UI must avoid writing to external installations. It can call ComfyUI
through configured local endpoints and write project-local outputs.

## Agent Contract

Agents should be able to:

- inspect character manifests and run folders;
- run a headless command to create or update a draft from supplied metadata;
- run a headless command to queue a generation only after explicit approval;
- inspect run status and outputs in JSON;
- apply an approved “continue pipeline” transition.
- inspect final scene, animation, and secondary asset paths.

Machine output must remain deterministic JSON with stable IDs and changed path
lists. Prompt text is project data and may appear in project-local manifests,
but support/report export should redact prompts by default unless the user
chooses to include them.

### Prompt ownership and ComfyUI tuning

Godot owns durable prompts, run metadata, selected versions, output paths, and
pipeline continuation state. ComfyUI remains a useful tuning surface, but the
runner must not depend on whichever graph is currently open in a browser. When a
user tunes a packaged workflow in ComfyUI, the addon can import supported prompt
fields from exported workflow JSON into the character draft. The user then
reviews and saves those fields in Godot before queueing.

Each queued run should save the configured API workflow snapshot under
`res://build_me_godot/characters/<character_id>/workflows/<version>_api.json`
and record its source path and content hash in the run manifest. If ComfyUI
returns a `prompt_id`, the run records it for polling and history lookup. This
solves two failure modes: a Godot/agent runner can tell which ComfyUI run it is
watching, and headless mode can reproduce the exact workflow without requiring
the prompt text to be read from the ComfyUI editor.

## Risks / Trade-offs

- ComfyUI output paths and prompt IDs can change. The integration should copy
  approved outputs into project-local character folders and keep a queued
  workflow snapshot rather than depending on ComfyUI output retention or editor
  state.
- Generated views may not align perfectly. The first implementation can support
  contact-sheet storage and later add assisted split/alignment tools.
- Long-running generation can block editor UX if implemented synchronously.
  Queueing and polling must be asynchronous from the dock perspective.
- A visually good reference does not guarantee production topology. The
  manifest stage names should reflect that image approval is not mesh approval.
- Project-derived metadata can be wrong or incomplete. The UI should show what
  it inferred and let users override rigged mesh inputs and critical metadata.

## Migration Plan

1. Add manifest fields and helper APIs for project context, rigged mesh slots,
   versioned character draft generation runs, final scenes, animations, and
   secondary assets.
2. Add Godot dock form and local persistence for project metadata, mesh slots,
   character name, and prompts.
3. Add ComfyUI queue/poll integration for the reviewed reference workflow.
4. Add output copy/import into character reference folders.
5. Add review/approve/rerun UI.
6. Add explicit continue gate and prepare Blender reference inputs.
7. Add final scene/animation/secondary-asset registration.
8. Add headless/agent commands for draft, run status, approval, continue, and
   final asset inspection.
9. Add tests and documentation.

## Open Questions

- Should contact-sheet splitting be automatic in the first implementation, or
  should the first version store the sheet and individual ComfyUI outputs when
  available?
- Should long prompts stay verbatim in the manifest long-term, or should a
  later schema move them to per-run sidecar files while preserving the same
  Godot-owned source-of-truth semantics?
- Should “Open in ComfyUI” link to the server history entry keyed by
  `prompt_id`, the copied output folder, or both?
- What are the exact semantics of the two rigged mesh slots in the first
  implementation: production base plus fitting proxy, masculine/feminine bases,
  or project-defined roles?
