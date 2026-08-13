## ADDED Requirements

### Requirement: Prepare Field-Engineer Conformance Plans

The system SHALL prepare a project-local conformance plan from an approved
field-engineer reference version, assigned rigged meshes, field-engineer
semantic targets, and optional user-managed reconstruction provider outputs.

#### Scenario: Approved reference creates project-local plan

- **GIVEN** a character manifest has an approved reference version
- **AND** primary and secondary rigged mesh slots are assigned
- **WHEN** the user explicitly prepares conformance for that version
- **THEN** the system writes conformance artifacts beneath
  `res://build_me_godot/characters/<character_id>/conformance/<version>/`
- **AND** the conformance plan records the approved reference image paths,
  rigged mesh paths, pose contract, provider provenance, field-engineer
  silhouette/material/prop targets, validation constraints, and changed paths.

#### Scenario: Missing approval blocks conformance

- **GIVEN** a character manifest has generated references but no approved
  reference version
- **WHEN** the user attempts to prepare conformance
- **THEN** the system refuses the transition
- **AND** reports the missing approval without writing conformance artifacts.

### Requirement: Preserve Source Meshes and Humanoid Contracts

The system SHALL treat source rigged meshes and AI reconstruction meshes as
immutable references during conformance preparation and Blender handoff.

#### Scenario: Blender handoff uses duplicate-only work files

- **GIVEN** a conformance plan references source rigged meshes and optional
  proxy reconstruction meshes
- **WHEN** Blender handoff is generated
- **THEN** source meshes and proxy meshes are imported or linked as
  reference-only objects
- **AND** editable work happens only on duplicate/generated project-local files
- **AND** validation confirms the original mesh files, stable bone names,
  sockets, `SkeletonProfileHumanoid` compatibility, and
  `neutral_a_pose_30deg_v1` contract are unchanged.

#### Scenario: Proxy mesh cannot become production topology

- **GIVEN** a proxy reconstruction mesh exists for a reference version
- **WHEN** the downstream build exports final character assets
- **THEN** the proxy mesh is excluded from production export unless an explicit
  reviewed manual asset import path has converted it into a separate approved
  secondary asset.

### Requirement: Capture Field-Engineer Targets

The system SHALL persist field-engineer-specific conformance targets for
clothing, protective equipment, materials, colors, and secondary assets.

#### Scenario: Prompt and reference metadata produce reviewable targets

- **GIVEN** an approved reference and prompt metadata describe a field engineer
- **WHEN** conformance is prepared
- **THEN** the plan records targets such as helmet/hardhat, high-visibility
  garment, work boots, gloves, utility belt, radio, clipboard/tablet, tools,
  safety glasses, badges/logos, material categories, color swatches, and
  suggested sockets
- **AND** uncertain detections are recorded as review notes rather than
  automatically generated final assets.

### Requirement: Gate Conformance Approval

The system SHALL require explicit user approval before conformance guidance can
drive downstream generated work-mesh edits.

#### Scenario: Validation reports required before approval

- **GIVEN** conformance artifacts have been prepared
- **WHEN** the user attempts to approve conformance
- **THEN** the system verifies required references, rigged mesh slots, provider
  provenance, and validation reports
- **AND** approval is blocked until required artifacts exist or warnings are
  explicitly acknowledged.
