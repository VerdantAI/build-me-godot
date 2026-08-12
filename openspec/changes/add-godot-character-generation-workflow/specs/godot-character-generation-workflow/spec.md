## ADDED Requirements

### Requirement: Godot Character Drafts

The addon SHALL provide a Godot editor workflow for creating and editing a
character draft with metadata, positive prompt, negative prompt, and generation
settings before any ComfyUI run is queued.

#### Scenario: Create a draft

- **GIVEN** the user opens the Build Me Godot editor dock
- **WHEN** the user enters a valid character ID, display name, metadata,
  positive prompt, and negative prompt
- **THEN** the addon writes or updates the character manifest under
  `res://build_me_godot/characters/<character_id>/character.json`
- **AND** the addon does not write into `addons/build_me_godot/`
- **AND** no ComfyUI, Blender, or model-download action runs until explicitly
  requested.

#### Scenario: Reject invalid draft metadata

- **GIVEN** the user is editing a character draft
- **WHEN** required metadata is missing or the character ID contains invalid
  path characters
- **THEN** the dock shows actionable validation messages
- **AND** generation controls remain disabled.

### Requirement: ComfyUI Reference Runs

The addon SHALL queue the reviewed ComfyUI reference workflow only after an
explicit user action and SHALL record each run with prompt, settings,
provenance, status, and output paths.

#### Scenario: Queue a reference run

- **GIVEN** the selected character draft is valid
- **AND** reference-generation readiness checks pass
- **WHEN** the user starts generation
- **THEN** the addon records a pending run in the manifest before queueing
  ComfyUI
- **AND** the run includes workflow ID, workflow version, prompts, seed or seed
  policy, queue time, and status.

#### Scenario: Complete a reference run

- **GIVEN** a queued ComfyUI run completes successfully
- **WHEN** the addon processes the ComfyUI history/output response
- **THEN** generated outputs are copied into
  `res://build_me_godot/characters/<character_id>/references/<run_id>/`
- **AND** the manifest records project-local output paths for the run.

#### Scenario: Preserve failed run attribution

- **GIVEN** a queued ComfyUI run fails
- **WHEN** the addon records the failure
- **THEN** the manifest marks only that run as failed
- **AND** any previously approved run remains selected.

### Requirement: Reference Review and Iteration

The addon SHALL let users review generated reference outputs, inspect run
history, edit prompts, rerun, and approve exactly one selected reference run for
pipeline continuation.

#### Scenario: Review output in Godot

- **GIVEN** a character has at least one completed reference run
- **WHEN** the user selects that run in the dock
- **THEN** the dock displays the contact sheet or named view outputs
- **AND** the dock displays the run prompt/settings beside the output.

#### Scenario: Iterate prompt without overwriting history

- **GIVEN** a completed run exists
- **WHEN** the user edits the prompt and starts another generation
- **THEN** the addon creates a new run ID
- **AND** previous run outputs and provenance remain available for review.

#### Scenario: Approve a reference run

- **GIVEN** a completed run has required reference outputs
- **WHEN** the user approves that run
- **THEN** the manifest records the run as the selected reference set
- **AND** the character stage advances to reference approved or equivalent.

### Requirement: Explicit Pipeline Continuation

The addon SHALL require a separate user approval before continuing from
approved reference images into Blender preparation, rigging, validation, or
Godot import work.

#### Scenario: Disable continuation before approval

- **GIVEN** no completed run is approved
- **WHEN** the user views pipeline controls
- **THEN** continuation controls are disabled
- **AND** the dock explains which reference approval requirement is missing.

#### Scenario: Continue after approval

- **GIVEN** a completed run is approved
- **AND** next-stage readiness checks pass or warnings are acknowledged
- **WHEN** the user enables continuation
- **THEN** the addon writes Blender reference input metadata under the
  character folder
- **AND** the manifest records the stage transition and changed paths.

### Requirement: Agent-Readable Workflow State

The addon SHALL expose character draft, run history, approval state, and
continuation state through deterministic project-local files and headless JSON
commands suitable for coding agents.

#### Scenario: Inspect workflow state as JSON

- **GIVEN** a character draft exists
- **WHEN** an agent runs the headless inspect command
- **THEN** stdout contains parseable JSON with schema version, character ID,
  stage, run list, selected run ID, output paths, and available actions
- **AND** progress, logs, and human prose are not emitted to stdout.

#### Scenario: Apply approved transition as an agent

- **GIVEN** a user has approved a specific transition action ID
- **WHEN** an agent runs the matching headless apply command
- **THEN** the command reports changed paths in JSON
- **AND** no unrelated generation, Blender, model-download, or external setup
  action runs.
