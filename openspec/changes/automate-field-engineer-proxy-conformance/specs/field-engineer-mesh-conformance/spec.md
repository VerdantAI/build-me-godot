## ADDED Requirements

### Requirement: Generate Local Proxy Reconstruction Outputs

The system SHALL provide an explicit command for generating immutable proxy
reconstruction meshes from prepared conformance inputs using a configured
user-managed local provider.

#### Scenario: Configured provider writes proxy mesh

- **GIVEN** a conformance plan exists for an approved field-engineer reference
  version
- **AND** `provider_inputs.json` contains a usable reconstruction input image
- **AND** a reviewed provider command is configured for a supported provider
- **WHEN** the user explicitly runs proxy generation for that provider
- **THEN** the system invokes only the configured local command with declared
  input, output, and metadata paths
- **AND** writes proxy outputs beneath
  `res://build_me_godot/characters/<character_id>/conformance/<version>/proxy_meshes/`
- **AND** records provider provenance, license record, input path, output path,
  command result, and changed paths in project-local artifacts.

#### Scenario: Missing provider command blocks automated proxy generation

- **GIVEN** conformance artifacts exist
- **AND** no supported reconstruction command is configured
- **WHEN** the user attempts automated proxy generation
- **THEN** the system refuses the operation without modifying external tools
- **AND** reports that manual proxy import or provider configuration is
  required.

#### Scenario: Provider failure is captured without approving conformance

- **GIVEN** proxy generation has been requested
- **WHEN** the provider command exits non-zero or does not write the expected
  mesh
- **THEN** the system records a failed provider attempt in the conformance
  reports
- **AND** does not mark conformance as proxy-generated or approved.

### Requirement: Emit Duplicate-Only Automated Conformance Guidance

The system SHALL derive automated conformance guidance from approved reference
images, source rigged meshes, field-engineer semantic targets, and immutable
proxy meshes without mutating source topology or skeleton contracts.

#### Scenario: Blender handoff includes proxy-measured guidance

- **GIVEN** a conformance plan references source rigged meshes and generated
  proxy meshes
- **WHEN** the Blender handoff command runs
- **THEN** proxy meshes are imported as reference-only objects
- **AND** duplicate work meshes are used for editable conformance experiments
- **AND** the handoff emits a guidance report with silhouette or bounds deltas,
  clothing shell candidates, prop/socket candidates, material targets,
  warnings, and changed paths
- **AND** source rigged meshes, source skeletons, sockets, and proxy meshes are
  excluded from production export.

#### Scenario: Guidance blocks source-rig mutation

- **GIVEN** an automated guidance pass determines that satisfying a reference
  would require changing stable bones, sockets, humanoid profile compatibility,
  or the pose contract
- **WHEN** the guidance report is written
- **THEN** the report marks that item as a blocker or manual-review warning
- **AND** no conformance approval is granted automatically.
