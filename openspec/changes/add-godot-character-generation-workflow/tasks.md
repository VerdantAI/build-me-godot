## 1. Manifest and Storage Contract

- [ ] 1.1 Define character generation run fields for metadata, prompts,
  workflow provenance, status, timestamps, selected run, output image paths,
  and pipeline stage.
- [ ] 1.2 Add manifest read/write helpers that preserve unknown fields and
  avoid writing inside `addons/build_me_godot/`.
- [ ] 1.3 Add run folder creation under
  `res://build_me_godot/characters/<character_id>/references/<run_id>/`.
- [ ] 1.4 Add tests for stable paths, repeat runs, selected-run changes, and
  prompt/provenance persistence.

## 2. Godot Editor Draft UI

- [ ] 2.1 Add a character draft panel with create/select character controls.
- [ ] 2.2 Add metadata fields for character ID, display name, role/archetype,
  style notes, pose contract, and other required pipeline metadata.
- [ ] 2.3 Add positive/negative prompt editors and generation settings.
- [ ] 2.4 Add validation messages for missing required metadata and invalid
  character IDs.

## 3. ComfyUI Reference Generation

- [ ] 3.1 Add a Godot-side service for queueing the reviewed Qwen reference
  workflow against the configured ComfyUI endpoint.
- [ ] 3.2 Record a pending run before queueing and update it from ComfyUI
  prompt/history status.
- [ ] 3.3 Copy completed outputs into the project-local character run folder.
- [ ] 3.4 Record workflow ID/version, seed, prompt text, model provenance, and
  output paths in the manifest.
- [ ] 3.5 Keep failures recoverable and attributable to a run without corrupting
  the selected approved run.

## 4. Review, Iteration, and Approval

- [ ] 4.1 Add a review panel for contact sheet and named view outputs.
- [ ] 4.2 Add run history with prompt/settings visibility and selected output.
- [ ] 4.3 Add rerun-from-previous controls that duplicate prompt/settings into a
  new run.
- [ ] 4.4 Add approve/unapprove controls that update selected run and stage.
- [ ] 4.5 Add optional “Open in ComfyUI” action for deeper review.

## 5. Continue Pipeline Gate

- [ ] 5.1 Add explicit “continue pipeline” state transition after reference
  approval.
- [ ] 5.2 Generate Blender reference input metadata from the approved run.
- [ ] 5.3 Disable continuation until required outputs exist and next-stage
  readiness checks pass or warnings are acknowledged.
- [ ] 5.4 Add changed-path and stage-transition reporting for agent use.

## 6. Headless and Agent Interface

- [ ] 6.1 Add commands to create/update a character draft from metadata and
  prompt inputs.
- [ ] 6.2 Add commands to inspect generation state and run history as JSON.
- [ ] 6.3 Add explicit commands for approved queue, approve run, and continue
  transitions.
- [ ] 6.4 Ensure JSON stdout is stable and free of progress/log text.

## 7. Validation and Documentation

- [ ] 7.1 Add unit tests for manifest updates, run history, approval gates, and
  output placement.
- [ ] 7.2 Add integration tests with a mock ComfyUI queue/history server.
- [ ] 7.3 Add editor smoke tests for draft creation, review, and continuation
  states where feasible.
- [ ] 7.4 Update README and addon documentation with the Godot-first workflow.
- [ ] 7.5 Run headless editor load, GDScript tests, Python parser checks, and
  `git diff --check`.
