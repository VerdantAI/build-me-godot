## ADDED Requirements

### Requirement: Assets Declare Taxonomy Before Generation

The system SHALL require asset-generation research plans to declare an object
taxonomy before selecting a geometry provider or production path. The taxonomy
SHALL distinguish organic, inorganic mechanical, inorganic architectural,
hybrid wearable, flexible/cloth, effect/volume, decal/marking, and unknown
mixed assets.

#### Scenario: Robot asset is not treated as organic blob

- **GIVEN** a generated reference depicts a robot or droid
- **WHEN** a representation plan is prepared
- **THEN** the asset is classified as `inorganic_mechanical` or
  `unknown_mixed` pending review
- **AND** the plan proposes separable components for shells, joints, wheels,
  cables, tubes, panels, decals, materials, pivots, sockets, and collision
  rather than a single production mesh by default.

#### Scenario: Organic asset uses mesh-first assumptions

- **GIVEN** a generated reference depicts a creature, plant, humanoid, or other
  soft organic object
- **WHEN** a representation plan is prepared
- **THEN** organic mesh or canonical-topology paths may be proposed
- **AND** hard-surface CAD or primitive paths are used only for distinct
  inorganic components such as armor, tools, or prosthetics.

### Requirement: Representation Plans Are Component-Based

The system SHALL produce a project-local representation plan that breaks an
asset into semantic components and assigns each component a representation
class before downstream geometry execution.

#### Scenario: Mechanical component receives analytic representation

- **GIVEN** a component is identified as a wheel, axle, knob, tube, cable, or
  flat panel
- **WHEN** representation planning runs
- **THEN** the plan considers primitive, lathed/revolved, curve, CAD code,
  BRep/STEP, NURBS, or hard-surface mesh representations before monolithic
  reconstruction
- **AND** records material, pivot, socket, collision, and LOD expectations.

#### Scenario: Residual mesh fallback is used

- **GIVEN** a component cannot be described by primitives, curves, CAD, NURBS,
  or hard-surface templates
- **WHEN** the planner selects `residual_reference_mesh`
- **THEN** the plan records why simpler representations were rejected
- **AND** the output remains reference-only until production topology is
  explicitly reviewed.

### Requirement: Part-Aware Providers Remain Research-Gated

The system SHALL treat PartCrafter, OmniPart, MeshArt, CAD-Recode, NURBGen,
SGS-1, Meshtron, and similar providers as research candidates until exact code,
model/data licenses, automatic-download behavior, hosted-service dependencies,
and output contracts are reviewed.

#### Scenario: Provider auto-downloads weights

- **GIVEN** a provider README or script automatically downloads model weights
- **WHEN** readiness is checked
- **THEN** the provider is not runnable by default
- **AND** the report requires manual local artifact configuration or offline
  mode before execution
- **AND** no download action runs without a later explicit setup proposal.

#### Scenario: Provider uses hosted VLM features

- **GIVEN** a provider offers part-count suggestion, style transfer, or other
  analysis through a hosted VLM/API
- **WHEN** the provider is evaluated for Build Me Godot
- **THEN** hosted features are marked out of scope for default local workflows
- **AND** local/manual alternatives remain available where the provider allows
  them.

### Requirement: Generated Code Execution Is Sandboxed

The system SHALL treat generated CAD/Python code as untrusted. It SHALL NOT run
generated CAD code inside the Godot editor process or without explicit user
approval and a reviewed sandbox contract.

#### Scenario: CAD-Recode-style provider emits CadQuery code

- **GIVEN** a procedural CAD provider emits Python or CadQuery code
- **WHEN** the output is imported into Build Me Godot
- **THEN** the code is stored as a review artifact
- **AND** no execution occurs until a sandboxed execution path is explicitly
  approved
- **AND** support reports redact local execution paths and do not include
  private generated code by default.

### Requirement: Representation Plans Drive Assembly Validation

The system SHALL validate planned assemblies for semantic part count, material
assignment, pivots, sockets, collision proxies, LOD strategy, scale, and
game-mode profile fit before any output can be promoted as production-ready.

#### Scenario: Articulated object needs pivots

- **GIVEN** a component is marked with a revolute, prismatic, hinge, wheel, or
  other articulation mode
- **WHEN** validation runs
- **THEN** the report requires pivot and axis evidence
- **AND** the component cannot be production-ready until that evidence exists.

#### Scenario: Low-poly game profile rejects dense output

- **GIVEN** an asset uses the `low_poly_high_volume` game-mode profile
- **WHEN** a provider returns dense part meshes or monolithic reconstruction
- **THEN** the scorecard records a budget conflict
- **AND** the output remains reference-only unless simplification or procedural
  regeneration satisfies the declared budget.

### Requirement: Monolithic Reconstruction Is A Fallback

The system SHALL prefer semantic parts and appropriate representations for
inorganic assets. Monolithic reconstruction SHALL be a fallback or measurement
reference, not the default production path for manufactured objects.

#### Scenario: Simple manufactured part is detected

- **GIVEN** a component can be represented as a cylinder, box, sphere, curve,
  lathed profile, bevelled panel, CAD feature, or decal
- **WHEN** the representation planner scores candidate paths
- **THEN** procedural or analytic representation receives priority over a
  dense generated triangle mesh
- **AND** any monolithic mesh output is tagged as residual reference unless
  reviewed otherwise.
