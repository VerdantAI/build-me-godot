## Why

Build Me Godot coordinates several independently installed tools: Godot,
ComfyUI, model weights and custom nodes, Blender, reconstruction providers,
animation assets, and optional last-mile editors such as Gator Model Studio.
The current dock can identify Blender, ComfyUI, and Gator at a basic level, but
it cannot explain whether an installation is complete enough for a particular
workflow or give another developer or coding agent a reproducible repair plan.

Manual setup instructions alone will drift as tool versions, model filenames,
workflow node requirements, and operating systems change. A human needs a
short, actionable setup view. An agent needs the same facts as stable JSON,
documented exit codes, exact commands, and paths that can be inspected without
screen scraping or guessing from prose.

## What Changes

- Add a capability-oriented environment checker for the host Godot project,
  writable character workspace, ComfyUI server, required workflow nodes and
  configured model artifacts, Blender, reconstruction providers, animation
  assets, and optional Gator Model Studio installation.
- Normalize every check into a versioned report schema with stable IDs,
  required/optional severity, detected and expected values, evidence, and
  actionable remediation.
- Render that single report model as an editor setup view for artists and as
  deterministic text or JSON for command-line users and development agents.
- Add installation planning utilities that distinguish observation from
  mutation. Planning is always read-only; applying a plan is an explicit,
  granular user action and reports every changed path.
- Permit safe local setup actions such as creating project workspace folders,
  saving configured executable paths, and copying the bundled MIT ComfyUI
  helper into a user-selected existing ComfyUI installation.
- Represent external downloads, package installation, model installation, and
  changes inside another addon's directory as unresolved/manual actions unless
  a separately reviewed provider explicitly implements them. No setup action
  runs silently when the addon is enabled.
- Add redaction, offline operation, license/provenance fields, report export,
  and tests for both human and agent interfaces.

## Capabilities

### New Capabilities

- `installation-environment-utilities`: Local environment discovery,
  workflow-specific readiness evaluation, installation planning, explicit
  safe setup actions, and human/agent-readable reporting.

### Modified Capabilities

- None. The repository does not yet have an archived baseline capability for
  dependency setup or diagnostics.

## Impact

- Expands the existing `dependency_probe.gd` into a capability registry rather
  than adding one-off status labels to the editor dock.
- Adds a setup/readiness section to the Build Me Godot editor UI.
- Adds a headless entry point suitable for local scripts, CI, and coding
  agents, with stable exit behavior and no GUI dependency.
- Introduces a versioned JSON report and install-plan schema beneath the
  addon, plus fixtures for ready, partially configured, incompatible, and
  offline environments.
- Adds explicit local copy/setup operations while preserving the project's
  rule that external tools, weights, packages, and addons are never installed
  automatically.
- Makes support reports useful without exposing credentials, environment
  dumps, home-directory contents, prompts, or generated assets.
