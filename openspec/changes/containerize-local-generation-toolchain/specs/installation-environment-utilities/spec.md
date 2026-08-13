## MODIFIED Requirements

### Requirement: Provider Dependencies Are Managed By Installation Utilities

The installation environment utilities SHALL manage every promoted conformance
model, custom node, LoRA, adapter, provider, or optional local container
toolchain through read-only detection, install planning, explicit apply/manual
actions, changed-path reporting, license records, and verification.

#### Scenario: Promoted provider appears in readiness checks

- **GIVEN** a conformance provider is promoted from experiment to supported
  workflow dependency
- **WHEN** the user runs an environment check for conformance readiness
- **THEN** the report includes stable check IDs for required node classes,
  model artifacts, command paths, container runtime readiness when applicable,
  license records, and expected output formats
- **AND** the check does not install packages, clone repositories, download
  weights, build container images, pull container images, run containers, or
  mutate ComfyUI or Blender installations.

#### Scenario: Plan explains model and node setup

- **GIVEN** a promoted provider is missing required ComfyUI nodes, model
  artifacts, or optional container runtime readiness
- **WHEN** the user runs an install plan
- **THEN** the plan reports the action IDs, source locations, target paths,
  artifact sizes or hashes when available, license/provenance records,
  commercial-use status, risk notes, and verification checks
- **AND** the plan remains read-only.

#### Scenario: Apply is explicit and granular

- **GIVEN** a promoted provider has reviewed setup actions that are allowed by
  project policy
- **WHEN** the user explicitly applies one selected action
- **THEN** only that action is executed
- **AND** changed paths and post-action verification results are reported
- **AND** no unrelated models, nodes, Python packages, container images, or
  external addons are installed.

#### Scenario: Risky setup remains manual but verifiable

- **GIVEN** a provider requires a mutation class that has not been approved for
  automatic application
- **WHEN** the user asks for an install plan
- **THEN** the utilities emit a manual action with exact placement and
  verification criteria
- **AND** verification can later detect whether the user completed the manual
  setup.
