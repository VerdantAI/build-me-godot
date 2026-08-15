## ADDED Requirements

### Requirement: Game-Mode Profile Capture

The addon SHALL capture a game-mode profile as part of Godot-owned project and
character workflow state. The profile SHALL identify camera/readability
assumptions, expected character volume, asset-budget class, LOD strategy,
validation priorities, source, and notes.

#### Scenario: Project default profile is selected

- **GIVEN** the user opens the Build Me Godot editor dock
- **WHEN** no project game-mode profile exists
- **THEN** the dock offers baseline profile presets including
  `3d_isometric_party`, `3d_isometric_settlement`, `first_person_vr`,
  `first_person_fps`, `low_poly_high_volume`, and `custom`
- **AND** selecting a preset writes project-local profile data under
  `res://build_me_godot/project/`
- **AND** no external generation, setup, download, or model action runs.

#### Scenario: Character inherits project profile

- **GIVEN** a project default game-mode profile exists
- **WHEN** the user creates a character draft
- **THEN** the character draft records a profile snapshot or reference
- **AND** the dock shows that the character is using the project default
- **AND** prompts and generation settings remain editable by the user.

#### Scenario: Character overrides project profile

- **GIVEN** a character draft inherits the project profile
- **WHEN** the user selects a different profile for that character
- **THEN** the manifest records the character-specific override
- **AND** the dock exposes a reset-to-project-default action
- **AND** previously approved runs are not rewritten.

### Requirement: Custom Game-Mode Survey

The addon SHALL provide a structured survey for custom or mixed game modes. The
survey SHALL save validated structured profile fields rather than only freeform
notes.

#### Scenario: User defines a custom profile

- **GIVEN** the user selects `custom` or chooses to refine a preset
- **WHEN** the user answers survey questions for camera, character volume,
  named-versus-variant mix, target platform pressure, close-up needs,
  modular-equipment needs, budget classes, and LOD strategy
- **THEN** the addon validates the answers
- **AND** writes a custom profile to project-local storage
- **AND** reports validation warnings without modifying external tools.

#### Scenario: Custom profile is incomplete

- **GIVEN** the user is editing a custom profile
- **WHEN** required fields are missing or budget values are invalid
- **THEN** the dock shows actionable validation messages
- **AND** downstream generation or continuation actions that depend on the
  profile remain disabled
- **AND** unrelated draft editing remains available.

### Requirement: Optional Local Ollama Profile Assistance

The addon SHALL treat Ollama-assisted game-mode profiling as an optional
local-only drafting aid. It SHALL NOT require Ollama for dropdown or survey
profile creation, and SHALL NOT install, pull, download, or start Ollama or any
model.

#### Scenario: Ollama is available for profile drafting

- **GIVEN** a configured local Ollama endpoint and model pass readiness checks
- **AND** the user explicitly requests assisted profile drafting
- **WHEN** the addon sends project context and user-entered survey answers to
  Ollama
- **THEN** the request uses only the configured local endpoint
- **AND** the response is parsed as structured profile JSON
- **AND** the proposed profile is shown for review before it can be saved
- **AND** accepted profiles record Ollama model provenance.

#### Scenario: Ollama is unavailable

- **GIVEN** Ollama is not configured, unreachable, or missing the requested
  local model
- **WHEN** the user edits a game-mode profile
- **THEN** dropdown presets and the structured survey remain available
- **AND** the dock reports Ollama assistance as optional unavailable
- **AND** no model is downloaded or pulled automatically.

#### Scenario: Ollama proposes invalid JSON

- **GIVEN** Ollama assistance returns malformed or schema-invalid content
- **WHEN** the addon validates the response
- **THEN** the proposal is rejected as a draft
- **AND** no durable profile is changed
- **AND** the user can continue with manual survey controls.

### Requirement: Game-Mode Profile Propagates To Pipeline Artifacts

The addon SHALL propagate the selected game-mode profile into prompt defaults,
reference generation hints, mesh guidance, conformance plans, provider
scorecards, and validation reports without overwriting explicit user choices.

#### Scenario: Profile influences reference-generation defaults

- **GIVEN** a character draft has a selected game-mode profile
- **WHEN** the user prepares reference generation
- **THEN** the dock derives non-destructive prompt hints and default
  validation priorities from that profile
- **AND** explicit positive and negative prompt text remains user-owned draft
  state.

#### Scenario: Profile is included in mesh guidance

- **GIVEN** a completed reference run is approved
- **AND** the character has a selected game-mode profile
- **WHEN** continuation writes Blender handoff and mesh-guidance artifacts
- **THEN** those artifacts include the profile snapshot, budget assumptions,
  readability expectations, and validation priorities
- **AND** downstream tooling can report conflicts such as dense output for
  low-poly/high-volume or insufficient hand evidence for first-person VR.

#### Scenario: Provider scorecard uses the profile

- **GIVEN** a canonical-human provider experiment is attached to a character
  draft
- **WHEN** the provider scorecard is generated
- **THEN** the scorecard includes the selected profile ID and budget
  assumptions
- **AND** providers are not compared across unrelated game modes unless the
  report contains an explicit cross-mode comparison note.

### Requirement: Agents Can Inspect And Apply Profiles

The addon SHALL expose game-mode profile state through deterministic
project-local files and headless JSON commands.

#### Scenario: Agent inspects profile state

- **GIVEN** a project or character game-mode profile exists
- **WHEN** an agent runs the headless profile inspect command
- **THEN** stdout contains parseable JSON with schema version, profile source,
  selected preset or custom fields, validation status, changed paths, and
  available actions
- **AND** progress logs and human prose are not emitted to stdout.

#### Scenario: Agent applies a preset

- **GIVEN** a valid baseline profile ID is supplied
- **WHEN** an agent runs the approved headless set-preset command
- **THEN** the profile is written to project-local storage
- **AND** the command reports changed paths in JSON
- **AND** no generation, Blender, setup, download, or Ollama action runs.
