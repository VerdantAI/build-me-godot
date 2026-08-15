## 1. Research Register

- [ ] 1.1 Add project-local research-register schema for canonical human
  provider candidates.
- [ ] 1.2 Record MPFB2/MakeHuman, SHERT, HumanGaussian, HAHA, UVFaceFusion,
  TECA, and SMPL-X license records with reviewed dates and source URLs.
- [ ] 1.3 Update `addons/build_me_godot/LICENSES.md` and
  `addons/build_me_godot/ATTRIBUTIONS.md` only for providers that become
  acknowledged addon-facing candidates; keep rejected/research-only entries
  explicit.

## 2. Provider Contracts

- [ ] 2.1 Define `canonical_human_provider.json`,
  `canonical_human_inputs.json`, `canonical_human_outputs.json`,
  `canonical_human_validation.json`, and
  `canonical_human_scorecard.json` contracts.
- [ ] 2.2 Add fixture examples under project-local test data, not under the
  addon package output directories.
- [ ] 2.3 Add parser/contract validation tests for accepted, research-only,
  blocked, and unknown license states.

## 3. MPFB-First Prototype

- [ ] 3.1 Add read-only readiness checks for Blender 4.2+ and a user-configured
  MPFB installation.
- [ ] 3.2 Add an explicit local wrapper contract that invokes only a configured
  command or Blender script and writes results under
  `res://build_me_godot/characters/<character_id>/canonical_human/<version>/`.
- [ ] 3.3 Add fixture-driven morph-vector and texture-map handoff before any AI
  estimator is integrated.
- [ ] 3.4 Validate exported character scale, `neutral_a_pose_30deg_v1`,
  humanoid bone/socket names, and `SkeletonProfileHumanoid` compatibility.

## 4. Research Provider Benchmarks

- [ ] 4.1 Add disabled-by-default scorecard fixtures for SHERT,
  HumanGaussian, HAHA, UVFaceFusion, and TECA.
- [ ] 4.2 Add research-only readiness checks that require explicit local paths,
  offline/no-download mode, and license acknowledgement before provider runs.
- [ ] 4.3 Add benchmark report templates for setup friction, output
  representation, animation control, texture usefulness, and Godot import
  distance.

## 5. Documentation

- [ ] 5.1 Document the MPFB-first architecture and why arbitrary AI topology
  remains reference-only.
- [ ] 5.2 Document SMPL-X licensing as a research/commercial gate, including
  why SMPL-X-backed systems are not default providers.
- [ ] 5.3 Document that Gaussian/NeRF layers are appearance references unless
  a future Godot runtime/import path is explicitly designed.

## 6. Validation

- [ ] 6.1 Run the headless editor load.
- [ ] 6.2 Run GDScript tests.
- [ ] 6.3 Run Python parser checks.
- [ ] 6.4 Run `openspec validate evaluate-canonical-human-topology-providers --strict`.
- [ ] 6.5 Run `git diff --check`.
