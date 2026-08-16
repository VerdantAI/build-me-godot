## ADDED Requirements

### Requirement: Isometric Character Recipe

The system SHALL define a versioned `character_recipe.json` artifact for
`3d_isometric_party` character production. The recipe SHALL translate approved
AI references and game-mode assumptions into concrete body, equipment,
material, socket, animation, LOD, validation, and output decisions.

#### Scenario: Recipe is created for approved reference run

- **GIVEN** a character has an approved reference run
- **AND** the character has a selected `3d_isometric_party` game-mode profile
- **WHEN** the user creates a character recipe
- **THEN** the system writes a versioned recipe under the character folder
- **AND** the recipe records the approved reference run, profile ID, provider
  provenance, body strategy, equipment plan, material plan, socket
  requirements, animation requirements, LOD expectations, and validation
  gates
- **AND** no external provider, model download, Blender job, or ComfyUI job
  runs unless separately approved.

#### Scenario: Recipe blocks unclear provider provenance

- **GIVEN** a recipe references a body, equipment, AI model, or proxy provider
  with unknown license state
- **WHEN** recipe validation runs
- **THEN** validation reports the provider as blocked or needing review
- **AND** the recipe cannot be promoted as a play-test-ready production
  character.

#### Scenario: Recipe rejects proxy topology promotion

- **GIVEN** a recipe references TRELLIS, TripoSR, Hunyuan3D, SMPL-X-backed, or
  other reconstruction output as a production humanoid body
- **WHEN** recipe validation runs
- **THEN** validation fails unless a separate reviewed production conversion
  path and license decision are recorded
- **AND** the output remains an immutable reference or proxy artifact by
  default.

### Requirement: AI Assistance Produces Reviewable Structured Drafts

The system SHALL use AI assistance for structured recipe drafting, references,
palettes, and material concepts. AI output SHALL be validated and reviewed
before it changes durable recipe or manifest state.

#### Scenario: Local LLM drafts recipe JSON

- **GIVEN** a local Ollama-compatible model is configured and passes readiness
  checks
- **AND** the user explicitly requests recipe assistance
- **WHEN** the system sends character context, profile data, and approved
  reference metadata to the local endpoint
- **THEN** the response is parsed as recipe JSON
- **AND** schema validation runs before any save action
- **AND** the user can inspect, edit, accept, or discard the proposed changes
- **AND** accepted recipes record model provenance.

#### Scenario: ComfyUI references are attached to recipe source data

- **GIVEN** a ComfyUI reference run produced approved images
- **WHEN** a recipe is created or updated
- **THEN** concept sheets, portraits, palettes, material references, and decal
  references may be linked as source evidence
- **AND** the recipe does not treat those images as production topology.

### Requirement: Production Body Uses Canonical Or Project-Owned Mesh

The system SHALL prefer a canonical humanoid body provider or project-owned
rigged base mesh for playable isometric humanoids. It SHALL NOT require SMPL-X
or arbitrary reconstruction meshes for the default production path.

#### Scenario: Project base body is selected

- **GIVEN** the project provides a rigged humanoid base mesh
- **WHEN** a recipe selects that mesh as the body source
- **THEN** validation checks pose contract, scale, skeleton profile, humanoid
  bone mapping, and source provenance
- **AND** downstream assembly works on duplicate project-local files rather
  than mutating the source mesh.

#### Scenario: External MPFB or MakeHuman provider is selected

- **GIVEN** the user has separately installed and configured an MPFB or
  MakeHuman-compatible Blender environment
- **WHEN** a recipe selects that provider
- **THEN** the system records readiness and provenance
- **AND** execution remains an explicit user action
- **AND** no MPFB, MakeHuman, Blender addon, Python package, or model artifact
  is installed automatically.

#### Scenario: SMPL-X-backed provider is selected

- **GIVEN** a recipe selects a provider that requires SMPL-X model/software,
  SMPL-X parameters, or SMPL-X-derived topology
- **WHEN** validation runs
- **THEN** the recipe is marked research-only unless a separate production
  license decision record explicitly permits the use
- **AND** the default play-test-ready path remains blocked.

### Requirement: Modular Equipment And Representation Planning

The system SHALL represent armor, weapons, tools, robes, helmets, backpacks,
and other character parts as modular components with explicit representation
classes, sockets, provenance, and production status.

#### Scenario: Fighter equipment plan is validated

- **GIVEN** a `party_fighter_v1` recipe defines weapon, shield, armor, and
  optional helmet components
- **WHEN** validation runs
- **THEN** required hand/head/back sockets are checked
- **AND** each component records whether it is an existing asset, primitive,
  hard-surface mesh, cloth/flexible mesh, decal, or proxy reference
- **AND** missing required equipment produces actionable warnings.

#### Scenario: Healer equipment plan is validated

- **GIVEN** a `village_healer_v1` recipe defines robe, staff, pouch, book, or
  similar components
- **WHEN** validation runs
- **THEN** cloth/flexible, hard-surface, curve, decal, and primitive
  representation choices are accepted when provenance is valid
- **AND** proxy reconstruction output remains reference-only unless reviewed.

### Requirement: Blender Assembly Produces Project-Local Work

The system SHALL provide an explicit Blender assembly step that consumes a
validated recipe and produces project-local work files, export artifacts, and
reports without mutating source providers or external tools.

#### Scenario: Assembly runs from validated recipe

- **GIVEN** a recipe passes validation
- **AND** the user explicitly starts Blender assembly
- **WHEN** the Blender job runs
- **THEN** it writes work files under the character folder
- **AND** imports or creates duplicate body/equipment work assets
- **AND** places approved reference planes when available
- **AND** verifies sockets, scale, humanoid profile expectations, and material
  placeholders
- **AND** writes a structured assembly report.

#### Scenario: Assembly attempts external mutation

- **GIVEN** a Blender assembly job would write into an external addon,
  ComfyUI directory, MPFB directory, model cache, or source asset-pack
  directory
- **WHEN** the job prepares outputs
- **THEN** the operation is blocked
- **AND** the report explains the unsafe target path.

### Requirement: Play-Test-Ready Godot Acceptance

The system SHALL accept the vertical slice only when the target characters are
importable, inspectable, and spawnable as Godot scenes with isometric
readability evidence.

#### Scenario: Character is registered as play-test ready

- **GIVEN** Blender assembly and Godot import complete for a character
- **WHEN** final registration runs
- **THEN** the character manifest records the final scene path, recipe version,
  animation paths, sockets, materials, LOD or LOD-plan evidence, preview
  thumbnails, validation report, and unresolved warnings
- **AND** the final scene lives under `res://build_me_godot/characters/`.

#### Scenario: Two-character vertical slice is complete

- **GIVEN** `party_fighter_v1` and `village_healer_v1` have registered final
  scenes
- **WHEN** the play-test fixture runs
- **THEN** both scenes load successfully
- **AND** required idle and walk animation evidence is available or explicitly
  reported as a known limitation
- **AND** isometric preview/readability evidence exists for both characters
- **AND** no research-only or unclear-license artifact is promoted as a final
  production asset.
