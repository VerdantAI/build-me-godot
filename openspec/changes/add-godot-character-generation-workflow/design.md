## Context

The current successful manual workflow produces a six-view reference sheet for
an industrial worker character. It is good enough to guide Blender modeling and
rigging, but it should remain a reference asset. The Godot addon must own the
workflow state: prompt, character metadata, output paths, selected images,
approval state, and next pipeline stage.

The addon is intended for Godot Asset Store distribution. Enabling it must not
start downloads, mutate ComfyUI, install models, or run Blender. All expensive
or mutating steps remain explicit user actions.

## Goals / Non-Goals

**Goals**

- Provide a Godot editor tool where a user enters character metadata,
  positive/negative prompts, generation settings, and an output folder.
- Queue the reviewed ComfyUI reference workflow using local configuration.
- Track every generation attempt as a run with prompt/settings/provenance.
- Let the user review outputs in Godot, open ComfyUI for deeper review, edit
  prompts, and rerun without losing previous outputs.
- Split or normalize an approved contact sheet into named reference images when
  needed for Blender reference planes.
- Require an explicit approval/continue action before Blender reconstruction,
  modeling, rigging, validation, or Godot import continues.
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

1. User opens the Build Me Godot dock and creates or selects a character draft.
2. User enters required metadata:
   - character ID / display name;
   - role/archetype;
   - body proportions or style notes;
   - positive prompt;
   - negative prompt;
   - optional seed and workflow settings.
3. The dock runs readiness checks for the reference-generation capability.
4. User starts a ComfyUI generation run.
5. The addon records a pending run in the character manifest before queueing.
6. The addon polls ComfyUI for completion and records produced images.
7. User reviews the output:
   - in the Godot dock;
   - optionally via an “Open in ComfyUI” action;
   - with prompt/settings visible beside the image.
8. User can duplicate/edit the prompt and rerun, creating a new run.
9. User approves one run as the selected reference set.
10. User explicitly enables continuation of the rest of the pipeline.
11. The addon creates normalized reference inputs for Blender automation and
    advances the manifest stage.

## Character Manifest Shape

The existing character manifest remains the source of truth. This change adds
or formalizes fields equivalent to:

```json
{
  "schema_version": 1,
  "character_id": "field_engineer",
  "display_name": "Field Engineer",
  "stage": "reference_review",
  "metadata": {
    "role": "construction field engineer",
    "style": "realistic game character",
    "pose_contract": "neutral_a_pose_30deg_v1"
  },
  "generation": {
    "selected_run_id": "run_20260812_154322",
    "runs": [
      {
        "run_id": "run_20260812_154322",
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
  `res://build_me_godot/characters/<character_id>/references/<run_id>/`.
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
- readiness checks for the next stage pass or warnings are acknowledged.

## Godot UI

The dock should provide:

- character draft selector / create new;
- metadata fields;
- positive and negative prompt editors;
- seed/settings controls;
- readiness summary with a link to setup details;
- generate/rerun controls;
- run history;
- image review area for contact sheet and split views;
- buttons for approve run, open in ComfyUI, export/copy run report, and
  continue pipeline.

The UI must avoid writing to external installations. It can call ComfyUI
through configured local endpoints and write project-local outputs.

## Agent Contract

Agents should be able to:

- inspect character manifests and run folders;
- run a headless command to create or update a draft from supplied metadata;
- run a headless command to queue a generation only after explicit approval;
- inspect run status and outputs in JSON;
- apply an approved “continue pipeline” transition.

Machine output must remain deterministic JSON with stable IDs and changed path
lists. Prompt text is project data and may appear in project-local manifests,
but support/report export should redact prompts by default unless the user
chooses to include them.

## Risks / Trade-offs

- ComfyUI output paths and prompt IDs can change. The integration should copy
  approved outputs into project-local character folders rather than depending
  on ComfyUI output retention.
- Generated views may not align perfectly. The first implementation can support
  contact-sheet storage and later add assisted split/alignment tools.
- Long-running generation can block editor UX if implemented synchronously.
  Queueing and polling must be asynchronous from the dock perspective.
- A visually good reference does not guarantee production topology. The
  manifest stage names should reflect that image approval is not mesh approval.

## Migration Plan

1. Add manifest fields and helper APIs for character draft generation runs.
2. Add Godot dock form and local persistence for metadata/prompts.
3. Add ComfyUI queue/poll integration for the reviewed reference workflow.
4. Add output copy/import into character reference folders.
5. Add review/approve/rerun UI.
6. Add explicit continue gate and prepare Blender reference inputs.
7. Add headless/agent commands for draft, run status, approval, and continue.
8. Add tests and documentation.

## Open Questions

- Should contact-sheet splitting be automatic in the first implementation, or
  should the first version store the sheet and individual ComfyUI outputs when
  available?
- Should prompts be stored verbatim in the manifest or in per-run sidecar files
  referenced by the manifest?
- Should “Open in ComfyUI” link to the current server history entry, copied
  output folder, or both?
