## Why

Build Me Godot can now produce usable multiview character references through
ComfyUI, but the workflow still relies on a developer manually placing images,
tracking prompts, and deciding when Blender/Godot processing should continue.
The intended product experience is an editor tool inside Godot: an artist opens
the dock, enters a character prompt and metadata, runs the reference workflow,
reviews the output, iterates the prompt, then explicitly continues the rest of
the asset pipeline.

Without a first-class Godot workflow contract, generated references can drift
away from manifests, prompts, seeds, workflow versions, and output paths. That
breaks repeatability for artists and agents, and it makes later Blender import,
rigging, validation, and Godot asset registration ambiguous.

## What Changes

- Add a Godot editor workflow for creating a character draft from prompt and
  metadata.
- Store all character prompts, workflow runs, selected outputs, reference
  images, and continuation state under `res://build_me_godot/`, never inside
  the addon.
- Let users review ComfyUI output from Godot and optionally open the matching
  ComfyUI run for deeper inspection.
- Support prompt iteration without overwriting prior runs; each run is
  attributable and selectable.
- Add an explicit “continue pipeline” gate that turns an approved reference set
  into Blender reference inputs and subsequent rigged game-asset work.
- Expose the same workflow state to agents through manifest files and a
  deterministic local command path, without relying on editor screen scraping.

## Capabilities

### New Capabilities

- `godot-character-generation-workflow`: Godot-owned prompt entry, metadata
  capture, reference generation, output review, prompt iteration, approval, and
  continuation into Blender/Godot asset production.

### Modified Capabilities

- `installation-environment-utilities`: The setup/readiness workflow remains
  responsible for checking ComfyUI, model files, helper nodes, Blender, and
  local paths before a character run begins. This proposal consumes those
  readiness results but does not replace them.

## Impact

- Adds editor UI state for a character draft form, run history, output review,
  and continuation controls.
- Adds or extends character manifest fields for prompt text, negative prompt,
  character metadata, workflow ID/version, seeds, selected run ID, reference
  image paths, and pipeline stage.
- Adds file-management logic that imports/splits/normalizes ComfyUI outputs
  into `res://build_me_godot/characters/<character_id>/references/`.
- Adds ComfyUI queue/history integration for the Qwen multiview reference
  workflow through the existing local-only ComfyUI configuration.
- Adds tests for manifest updates, repeatable output placement, prompt
  iteration, user approval gates, and agent-readable state.
