## ADDED Requirements

### Requirement: Character Checkpoint Index

The system SHALL define a versioned `checkpoint_index.json` artifact for each
character version. The checkpoint index SHALL record durable pipeline stages,
stage status, input dependencies, file paths, file digests, provider
provenance, license state, warnings, and review timestamps.

#### Scenario: Checkpoint index is written for a character version

- **GIVEN** a character has at least one durable pipeline artifact
- **WHEN** the system records checkpoint state
- **THEN** it writes `checkpoint_index.json` under
  `res://build_me_godot/characters/<character_id>/checkpoints/<version>/`
- **AND** the record includes the character ID, version, game-mode profile,
  schema version, and stage map
- **AND** unknown fields are preserved on update.

#### Scenario: Checkpoint status is reported

- **GIVEN** a checkpoint index exists
- **WHEN** the user requests checkpoint status
- **THEN** the system reports every known stage as `valid`, `stale`,
  `failed`, `missing`, or `pending`
- **AND** the report includes actionable warnings for stale or failed stages.

### Requirement: Reusable Base Character Checkpoint

The system SHALL allow reviewed rigged and animated base characters to be
checkpointed and reused across character iterations. A reusable base SHALL
record license state, source provenance, source digest, pose contract, scale,
skeleton profile, skeleton compatibility notes, UV assumptions, available
animation libraries, and game-mode fit.

#### Scenario: Reviewed project base is reused

- **GIVEN** a project-local rigged humanoid base has reviewed license state
- **AND** it declares `neutral_a_pose_30deg_v1`
- **AND** it is compatible with Godot `SkeletonProfileHumanoid`
- **WHEN** a character recipe selects the base
- **THEN** the base body checkpoint can be marked `valid`
- **AND** downstream assembly may reuse it without rerunning concept or
  reconstruction providers.

#### Scenario: Research-only topology is selected as a base

- **GIVEN** a base candidate comes from SMPL-X, TRELLIS, TripoSR, Hunyuan3D,
  HumanGaussian, SHERT, or another research/proxy provider
- **WHEN** the candidate lacks a separate production license and topology
  approval record
- **THEN** the checkpoint cannot mark it as a production base
- **AND** the candidate remains an immutable reference or proxy artifact.

### Requirement: Checkpoint Invalidation

The system SHALL detect stale checkpoints when upstream inputs change. It
SHALL invalidate dependent downstream stages according to recorded dependency
edges instead of silently reusing mismatched artifacts.

#### Scenario: Base body changes

- **GIVEN** a character has valid base body, assembly, Godot scene, animation
  smoke, and readability checkpoints
- **WHEN** the base body path, digest, skeleton metadata, or pose contract
  changes
- **THEN** the assembly, Godot scene, animation smoke, and readability stages
  are marked stale
- **AND** the status report explains that the base body changed.

#### Scenario: Animation library changes

- **GIVEN** a character has a valid Godot scene and animation smoke checkpoint
- **WHEN** the animation library path or digest changes
- **THEN** the Godot scene and animation smoke stages are marked stale
- **AND** unrelated concept/reference checkpoints remain valid.

### Requirement: Resume From Checkpoint

The system SHALL support resuming character work from the latest valid
checkpoint stage. Resume operations SHALL skip valid upstream stages and only
rerun explicitly requested or stale downstream stages.

#### Scenario: Resume from valid assembly

- **GIVEN** references, recipe, base body, and assembly checkpoints are valid
- **AND** the Godot scene checkpoint is stale or missing
- **WHEN** the user resumes from the Godot scene stage
- **THEN** the system reuses the existing assembly report and import asset
- **AND** it does not rerun concept generation, recipe drafting, base body
  selection, or Blender assembly.

#### Scenario: Resume would require external download

- **GIVEN** a stale checkpoint references a missing external model, tool,
  animation pack, or Blender addon
- **WHEN** the user resumes from that stage
- **THEN** the system reports the missing dependency
- **AND** it does not download, install, or mutate external tools without an
  explicit separate user action.

### Requirement: AI-Compatible Checkpoint Boundaries

The system SHALL keep AI assistance compatible with reusable base
checkpoints. AI providers MAY draft recipes, choose reviewed bases, propose
morph/material/equipment decisions, generate texture or decal maps, and
produce immutable proxy references, but SHALL NOT overwrite valid production
topology, rig, or animation checkpoints without review.

#### Scenario: AI proposes changes against a valid base

- **GIVEN** a character has a valid reviewed base checkpoint
- **WHEN** an AI recipe assistant proposes changes
- **THEN** the proposal is represented as reviewable recipe data
- **AND** it may update materials, equipment, morph targets, texture plans, or
  proxy references
- **AND** it does not replace the base mesh or skeleton unless the user
  accepts a new reviewed base candidate.

#### Scenario: AI texture output depends on base UVs

- **GIVEN** an AI texture provider creates maps for a base character
- **WHEN** the base UV layout digest changes
- **THEN** texture/material checkpoints depending on that UV layout are marked
  stale
- **AND** animation-only checkpoints are not invalidated solely by UV changes.
