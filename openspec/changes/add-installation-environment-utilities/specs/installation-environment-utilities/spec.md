## ADDED Requirements

### Requirement: Environment checks are local, read-only, and repeatable

The addon SHALL provide an environment check operation that inspects only the
current Godot project, configured local executables, configured local assets,
installed addons, and user-configured service endpoints. Running a check SHALL
NOT install, download, overwrite, or reconfigure any component.

#### Scenario: Artist opens setup on a new project

- **GIVEN** Build Me Godot is enabled in a project with no configured external
  dependencies
- **WHEN** the artist runs the environment check
- **THEN** the operation completes without modifying external tools or project
  settings
- **AND** required missing capabilities are reported with remediation
- **AND** optional missing tools do not make unrelated workflows fail.

#### Scenario: Agent repeats the same check

- **GIVEN** the relevant project files, settings, processes, and endpoints have
  not changed
- **WHEN** an agent runs the same capability check twice
- **THEN** both reports contain equivalent ordered check results apart from
  documented volatile fields such as timestamp and elapsed time.

### Requirement: Readiness is evaluated per workflow capability

The checker SHALL evaluate required and optional dependencies against a
requested workflow capability rather than returning one global installed
boolean.

#### Scenario: Canonical generation is ready without Gator

- **GIVEN** Godot, the project workspace, ComfyUI, canonical workflow nodes,
  and canonical model artifacts pass their checks
- **AND** Gator Model Studio is not installed
- **WHEN** readiness is requested for `canonical_generation`
- **THEN** canonical generation is reported ready
- **AND** Gator is reported only as an optional last-mile capability.

#### Scenario: Multiview model is missing

- **GIVEN** canonical generation requirements pass
- **AND** the configured Qwen image-edit artifact is missing
- **WHEN** readiness is requested for `multiview_generation`
- **THEN** multiview generation fails its required model-artifact check
- **AND** the report does not claim canonical generation is broken.

### Requirement: Reports use one versioned machine-readable contract

Every check SHALL produce a normalized result with a stable ID, capability,
status, importance, summary, detected value, expected value, evidence, and
zero or more remediation IDs. An environment report SHALL declare its schema
version and overall readiness.

#### Scenario: Agent parses a partial environment

- **GIVEN** Blender is installed but ComfyUI is unreachable
- **WHEN** an agent requests JSON for capability `all`
- **THEN** stdout contains one valid JSON document
- **AND** Blender and ComfyUI results have stable distinct IDs
- **AND** the ComfyUI result identifies local reachability as the failed check
- **AND** the output contains no ANSI formatting or human progress lines.

#### Scenario: Human saves a report

- **GIVEN** the editor displays an environment report
- **WHEN** the artist saves that report as JSON
- **THEN** it conforms to the same schema and readiness rules as CLI JSON for
  the same checks.

### Requirement: Human diagnostics are concise and actionable

The editor SHALL present readiness grouped by workflow stage with readable
status, detected evidence, impact, and remediation. Status SHALL NOT depend on
color alone, and detailed technical evidence SHALL remain available without
dominating the default view.

#### Scenario: Blender executable is incompatible

- **GIVEN** the configured executable starts but reports an unsupported Blender
  version
- **WHEN** the artist views Blender build readiness
- **THEN** the setup view identifies the detected and minimum versions
- **AND** explains that generation outputs are unaffected but Blender builds
  are blocked
- **AND** provides a copyable configuration or installation instruction.

### Requirement: Agent diagnostics have documented invocation and exit codes

The addon SHALL provide a headless interface for checking, planning, applying
explicitly selected actions, and verifying an environment. It SHALL support
deterministic text and JSON formats and documented process exit codes.

Configuration SHALL resolve from command-line overrides, environment variables,
a gitignored project-local configuration file, editor-global settings when
available, and packaged defaults, in that order. Headless operation SHALL not
require `EditorInterface`.

#### Scenario: Headless run uses project-local model configuration

- **GIVEN** a developer saved local model and executable locations for the project
- **WHEN** an agent runs the environment CLI without path overrides
- **THEN** the CLI reads `res://build_me_godot.local.cfg`
- **AND** resolves the same project-local values used by the editor
- **AND** the local file is excluded from version control.

#### Scenario: Required check fails

- **GIVEN** at least one required check for the requested capability fails
- **WHEN** an agent runs `check --format json`
- **THEN** a complete JSON report is written
- **AND** the process exits with code 1.

#### Scenario: Invocation is malformed

- **GIVEN** the requested capability or output format is invalid
- **WHEN** the headless interface runs
- **THEN** it writes an actionable invocation error
- **AND** exits with code 2
- **AND** performs no installation action.

### Requirement: Installation plans are separate from application

The utility SHALL generate a read-only ordered remediation plan before any
installation action can be applied. Applying SHALL require explicit action IDs
and SHALL report affected paths, results, and verification status.

#### Scenario: Artist previews ComfyUI helper setup

- **GIVEN** the bundled turnaround helper is missing from a configured existing
  ComfyUI installation
- **WHEN** the artist requests an installation plan
- **THEN** the plan identifies the packaged source, selected destination,
  overwrite policy, MIT license, restart requirement, and verification check
- **AND** no file is copied until the artist explicitly applies that action.

#### Scenario: Agent applies one selected action

- **GIVEN** a plan contains workspace creation and ComfyUI helper copy actions
- **WHEN** an authorized agent applies only the workspace action ID
- **THEN** only the project workspace paths are created
- **AND** the ComfyUI installation remains unchanged
- **AND** the report lists every created path and the verification result.

### Requirement: Unsafe or expansive installation remains manual by default

The initial utility SHALL NOT automatically install system packages, Python
packages, model weights, external addons, or unreviewed provider code. Such
requirements SHALL be represented as manual remediation with exact source,
destination, license, and verification guidance where known.

#### Scenario: Required model weight is absent

- **GIVEN** a workflow declares a model artifact that is not installed
- **WHEN** an installation plan is generated
- **THEN** the model is not downloaded
- **AND** the plan identifies the exact repository, filename or artifact ID,
  expected destination, reviewed weight license, and verification method
- **AND** unclear or non-commercial weight licensing is reported as rejected,
  not installable.

### Requirement: Reports protect credentials and private creative data

Human and machine-readable reports SHALL omit credentials, authorization
headers, query secrets, environment dumps, prompt text, generated images, and
unrelated directory contents. Support-mode reports SHALL redact user-specific
absolute path prefixes while preserving enough relative context to diagnose
the project.

#### Scenario: ComfyUI URL contains a secret

- **GIVEN** a configured service URL includes a credential or sensitive query
  value
- **WHEN** a text or JSON report is rendered
- **THEN** the secret is absent from the report
- **AND** endpoint evidence retains only a safe origin and path description.

### Requirement: Workflow packages declare their environment requirements

Packaged workflows and processing scripts SHALL carry machine-readable
compatibility metadata describing required nodes, model artifacts, helper
versions, tool versions, and output contracts. Check providers SHALL evaluate
those declarations rather than scattering workflow-specific filenames through
the editor UI.

#### Scenario: Packaged workflow changes its custom nodes

- **GIVEN** a workflow template references a new custom node class
- **WHEN** package validation runs
- **THEN** validation fails until that node is declared in the workflow's
  compatibility metadata
- **AND** environment reports use the declaration after it is added.

### Requirement: Optional Gator integration remains independent

The utility SHALL detect a separately installed Gator Model Studio version,
enabled state, and compatible extension API without installing it or writing
inside its addon directory.

#### Scenario: Gator is available for last-mile refinement

- **GIVEN** a compatible Gator Model Studio installation is enabled
- **WHEN** readiness is requested for `last_mile_refinement`
- **THEN** the report identifies Gator as an available refinement path
- **AND** credits its publisher and reviewed license source
- **AND** performs no cross-addon modification.
