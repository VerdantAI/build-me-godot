## ADDED Requirements

### Requirement: Humanoid Customization Is Layered

The system SHALL support meaningful humanoid customization as layered,
non-destructive changes over a reviewed rigged base. Layers SHALL include body
variant controls, material/texture identity, modular clothing or accessories,
socketed props, animation compatibility, and game-mode readability evidence.

#### Scenario: Character differs from base through visible layers

- **GIVEN** a character uses a reviewed rigged humanoid base
- **WHEN** the character is assembled for a game-mode profile
- **THEN** the output records visible customization layers
- **AND** at least material identity and one silhouette or equipment change are
  present before the character can be considered meaningfully customized.

#### Scenario: Metadata-only character is not customized

- **GIVEN** a character recipe changes only display name, prompt text, or
  manifest metadata
- **WHEN** customization validation runs
- **THEN** the character is reported as not meaningfully customized
- **AND** the report identifies missing visible layers.

### Requirement: Source Bases Are Not Mutated

The system SHALL preserve source base meshes and rigs. Customization operations
SHALL run on character-local duplicates or exported candidates under
`res://build_me_godot/characters/` or `res://build_me_godot/assets/`.

#### Scenario: Current project base is customized

- **GIVEN** a recipe selects the current project rigged base
- **WHEN** Blender assembly applies body or material customization
- **THEN** source files in addon examples or asset-library source folders are
  not modified
- **AND** customized outputs are written to the character folder.

#### Scenario: Customization would mutate source asset

- **GIVEN** a customization step attempts to write into the source base asset
  path
- **WHEN** validation or assembly detects the target path
- **THEN** the operation is blocked
- **AND** the report explains that customization must happen on a duplicate.

### Requirement: Body Variant Controls Declare Provider Limits

The system SHALL record the provider and limitations for body variant controls.
Coarse transform controls, semantic morph providers, and generated proxy
references SHALL be distinguished.

#### Scenario: Coarse project-base controls are used

- **GIVEN** the current project rigged base lacks semantic morph targets
- **WHEN** a recipe applies height, shoulder, torso, head, or limb scale
  controls
- **THEN** the customization report marks the provider as
  `project_base_transform_controls`
- **AND** records that the result is a coarse non-destructive variant rather
  than a semantic body morph.

#### Scenario: MPFB or MakeHuman controls are used

- **GIVEN** the user has explicitly configured an MPFB or MakeHuman-compatible
  environment
- **WHEN** a recipe selects that provider for body or face morphs
- **THEN** readiness, provenance, license state, pose contract, scale, and
  skeleton compatibility are recorded
- **AND** no provider installation or asset download occurs automatically.

### Requirement: Material Overrides Are First-Class Customization

The system SHALL support material and texture overrides as first-class
character customization data. Overrides SHALL resolve to known material slots
or report actionable warnings.

#### Scenario: Field engineer material palette is applied

- **GIVEN** a field-engineer recipe declares skin, hair, body, safety-yellow,
  canvas, rubber, or leather material overrides
- **WHEN** assembly runs
- **THEN** the output applies matching overrides where supported
- **AND** unresolved slots are reported without mutating source materials.

#### Scenario: Material slot is unknown

- **GIVEN** a recipe references a material slot not present on the selected
  base or equipment asset
- **WHEN** recipe or assembly validation runs
- **THEN** the warning identifies the unknown slot
- **AND** production readiness is blocked only when the slot is required.

#### Scenario: Generated material exports to Godot

- **GIVEN** Blender assembly applies a recipe material override
- **WHEN** the production GLB is exported and imported by Godot
- **THEN** the generated material is exported as non-emissive PBR material data
- **AND** Godot imports the material with emission disabled
- **AND** the result does not depend on Blender viewport lights or stale
  fallback white materials.

### Requirement: Reusable Shapes Provide Silhouette Customization

The system SHALL prefer reusable shape assets for common clothing,
accessories, hair, armor, and props that define character silhouette.

#### Scenario: Field engineer needs role-specific silhouette

- **GIVEN** a field-engineer recipe requires a hard hat, vest, tool belt, or
  hand tool
- **WHEN** reusable reviewed shapes exist for those parts
- **THEN** the recipe references them by `shape_id`
- **AND** assembly attaches them to stable sockets rather than generating new
  one-off placeholders.

#### Scenario: Only placeholder is available

- **GIVEN** no reviewed reusable shape exists for a required part
- **WHEN** a placeholder is used for blockout
- **THEN** the placeholder is marked reference-only or blockout
- **AND** the character cannot be considered production-customized by that
  placeholder alone.

#### Scenario: Placeholder equipment is excluded from production export

- **GIVEN** field-engineer equipment is still represented by procedural
  placeholder geometry
- **WHEN** production assembly exports a GLB
- **THEN** placeholder equipment is omitted from the production export
- **AND** the customization report remains `partial`
- **AND** the report identifies reusable production accessories as the next
  required step.

### Requirement: Customization Invalidates Dependent Checkpoints

The system SHALL include body variant controls, material overrides, reusable
shape references, and customization limitations in checkpoint dependencies.

#### Scenario: Material override changes

- **GIVEN** a character has valid assembly and readability checkpoints
- **WHEN** a material override changes
- **THEN** assembly and readability checkpoints become stale
- **AND** base body and approved reference checkpoints remain valid.

#### Scenario: Body variant provider changes

- **GIVEN** a character uses project-base transform controls
- **WHEN** the recipe changes to an MPFB/MakeHuman morph provider
- **THEN** base body, assembly, Godot scene, animation smoke, and readability
  checkpoints are marked stale
- **AND** validation requires provider readiness and license evidence.
