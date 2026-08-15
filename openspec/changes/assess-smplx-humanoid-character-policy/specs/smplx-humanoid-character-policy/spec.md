## ADDED Requirements

### Requirement: SMPL-X Current-Use Audit

The system SHALL provide a repeatable audit for SMPL-X use before any SMPL-X
backed humanoid workflow can be promoted. The audit SHALL distinguish research
references from runtime dependencies, bundled files, local path requirements,
derived outputs, and unknown provenance.

#### Scenario: Repository contains only research references

- **GIVEN** SMPL-X terms appear only in OpenSpec or documentation research
  notes
- **WHEN** the audit runs
- **THEN** the report classifies the repository posture as
  `research_reference`
- **AND** states that no shipped implicit SMPL-X runtime use was detected
- **AND** no production provider is enabled by that finding.

#### Scenario: Addon code introduces an SMPL-X import

- **GIVEN** addon code imports SMPL-X software, requires an SMPL-X model path,
  or references SMPL-X files for runtime behavior
- **WHEN** the audit runs
- **THEN** the report classifies the finding as `requires_local_smplx` or
  `bundled_or_redistributed`
- **AND** release validation fails until a reviewed license decision record
  exists.

#### Scenario: Provider output has unclear SMPL-X provenance

- **GIVEN** a provider output or sample asset may be derived from SMPL-X
- **WHEN** provenance cannot be established
- **THEN** the artifact is classified as `unknown_needs_review`
- **AND** it cannot be promoted as a production humanoid character.

### Requirement: SMPL-X License Posture Is Explicit

The system SHALL record a license posture before invoking, wrapping, detecting,
or promoting SMPL-X-backed workflows. The posture SHALL distinguish full
SMPL-X model/software use from SMPL-X Body outputs and SHALL not treat those as
equivalent permissions.

#### Scenario: Standard SMPL-X model/software is configured

- **GIVEN** a user configures a local standard SMPL-X model/software path
- **WHEN** a provider readiness check evaluates that path
- **THEN** the provider is marked `research_only` by default
- **AND** the readiness report states that production/commercial use requires
  separate permission
- **AND** no automatic download, install, or redistribution action is offered.

#### Scenario: Commercial permission is recorded

- **GIVEN** a user records that a project has commercial SMPL-X permission
- **WHEN** the addon validates the license decision record
- **THEN** the record captures scope, allowed workflow type, attribution needs,
  expiry/review date if known, and redacted evidence metadata
- **AND** private contract text is not required in support reports by default.

#### Scenario: SMPL-X Body output is imported

- **GIVEN** an imported artifact claims SMPL-X Body CC-BY output status
- **WHEN** the artifact is registered
- **THEN** the manifest records attribution requirements and source provenance
- **AND** the system does not infer permission to use or redistribute the full
  SMPL-X model/software.

### Requirement: SMPL-X Remains Disabled For Default Production

The system SHALL keep SMPL-X-backed workflows disabled for default production
humanoid characters unless a later decision record explicitly approves a
commercial-license-enabled or otherwise compatible path.

#### Scenario: Default character pipeline runs

- **GIVEN** the user creates a normal Build Me Godot character draft
- **WHEN** no reviewed SMPL-X production permission exists
- **THEN** the pipeline uses non-SMPL-X defaults
- **AND** SMPL-X-backed providers are not selected automatically
- **AND** current humanoid contracts, including Godot `SkeletonProfileHumanoid`,
  remain authoritative.

#### Scenario: Research-only SMPL-X output exists

- **GIVEN** a research-only SMPL-X-backed provider produced a mesh, parameter
  set, texture, render, or scorecard
- **WHEN** the user attempts to register it as a final character asset
- **THEN** the system blocks promotion
- **AND** reports the research-only license state and required decision record.

### Requirement: SMPL-X Provider Boundaries Are User-Managed

The system SHALL require SMPL-X-backed experiments to use user-managed local
installations and explicit user actions. The addon SHALL NOT clone SMPL-X
repositories, download model files, install Python packages, install Blender
extensions, or bundle SMPL-X artifacts.

#### Scenario: Local SMPL-X provider is missing

- **GIVEN** a SHERT, HumanGaussian, HAHA, TECA-style, or other SMPL-X-backed
  provider is selected for research
- **AND** the configured local SMPL-X files are absent
- **WHEN** readiness is checked
- **THEN** the report identifies the missing manual requirement
- **AND** no download or install action is run
- **AND** unrelated non-SMPL-X workflows remain available.

#### Scenario: Provider has transitive SMPL-X dependency

- **GIVEN** a provider does not ship SMPL-X but requires SMPL-X files at runtime
- **WHEN** provider metadata is recorded
- **THEN** the transitive SMPL-X requirement is represented explicitly
- **AND** provider scorecards and manifests carry the SMPL-X license posture.

### Requirement: SMPL-X Research Is Game-Mode Scoped

The system SHALL evaluate SMPL-X usefulness under declared game-mode profiles
rather than as a generic humanoid-quality score.

#### Scenario: VR research values hands and close inspection

- **GIVEN** an SMPL-X-backed experiment declares `first_person_vr`
- **WHEN** the scorecard is generated
- **THEN** hands, face, material scale, interaction anchors, and close-up
  deformation are evaluated
- **AND** license posture remains part of the result.

#### Scenario: Low-poly research values budget compatibility

- **GIVEN** an SMPL-X-backed experiment declares `low_poly_high_volume`
- **WHEN** the scorecard is generated
- **THEN** the report evaluates whether SMPL-X detail can be reduced to the
  declared mesh, texture, rig, batching, and LOD budgets
- **AND** dense research output remains reference-only unless a compatible
  simplification path and license record exist.
