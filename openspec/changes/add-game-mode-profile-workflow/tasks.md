## 1. Profile Schema And Presets

- [ ] 1.1 Define a versioned game-mode profile schema with camera, volume,
  budget, LOD, priority, validation, source, and notes fields.
- [ ] 1.2 Add built-in presets for `3d_isometric_party`,
  `3d_isometric_settlement`, `first_person_vr`, `first_person_fps`, and
  `low_poly_high_volume`.
- [ ] 1.3 Add validation for unknown preset IDs, malformed custom profiles,
  unsupported budget values, and missing required survey answers.

## 2. Manifest And Storage

- [ ] 2.1 Store the project default profile under
  `res://build_me_godot/project/game_mode_profile.json`.
- [ ] 2.2 Add character-level profile snapshots or overrides to the existing
  character manifest while preserving unknown fields.
- [ ] 2.3 Ensure profile data is never written under `addons/build_me_godot/`.

## 3. Godot Editor UX

- [ ] 3.1 Add a compact game-mode dropdown near project context and character
  metadata.
- [ ] 3.2 Add reset-to-project-default and per-character override indicators.
- [ ] 3.3 Add a custom-profile survey with constrained controls for camera,
  character volume, platform pressure, close-up importance, sockets, budgets,
  LOD/impostor strategy, and notes.
- [ ] 3.4 Add profile validation messages that disable only affected downstream
  actions, not unrelated draft editing.

## 4. Optional Ollama Assistance

- [ ] 4.1 Add read-only readiness checks for local Ollama profile assistance
  using existing environment-report conventions.
- [ ] 4.2 Add an explicit assisted-profile-draft action that sends only local
  project context and user-entered survey answers to the configured local
  Ollama endpoint.
- [ ] 4.3 Require structured JSON output, validate it against the profile
  schema, and show a reviewable diff before saving.
- [ ] 4.4 Record model provenance when an accepted profile was
  `ollama_assisted`.
- [ ] 4.5 Keep dropdown and survey workflows fully usable when Ollama is absent.

## 5. Pipeline Propagation

- [ ] 5.1 Use the selected profile to seed prompt defaults and reference-sheet
  hints without overwriting explicit prompts.
- [ ] 5.2 Include the profile snapshot in `mesh_guidance.json` and conformance
  artifacts.
- [ ] 5.3 Carry profile IDs and budget assumptions into canonical-human
  provider scorecards.
- [ ] 5.4 Add warnings when selected outputs conflict with the profile, such as
  dense meshes for low-poly/high-volume or insufficient hand evidence for VR.

## 6. Headless And Agent Interface

- [ ] 6.1 Add commands to inspect project and character profiles as JSON.
- [ ] 6.2 Add commands to set a preset profile and apply a validated custom
  profile.
- [ ] 6.3 Add a command to print the survey schema for non-UI agents.
- [ ] 6.4 Add an explicit optional command for local Ollama-assisted profile
  drafting when the user requests it.

## 7. Documentation And Validation

- [ ] 7.1 Document the dropdown, custom survey, character overrides, and local
  Ollama assistance behavior.
- [ ] 7.2 Add tests for schema validation, preset selection, custom profiles,
  manifest persistence, profile propagation, and redaction.
- [ ] 7.3 Run the headless editor load.
- [ ] 7.4 Run GDScript tests.
- [ ] 7.5 Run Python parser checks.
- [ ] 7.6 Run `openspec validate add-game-mode-profile-workflow --strict`.
- [ ] 7.7 Run `git diff --check`.
