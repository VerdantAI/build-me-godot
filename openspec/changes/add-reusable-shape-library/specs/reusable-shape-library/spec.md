## ADDED Requirements

### Requirement: Reusable Shape Library

The system SHALL support a project-local reusable shape library for common
character accessories, props, and hard-surface components. Reusable shape
assets SHALL be stored under `res://build_me_godot/assets/` and SHALL NOT be
stored inside `addons/build_me_godot/`.

#### Scenario: Common accessory is available in the library

- **GIVEN** a character recipe requests a hard hat
- **AND** the reusable shape library contains a reviewed production-ready
  `hard_hat` shape compatible with the character's game-mode profile
- **WHEN** assembly planning runs
- **THEN** the system selects the reusable shape by ID
- **AND** it does not invoke procedural generation or AI reconstruction for
  that hard hat by default.

#### Scenario: Addon package remains self-contained

- **GIVEN** a reusable shape is imported from a third-party asset pack
- **WHEN** the asset is staged for project use
- **THEN** the model files, textures, previews, and license evidence are
  stored under `res://build_me_godot/assets/`
- **AND** addon code stores only schemas, UI, import helpers, and metadata
  templates.

### Requirement: Shape Metadata Records Provenance

The system SHALL record provenance and license metadata for every reusable
shape before it can be used as production-ready. Metadata SHALL include source
provider, source URL or local source note, license, license review status,
review timestamp, source digest, imported digest, semantic tags, game-mode fit,
and production status.

#### Scenario: Shape lacks license review

- **GIVEN** a reusable shape candidate has no reviewed license state
- **WHEN** a recipe selects it for a production assembly
- **THEN** validation fails the production readiness check
- **AND** the shape may only be used as `candidate`, `blockout`, or
  `reference_only`.

#### Scenario: Shape has reviewed permissive license

- **GIVEN** a reusable shape has a reviewed CC0 or otherwise compatible
  permissive license record
- **AND** its source and imported digests are recorded
- **WHEN** a recipe selects it
- **THEN** the shape may satisfy production asset requirements if geometry,
  scale, socket, material, collision, and game-mode validation also pass.

### Requirement: Recipes Reference Shapes By Stable ID

Character and asset recipes SHALL reference reusable shapes by stable
`shape_id` rather than copying or regenerating common geometry inline.
Recipes MAY provide transform, material, LOD, and socket overrides.

#### Scenario: Multiple characters share one hard hat

- **GIVEN** `field_engineer` and `foreman` both require a hard hat
- **WHEN** both recipes resolve equipment
- **THEN** both recipes reference the same reusable `shape_id`
- **AND** each recipe may apply its own material or transform overrides
- **AND** the source model is not duplicated as independent generated output.

#### Scenario: Shape override changes

- **GIVEN** a recipe references a reusable clipboard shape
- **WHEN** only the clipboard transform override changes
- **THEN** the reusable shape asset remains valid
- **AND** only dependent assembly/readability outputs need refresh.

### Requirement: Search And Reuse Precede Generation

The system SHALL attempt reusable-shape lookup and reviewed asset import
planning before procedural generation or AI generation for common objects.

#### Scenario: Requested object is common

- **GIVEN** a recipe requests a common hard-surface object such as a hard hat,
  tool, belt, clipboard, boot, pouch, cable, wheel, crate, barrel, or panel
- **WHEN** no project-local reusable shape matches
- **THEN** the system records an asset-search/import recommendation
- **AND** it does not automatically download external assets
- **AND** procedural or AI generation remains an explicit fallback.

#### Scenario: Procedural placeholder is used

- **GIVEN** no reviewed reusable shape is available
- **AND** the user allows a procedural blockout
- **WHEN** the assembly script creates a placeholder shape
- **THEN** the output is marked `blockout` or `reference_only`
- **AND** it is excluded from production export unless explicit promotion
  evidence is recorded.

### Requirement: Shape Dependencies Invalidate Checkpoints

The system SHALL include reusable shape IDs and digests in character checkpoint
dependencies. Assemblies depending on a reusable shape SHALL become stale when
that shape's production asset, metadata, or digest changes.

#### Scenario: Reusable shape model changes

- **GIVEN** a character assembly checkpoint depends on `hard_hat_basic`
- **WHEN** the imported hard-hat GLB digest changes
- **THEN** the assembly, Godot import, animation smoke where relevant, and
  readability checkpoints are marked stale
- **AND** unrelated concept/reference checkpoints remain valid.

#### Scenario: Shape metadata changes license status

- **GIVEN** a character uses a reusable shape previously marked
  `production_ready`
- **WHEN** the shape license status changes to `rejected` or
  `review_required`
- **THEN** production readiness validation fails
- **AND** the report identifies every dependent character/version.

### Requirement: Reusable Shapes Declare Game-Mode Fit

Reusable shapes SHALL declare game-mode fit metadata including polygon budget,
texture budget, readability intent, LOD availability, collision strategy, and
intended camera distance or interaction distance where applicable.

#### Scenario: Isometric profile selects low-detail accessory

- **GIVEN** a 3D isometric party or settlement game-mode profile
- **WHEN** the system selects a reusable hard hat
- **THEN** it prefers a readable low-to-mid detail shape with appropriate LODs
- **AND** it warns if the only available shape is too dense for the declared
  screen size or character count.

#### Scenario: First-person profile requires close-up quality

- **GIVEN** a first-person or VR game-mode profile
- **WHEN** the system selects a reusable handheld tool
- **THEN** it requires closer inspection metadata, stronger material fidelity,
  and collision/interaction notes than an isometric-only prop.
