## 1. Report contract and provider boundary

- [x] 1.1 Define versioned check-result, environment-report, remediation, and
  install-plan schemas with stable IDs, statuses, importance, evidence, and
  redaction rules.
- [x] 1.2 Refactor existing Blender, ComfyUI, and Gator probes behind narrow
  provider interfaces without changing their current editor behavior.
- [x] 1.3 Add project/Godot, workflow-template, reconstruction, and local asset
  providers with workflow-specific required/optional evaluation.
- [x] 1.4 Add fixtures for ready, partial, incompatible, unreachable, malformed,
  and optional-dependency environments.

## 2. Workflow compatibility declarations

- [x] 2.1 Add sidecar metadata for the canonical and multiview workflows,
  declaring required node classes, helper version, loader inputs, model
  artifacts, and recommended memory behavior.
- [x] 2.2 Add Blender builder metadata for minimum Blender version, required
  operators, configuration schema, and expected report/output contract.
- [x] 2.3 Validate declarations during addon tests and fail clearly when a
  packaged workflow references an undeclared custom node or model artifact.

## 3. Agent and command-line interface

- [x] 3.1 Add a headless CLI supporting `check`, `plan`, `apply`, and `verify`,
  capability selection, and `text` or `json` output.
- [x] 3.2 Implement documented exit codes and keep JSON stdout free of progress,
  logs, color, and non-JSON text.
- [x] 3.3 Add deterministic ordering, schema-version reporting, path redaction,
  and tests that parse CLI output as an external agent would.
- [x] 3.4 Document example agent prompts and commands for discovering, planning,
  applying selected safe actions, and re-verifying an installation.
- [x] 3.5 Add local/global configuration resolution shared by the editor and
  headless CLI, with environment and command-line overrides and a gitignored
  project-local file.

## 4. Human setup experience

- [x] 4.1 Replace the flat dependency label with an editor setup view grouped
  by canonical, multiview, reconstruction, Blender build, Godot import, and
  optional last-mile stages.
- [x] 4.2 Add concise status/evidence/remediation presentation, expandable
  technical details, rerun/deep-check controls, and no per-frame warning spam.
- [x] 4.3 Add copy-text-report and save-JSON-report actions using the same report
  model and redaction behavior as the CLI.
- [ ] 4.4 Verify keyboard navigation, narrow dock layouts, high-DPI rendering,
  and status cues that do not depend on color alone.

## 5. Explicit installation planning and safe actions

- [x] 5.1 Generate ordered, read-only remediation plans with action IDs,
  rationale, affected paths, prerequisites, reversibility, license records,
  and expected verification checks.
- [x] 5.2 Implement explicit project-workspace creation and editor-setting
  controls with visible values and post-action verification.
- [x] 5.3 Implement explicit copying of the bundled MIT ComfyUI helper to a
  user-selected existing installation, including target validation,
  overwrite/backup policy, changed-path reporting, and restart instructions.
- [x] 5.4 Keep models, Python packages, system packages, external addons, and
  unreviewed provider installers as manual actions; test that neither plugin
  activation nor `check`/`plan` modifies them.

## 6. Validation and Store documentation

- [x] 6.1 Add unit tests for result aggregation, capability gating, stable
  ordering, redaction, renderer equivalence, and exit-code selection.
- [x] 6.2 Add local integration tests for a mock ComfyUI server, Blender version
  and deep probes, missing assets, and optional Gator detection.
- [x] 6.3 Add a clean-project installation test proving the addon can diagnose an
  empty environment without errors or mutations.
- [ ] 6.4 Update README, packaged setup documentation, attributions, license
  review, screenshots, and Godot Asset Store description.
