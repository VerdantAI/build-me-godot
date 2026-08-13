## ADDED Requirements

### Requirement: Godot Character Drafts

The addon SHALL provide a Godot editor workflow for creating and editing a
character draft with project-context metadata, replaceable rigged mesh inputs,
positive prompt, negative prompt, and generation settings before any ComfyUI
run is queued.

#### Scenario: Create a draft

- **GIVEN** the user opens the Build Me Godot editor dock
- **WHEN** the addon can infer project context from the open Godot project
- **THEN** the dock displays inferred project metadata and default workspace
  values before generation.

#### Scenario: Replace project rigged meshes

- **GIVEN** the user opens the Build Me Godot editor dock
- **WHEN** the pipeline requires two rigged mesh inputs
- **THEN** the dock displays both current rigged mesh assignments
- **AND** the user can replace each assignment with a project-specific rigged
  mesh before continuing.

#### Scenario: Create a draft

- **GIVEN** the user opens the Build Me Godot editor dock
- **WHEN** the user enters a valid character ID or character name, display
  name, required metadata not inferred from the project, positive prompt, and
  negative prompt
- **THEN** the addon writes or updates the character manifest under
  `res://build_me_godot/characters/<character_id>/character.json`
- **AND** the prompts are saved for later reuse
- **AND** the addon does not write into `addons/build_me_godot/`
- **AND** no ComfyUI, Blender, or model-download action runs until explicitly
  requested.

#### Scenario: Reject invalid draft metadata

- **GIVEN** the user is editing a character draft
- **WHEN** required metadata is missing, a required rigged mesh slot is
  unassigned, or the character ID contains invalid path characters
- **THEN** the dock shows actionable validation messages
- **AND** generation controls remain disabled.

### Requirement: ComfyUI Reference Runs

The addon SHALL queue the reviewed ComfyUI reference workflow only after an
explicit user action and SHALL record each run with prompt, settings,
provenance, sequential version tag, status, and output paths.

#### Scenario: Queue a reference run

- **GIVEN** the selected character draft is valid
- **AND** reference-generation readiness checks pass
- **WHEN** the user starts generation
- **THEN** the addon assigns the next sequential version tag
- **AND** the addon records a pending run in the manifest before queueing
  ComfyUI
- **AND** the run includes workflow ID, workflow version, prompts, seed or seed
  policy, queue time, version tag, and status.

#### Scenario: Complete a reference run

- **GIVEN** a queued ComfyUI run completes successfully
- **WHEN** the addon processes the ComfyUI history/output response
- **THEN** generated outputs are copied into
  `res://build_me_godot/characters/<character_id>/references/<version>/`
- **AND** the manifest records project-local output paths for the run.

#### Scenario: Assign sequential version tags

- **GIVEN** a character already has runs tagged `v1` and `v2`
- **WHEN** the user starts another generation
- **THEN** the addon tags the new run as `v3`
- **AND** no previous run output or prompt is overwritten.

#### Scenario: Preserve failed run attribution

- **GIVEN** a queued ComfyUI run fails
- **WHEN** the addon records the failure
- **THEN** the manifest marks only that run as failed
- **AND** any previously approved run remains selected.

### Requirement: Reference Review and Iteration

The addon SHALL let users review generated reference outputs, inspect run
history, edit prompts, rerun, and approve exactly one selected reference run for
pipeline continuation.

#### Scenario: Import tuned ComfyUI prompt fields

- **GIVEN** the user tuned a packaged workflow in ComfyUI and exported workflow
  JSON
- **WHEN** the user imports that workflow into the character draft
- **THEN** the addon copies supported prompt fields, negative prompt, seed, and
  character name into the Godot draft for review
- **AND** the draft remains the source of truth for future headless queueing.

#### Scenario: Review output in Godot

- **GIVEN** a character has at least one completed reference run
- **WHEN** the user selects that run in the dock
- **THEN** the dock displays the contact sheet or named view outputs
- **AND** the dock displays the run prompt/settings beside the output.

#### Scenario: Iterate prompt without overwriting history

- **GIVEN** a completed run exists
- **WHEN** the user edits the prompt and starts another generation
- **THEN** the addon creates a new run ID and next sequential version tag
- **AND** previous run outputs and provenance remain available for review.

#### Scenario: Snapshot queued workflow

- **GIVEN** a valid character draft is queued from Godot
- **WHEN** the addon sends the configured workflow to ComfyUI
- **THEN** the run records the ComfyUI prompt ID when available
- **AND** the configured API workflow snapshot is saved under the character
  folder with a content hash and source workflow path.

#### Scenario: Approve a reference run

- **GIVEN** a completed run has required reference outputs
- **WHEN** the user approves that run
- **THEN** the manifest records the run version as the selected reference set
- **AND** the character stage advances to reference approved or equivalent.

### Requirement: Explicit Pipeline Continuation

The addon SHALL require a separate user approval before continuing from
approved reference images into Blender preparation, rigging, validation, or
Godot import work, and SHALL produce a project-local playable character scene
with animations and secondary assets when the downstream pipeline completes.

#### Scenario: Disable continuation before approval

- **GIVEN** no completed run is approved
- **WHEN** the user views pipeline controls
- **THEN** continuation controls are disabled
- **AND** the dock explains which reference approval requirement is missing.

#### Scenario: Disable continuation before rigged meshes are assigned

- **GIVEN** a completed run is approved
- **AND** a required rigged mesh slot is unassigned
- **WHEN** the user views pipeline controls
- **THEN** continuation controls are disabled
- **AND** the dock explains which rigged mesh assignment is missing.

#### Scenario: Continue after approval

- **GIVEN** a completed run is approved
- **AND** next-stage readiness checks pass or warnings are acknowledged
- **WHEN** the user enables continuation
- **THEN** the addon writes Blender reference input metadata under the
  character folder
- **AND** the addon writes mesh-guidance metadata that maps approved reference
  outputs to the primary and secondary rigged mesh inputs
- **AND** the manifest records the stage transition and changed paths.

#### Scenario: Generate mesh guidance from approved references

- **GIVEN** a completed reference run is approved
- **AND** primary and secondary rigged mesh inputs are assigned
- **WHEN** the continuation stage prepares Blender handoff files
- **THEN** the addon writes a project-local mesh guidance artifact containing
  approved reference paths, rigged mesh paths, pose contract, view placement
  hints, scale/alignment assumptions, prompt-derived style targets, and
  secondary asset candidates
- **AND** the guidance artifact states that source rigged meshes are immutable
  references and must not be overwritten by downstream automation.

#### Scenario: Block mesh guidance without required inputs

- **GIVEN** a completed reference run is approved
- **WHEN** approved reference outputs or required rigged mesh inputs are missing
- **THEN** continuation remains blocked
- **AND** the dock or headless command reports which input is missing
- **AND** no Blender handoff artifact is written.

#### Scenario: Register final character assets

- **GIVEN** the downstream Blender/Godot build completes successfully
- **WHEN** the addon imports the result into the project
- **THEN** a final character scene is available under the character folder
- **AND** available animations are referenced from the manifest
- **AND** secondary assets such as helmets, swords, clipboards, or other props
  are available as project-local scenes or resources.

### Requirement: Agent-Readable Workflow State

The addon SHALL expose character draft, run history, approval state, and
continuation state through deterministic project-local files and headless JSON
commands suitable for coding agents.

#### Scenario: Inspect workflow state as JSON

- **GIVEN** a character draft exists
- **WHEN** an agent runs the headless inspect command
- **THEN** stdout contains parseable JSON with schema version, character ID,
  stage, rigged mesh assignments, run list, selected version, output paths,
  final scene path, animation paths, secondary asset paths, and available
  actions
- **AND** progress, logs, and human prose are not emitted to stdout.

#### Scenario: Apply approved transition as an agent

- **GIVEN** a user has approved a specific transition action ID
- **WHEN** an agent runs the matching headless apply command
- **THEN** the command reports changed paths in JSON
- **AND** no unrelated generation, Blender, model-download, or external setup
  action runs.
