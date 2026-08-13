## 1. Manifest and Storage Contract

- [x] 1.1 Define character generation run fields for project context, rigged
  mesh slots, metadata, prompts, workflow provenance, sequential version tags,
  status, timestamps, selected version, output image paths, final scene paths,
  animation paths, secondary asset paths, and pipeline stage.
- [x] 1.2 Add manifest read/write helpers that preserve unknown fields and
  avoid writing inside `addons/build_me_godot/`.
- [x] 1.3 Add run folder creation under
  `res://build_me_godot/characters/<character_id>/references/<run_id>/`.
- [x] 1.4 Add tests for stable paths, repeat runs, sequential `v1`/`v2` tags,
  selected-version changes, final asset paths, and prompt/provenance
  persistence.

## 2. Godot Editor Draft UI

- [x] 2.1 Add a character draft panel with create/select character controls.
- [x] 2.2 Add project context discovery for project name, workspace, shared
  animation libraries, and configured defaults.
- [x] 2.3 Add two rigged mesh slots shown when the addon opens, with controls
  to replace defaults with project-specific rigged meshes.
- [x] 2.4 Add metadata fields for character name, display name, role/archetype,
  style notes, pose contract, and other required pipeline metadata that cannot
  be inferred from the project.
- [x] 2.5 Add positive/negative prompt editors and generation settings.
- [x] 2.6 Add validation messages for missing required metadata, missing rigged
  mesh slots, and invalid character IDs.

## 3. ComfyUI Reference Generation

- [x] 3.1 Add a Godot-side service for queueing the reviewed Qwen reference
  workflow against the configured ComfyUI endpoint.
- [x] 3.2 Allocate the next sequential version tag before queueing, record a
  pending run, and update it from ComfyUI prompt/history status.
- [x] 3.3 Copy completed outputs into the project-local character run folder.
- [x] 3.4 Record workflow ID/version, seed, prompt text, model provenance, and
  output paths in the manifest.
- [x] 3.5 Keep failures recoverable and attributable to a run without corrupting
  the selected approved run.

## 4. Review, Iteration, and Approval

- [x] 4.1 Add a review panel for contact sheet and named view outputs.
- [x] 4.2 Add run history with prompt/settings visibility and selected output.
- [x] 4.3 Add rerun-from-previous controls that duplicate prompt/settings into a
  new sequential version.
- [x] 4.4 Add approve/unapprove controls that update selected version and stage.
- [x] 4.5 Add optional “Open in ComfyUI” action for deeper review.

## 5. Continue Pipeline Gate

- [x] 5.1 Add explicit “continue pipeline” state transition after reference
  approval.
- [x] 5.2 Generate Blender reference input metadata from the approved run.
- [x] 5.3 Disable continuation until required outputs exist and next-stage
  readiness checks pass, required rigged mesh slots are assigned, and warnings
  are acknowledged.
- [x] 5.4 Add changed-path and stage-transition reporting for agent use.
- [x] 5.5 Register the final character scene, available animations, and
  secondary assets under the character folder when the downstream build
  completes.

## 6. Headless and Agent Interface

- [x] 6.1 Add commands to create/update a character draft from metadata and
  prompt inputs.
- [x] 6.2 Add commands to inspect generation state and run history as JSON.
- [x] 6.3 Add explicit commands for approved queue, approve run, and continue
  transitions.
- [x] 6.4 Add commands to inspect final character scene, animations, and
  secondary assets as JSON.
- [x] 6.5 Ensure JSON stdout is stable and free of progress/log text.

## 7. Validation and Documentation

- [x] 7.1 Add unit tests for manifest updates, project context capture, rigged
  mesh slot replacement, run history, version tags, approval gates, final asset
  registration, and output placement.
- [x] 7.2 Add integration tests with a mock ComfyUI queue/history server.
- [x] 7.3 Add editor smoke tests for draft creation, review, and continuation
  states where feasible.
- [x] 7.4 Update README and addon documentation with the Godot-first workflow.
- [x] 7.5 Run headless editor load, GDScript tests, Python parser checks, and
  `git diff --check`.

## 8. Mesh Guidance From Approved References

- [x] 8.1 Define the project-local `mesh_guidance.json` schema emitted after an
  approved reference run enters continuation.
- [x] 8.2 Populate guidance with approved reference image paths, prompt-derived
  character targets, pose contract, scale/alignment assumptions, and primary /
  secondary rigged mesh paths.
- [x] 8.3 Record secondary asset candidates and suggested sockets for props
  visible in or implied by the approved reference set.
- [x] 8.4 Add a Blender handoff command that reads the guidance artifact and
  places non-destructive reference planes against the rigged meshes.
- [x] 8.5 Add validation that source rigged meshes are preserved as immutable
  references and that downstream edits happen in generated project-local work
  files.
- [x] 8.6 Add tests for guidance artifact creation, agent-readable changed
  paths, and failure cases when approved references or rigged meshes are
  missing.

## 9. Baseline Facial Authoring

- [x] 9.1 Preserve the original Quaternius male and female body rigs and create
  duplicate-only Rigify facial-authoring experiments in `field_engineers.blend`.
- [x] 9.2 Enable Blender's bundled Rigify explicitly, generate male and female
  control rigs, and record dependency/license status without adding a runtime
  Godot dependency.
- [x] 9.3 Align generated face controls to the duplicate QTR rigs using body
  height, QTR `Head` X/Y anchoring, and `ORG-face` Z anchoring.
- [x] 9.4 Repair duplicated mesh Armature modifiers so they target duplicate
  QTR rigs while the original meshes continue targeting the original rigs.
- [x] 9.5 Limit visible Rigify collections to facial authoring controls and tag
  the generated full rigs as authoring-only and excluded from production export.
- [x] 9.6 Split the shared baseline into reproducible female and male working
  files, each containing one complete QTR character plus its matching Rigify
  facial-authoring scaffolding.
- [ ] 9.7 Fit male and female facial metarig landmarks to brows, eyelids, eyes,
  cheeks, nose, lips, jaw, ears, teeth, and tongue with artist review.
- [ ] 9.8 Add reviewed facial deformation weights or morph targets without
  replacing existing QTR body weights or production topology.
- [ ] 9.9 Add a rest-space face attachment from the fitted Rigify face chain to
  QTR `Head`; do not parent the complete Rigify object to an animated head bone.
- [ ] 9.10 Add blink, jaw-open, smile, frown, brow-raise, and eye-look validation
  poses, then define a deformation-only glTF/Godot export contract.
