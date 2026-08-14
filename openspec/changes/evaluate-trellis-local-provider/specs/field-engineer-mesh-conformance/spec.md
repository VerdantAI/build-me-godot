## MODIFIED Requirements

### Requirement: Generate Local Proxy Reconstruction Outputs

The system SHALL provide an explicit command for generating immutable proxy
reconstruction meshes from prepared conformance inputs using a configured
user-managed local provider.

#### Scenario: TRELLIS provider writes proxy mesh

- **GIVEN** a conformance plan exists for an approved field-engineer reference
  version
- **AND** a user-managed TRELLIS checkout and local model folder are configured
- **AND** the TRELLIS wrapper passes its version probe
- **WHEN** the user explicitly runs proxy generation with provider `trellis`
- **THEN** the system invokes only the configured local command with declared
  input, output, and metadata paths
- **AND** writes the generated GLB beneath the project conformance proxy folder
- **AND** records TRELLIS provenance and keeps the generated mesh as immutable
  reference geometry.
