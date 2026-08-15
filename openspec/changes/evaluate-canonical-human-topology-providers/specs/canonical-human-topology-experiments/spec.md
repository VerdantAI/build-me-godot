## ADDED Requirements

### Requirement: Canonical Human Experiments Are Explicit And Local

The system SHALL model canonical-human topology experiments as explicit,
project-local workflows that do not install, download, overwrite, or configure
external tools unless a separate user-approved action is introduced by a later
change.

#### Scenario: Artist creates an experiment plan

- **GIVEN** a character manifest has an approved reference version
- **WHEN** the artist prepares a canonical-human experiment plan
- **THEN** the system writes plan artifacts beneath
  `res://build_me_godot/characters/<character_id>/canonical_human/<version>/`
- **AND** the plan records input references, requested pose contract, provider
  candidates, output contracts, validation checks, and changed paths
- **AND** no external provider, model, Python package, Blender extension, or
  dataset is installed.

#### Scenario: Missing local provider blocks execution only

- **GIVEN** a canonical-human experiment plan exists
- **AND** no user-managed provider path is configured
- **WHEN** the user requests provider execution
- **THEN** the system refuses execution with an actionable readiness report
- **AND** preserves the experiment plan for later use
- **AND** does not modify external tools.

### Requirement: Provider Candidates Have License And Provenance Records

Each canonical-human provider candidate SHALL have a reviewed provenance record
before it can appear in setup reports, execution plans, or provider scorecards.
The record SHALL distinguish code license, model/data license, generated-output
posture, commercial-use posture, automatic-download behavior, and redistribution
constraints.

#### Scenario: SMPL-X-backed provider is reviewed

- **GIVEN** a provider requires the standard SMPL-X model/software download
- **WHEN** its provenance record is created
- **THEN** the provider is marked `research_only` by default
- **AND** the record states that standard SMPL-X model/software use is
  non-commercial unless separate commercial permission is recorded
- **AND** the provider cannot be selected for commercial-default workflows.

#### Scenario: MPFB candidate is reviewed

- **GIVEN** MPFB2 or MakeHuman is considered as a provider
- **WHEN** its provenance record is created
- **THEN** the record distinguishes GPL/AGPL source-code constraints from CC0
  core graphical asset posture
- **AND** the addon does not vendor MPFB or MakeHuman source code
- **AND** generated asset provenance is recorded per output.

### Requirement: Canonical Output Contracts Are Provider-Agnostic

The system SHALL define provider-agnostic contracts for canonical-human inputs,
provider readiness, outputs, validation reports, and scorecards. Contracts SHALL
support morph parameters, neutral meshes, texture maps, residual maps, face
references, Gaussian or NeRF appearance references, and immutable-source flags.
Contracts SHALL also include a declared game assumption for each experiment.

#### Scenario: MPFB and SHERT outputs use one comparison shape

- **GIVEN** one experiment output comes from an MPFB-style morph provider
- **AND** another output comes from a SHERT-style semantic reconstruction
  provider
- **WHEN** scorecards are generated
- **THEN** both scorecards use the same required fields for provider ID,
  license status, locality, output representation, humanoid readiness, Godot
  import readiness, manual-review reasons, and evidence paths.

#### Scenario: Gaussian output is not mistaken for production mesh

- **GIVEN** a HumanGaussian-style provider produces Gaussian PLY output
- **WHEN** its output contract is written
- **THEN** the output representation is recorded as Gaussian or hybrid
  appearance data
- **AND** `production_topology_candidate` is false unless a separate reviewed
  mesh-conversion path exists.

### Requirement: Experiments Declare A Game Assumption

The system SHALL require every canonical-human research plan, provider
benchmark, and scorecard to declare a game assumption before evaluating pipeline
fitness. A game assumption SHALL define camera/readability constraints,
expected simultaneous character volume, named-character versus variant/crowd
ratio, platform or runtime pressure, asset-budget class, LOD strategy, and
minimum evidence needed for acceptance.

#### Scenario: Isometric party benchmark values silhouettes and equipment

- **GIVEN** a provider benchmark declares the `3d_isometric_party` assumption
- **WHEN** the scorecard is generated
- **THEN** the scorecard includes medium-camera readability, modular equipment
  support, portrait or dialogue close-up exceptions, LOD expectations, and
  animation-retargeting evidence
- **AND** providers are compared on party-RPG character quality rather than
  settlement-scale crowd throughput.

#### Scenario: Isometric settlement benchmark values volume

- **GIVEN** a provider benchmark declares the `3d_isometric_settlement`
  assumption
- **WHEN** the scorecard is generated
- **THEN** the scorecard includes expected simultaneous character count,
  atlas/material reuse expectations, LOD or impostor strategy, and far-camera
  readability evidence
- **AND** high-detail close-up geometry does not increase production fitness
  unless it can be reduced to the declared crowd budget.

#### Scenario: First-person VR benchmark values close inspection

- **GIVEN** a provider benchmark declares the `first_person_vr` assumption
- **WHEN** validation runs
- **THEN** the validation report includes close-camera material scale,
  hand/finger deformation, interaction anchors, collision proxies, and
  conservative LOD-transition checks
- **AND** outputs that only pass far-camera readability remain review
  references, not production-ready VR characters.

#### Scenario: First-person FPS benchmark separates body and arms

- **GIVEN** a provider benchmark declares the `first_person_fps` assumption
- **WHEN** the scorecard is generated
- **THEN** the scorecard includes world-character readiness, optional
  first-person arm readiness, weapon and equipment socket evidence,
  combat-distance silhouette evidence, and animation stress-pose validation
- **AND** providers that cannot preserve stable sockets or animation contracts
  remain reference-only for FPS production work.

#### Scenario: Low-poly benchmark values simplification

- **GIVEN** a provider benchmark declares the `low_poly_high_volume`
  assumption
- **WHEN** the scorecard is generated
- **THEN** the scorecard rewards small mesh budgets, palette/material swaps,
  deterministic variants, batching, and tiny-thumbnail readability
- **AND** dense reconstruction detail is treated as concept evidence unless a
  simplified canonical output is produced.

#### Scenario: New game mode is introduced

- **GIVEN** a researcher wants to evaluate a side-scroller, over-the-shoulder
  third-person game, tactical grid, MMO crowd, mobile game, or another mode
- **WHEN** the research plan is created
- **THEN** it defines a new game assumption with the same required budget,
  camera, volume, readability, and evidence fields
- **AND** provider comparisons are scoped to that assumption rather than mixed
  with unrelated game modes.

### Requirement: MPFB-First Prototype Preserves Humanoid Contracts

The first production-oriented prototype SHALL prioritize a separately installed
MPFB2/MakeHuman-compatible provider and validate its outputs against Build Me
Godot's stable humanoid constraints before Godot import.

#### Scenario: MPFB provider exports a neutral character

- **GIVEN** Blender 4.2 or newer is configured
- **AND** a user-managed MPFB-compatible provider is configured
- **WHEN** the user explicitly runs the MPFB-first prototype for a character
- **THEN** outputs are written under the character's project-local
  canonical-human experiment directory
- **AND** the validation report checks scale, humanoid bone/socket names,
  `neutral_a_pose_30deg_v1`, and `SkeletonProfileHumanoid` compatibility
- **AND** the provider source installation is not modified.

#### Scenario: Export violates the pose contract

- **GIVEN** a provider output exists
- **WHEN** validation detects a pose, skeleton, socket, or humanoid-profile
  mismatch
- **THEN** the output is kept as a review artifact
- **AND** the system refuses to promote it as a ready production character.

### Requirement: Research Providers Remain Disabled By Default

The system SHALL keep SHERT, HumanGaussian, HAHA, UVFaceFusion, TECA, and
similar research providers disabled by default until their exact code, weights,
data, installation mode, and output contracts have been reviewed. Providers
that require SMPL-X SHALL also require an explicit license acknowledgement
before execution.

#### Scenario: Research provider has no local checkpoints

- **GIVEN** a SHERT-style provider path is configured
- **AND** required checkpoints or SMPL-X files are absent
- **WHEN** readiness is checked
- **THEN** the provider reports missing manual artifacts
- **AND** no artifact is downloaded automatically
- **AND** unrelated MPFB-first experiments remain available.

#### Scenario: TECA code is unavailable

- **GIVEN** TECA is present only as a paper/project-page reference
- **WHEN** provider candidates are listed
- **THEN** TECA is marked concept-only
- **AND** it cannot be selected for local execution.

### Requirement: Detail Layers Do Not Replace Production Topology Automatically

The system SHALL treat face-specific, Gaussian, NeRF, residual, clothing, and
hair detail artifacts as references or manually approved secondary assets
unless a later versioned workflow defines a conventional Godot import/runtime
contract.

#### Scenario: UV face reconstruction exists

- **GIVEN** a UVFaceFusion-style provider creates a fixed-topology face mesh
  reference
- **WHEN** the experiment report is generated
- **THEN** the face mesh is recorded as a reference or blendshape suggestion
- **AND** it is not automatically merged into the production body topology.

#### Scenario: Hybrid mesh plus Gaussian output exists

- **GIVEN** a HAHA-style provider creates a textured mesh with Gaussian hair or
  clothing detail
- **WHEN** the experiment report is generated
- **THEN** the mesh and Gaussian layers are recorded separately
- **AND** only conventional mesh/material outputs with reviewed provenance can
  be considered for Godot import.
