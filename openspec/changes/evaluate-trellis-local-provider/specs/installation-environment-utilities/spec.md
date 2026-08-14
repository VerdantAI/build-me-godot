## MODIFIED Requirements

### Requirement: Provider Dependencies Are Managed By Installation Utilities

The installation environment utilities SHALL manage every promoted conformance
model, custom node, LoRA, adapter, provider, or optional local container
toolchain through read-only detection, install planning, explicit apply/manual
actions, changed-path reporting, license records, and verification.

#### Scenario: Experimental TRELLIS provider is detectable but not installed

- **GIVEN** TRELLIS is promoted as an experimental local proxy provider
- **WHEN** the user runs the setup utility plan
- **THEN** the report includes stable checks for TRELLIS checkout path, local
  image-model folder, wrapper availability, license records, expected GLB
  output, and command version probing
- **AND** the setup utility provides a manual remediation action with reviewed
  source URLs, configuration keys, and local-only constraints
- **AND** the setup utility does not clone TRELLIS, install Python packages,
  download model weights, or mutate ComfyUI or Blender.
