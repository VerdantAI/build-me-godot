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
- [ ] 2.2 Add game-assumption contract fields for camera mode, expected
  simultaneous character count, asset budgets, LOD strategy, and readability
  evidence.
- [ ] 2.3 Add fixture examples under project-local test data, not under the
  addon package output directories.
- [ ] 2.4 Add parser/contract validation tests for accepted, research-only,
  blocked, and unknown license states.

## 3. Game-Mode Pipeline Research

- [ ] 3.1 Define baseline assumptions for `3d_isometric_party`,
  `3d_isometric_settlement`, `first_person_vr`, `first_person_fps`, and
  `low_poly_high_volume`.
- [ ] 3.2 Add a pipeline scorecard template that compares provider fitness
  under one declared game assumption at a time.
- [ ] 3.3 Add example research briefs for at least one provider under each
  baseline game assumption.
- [ ] 3.4 Require future provider benchmark tasks to declare either one of the
  baseline assumptions or a new explicitly documented assumption.

## 4. MPFB-First Prototype

- [ ] 4.1 Add read-only readiness checks for Blender 4.2+ and a user-configured
  MPFB installation.
- [ ] 4.2 Add an explicit local wrapper contract that invokes only a configured
  command or Blender script and writes results under
  `res://build_me_godot/characters/<character_id>/canonical_human/<version>/`.
- [ ] 4.3 Add fixture-driven morph-vector and texture-map handoff before any AI
  estimator is integrated.
- [ ] 4.4 Validate exported character scale, `neutral_a_pose_30deg_v1`,
  humanoid bone/socket names, and `SkeletonProfileHumanoid` compatibility.

## 5. Research Provider Benchmarks

- [ ] 5.1 Add disabled-by-default scorecard fixtures for SHERT,
  HumanGaussian, HAHA, UVFaceFusion, and TECA.
- [ ] 5.2 Add research-only readiness checks that require explicit local paths,
  offline/no-download mode, and license acknowledgement before provider runs.
- [ ] 5.3 Add benchmark report templates for setup friction, output
  representation, animation control, texture usefulness, and Godot import
  distance under a declared game assumption.

## 6. Documentation

- [ ] 6.1 Document the MPFB-first architecture and why arbitrary AI topology
  remains reference-only.
- [ ] 6.2 Document SMPL-X licensing as a research/commercial gate, including
  why SMPL-X-backed systems are not default providers.
- [ ] 6.3 Document that Gaussian/NeRF layers are appearance references unless
  a future Godot runtime/import path is explicitly designed.
- [ ] 6.4 Document the baseline game assumptions and how to add new assumptions
  for side-scrollers, over-the-shoulder third-person games, tactical grids,
  MMO crowds, mobile games, or non-human character sets.

## 7. Validation

- [ ] 7.1 Run the headless editor load.
- [ ] 7.2 Run GDScript tests.
- [ ] 7.3 Run Python parser checks.
- [ ] 7.4 Run `openspec validate evaluate-canonical-human-topology-providers --strict`.
- [ ] 7.5 Run `git diff --check`.
