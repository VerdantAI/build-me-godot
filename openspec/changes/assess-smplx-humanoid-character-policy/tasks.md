## 1. Current-Use Audit

- [ ] 1.1 Add a repeatable audit command or test that scans source, addon
  package files, local workflow assets, provider manifests, docs, and sample
  manifests for SMPL-X terms, file signatures, and path requirements.
- [ ] 1.2 Classify findings as `none`, `research_reference`,
  `requires_local_smplx`, `derived_output`, `bundled_or_redistributed`, or
  `unknown_needs_review`.
- [ ] 1.3 Record the initial finding that current repo evidence shows
  OpenSpec-only references and no shipped implicit SMPL-X use.

## 2. License And Provenance Policy

- [ ] 2.1 Add a license decision record schema for SMPL-X model/software,
  SMPL-X Body outputs, commercial permission, attribution, and transitive
  provider dependencies.
- [ ] 2.2 Document that standard SMPL-X model/software use is research-only by
  default and cannot be a commercial-default provider.
- [ ] 2.3 Document that SMPL-X Body CC-BY output posture does not imply
  permission to redistribute or commercially use the full model/software.
- [ ] 2.4 Add release-gate checks so SMPL-X files or provider requirements
  cannot enter the addon package without an accepted license record.

## 3. Decision Path Evaluation

- [ ] 3.1 Compare Path A, no SMPL-X runtime use, against the current
  Quaternius/Rigify/Godot humanoid workflow.
- [ ] 3.2 Compare Path B, optional user-managed research-only SMPL-X, against
  SHERT, HumanGaussian, HAHA, and TECA benchmark needs.
- [ ] 3.3 Define requirements for Path C, commercial-license-enabled SMPL-X,
  without assuming a commercial license exists.
- [ ] 3.4 Produce a decision record recommending which path is allowed for
  default, research-only, and production workflows.

## 4. Manifest And Provider Boundaries

- [ ] 4.1 Define manifest fields for SMPL-X provenance when a research-only
  provider output is imported as a reference.
- [ ] 4.2 Add provider metadata fields for transitive SMPL-X requirements and
  automatic-download behavior.
- [ ] 4.3 Add approval gates that prevent research-only SMPL-X outputs from
  registering as final production characters.
- [ ] 4.4 Ensure support reports redact local SMPL-X paths and omit private
  commercial-license evidence by default.

## 5. Game-Mode Research Fit

- [ ] 5.1 Score SMPL-X usefulness separately for `first_person_vr`,
  `first_person_fps`, `3d_isometric_party`, `3d_isometric_settlement`, and
  `low_poly_high_volume`.
- [ ] 5.2 Identify where SMPL-X hands/face/body detail would materially improve
  output quality versus where it exceeds budget or licensing tolerance.
- [ ] 5.3 Compare SMPL-X against MPFB/MakeHuman and permissive-template
  alternatives for each game-mode profile.

## 6. Documentation And Validation

- [ ] 6.1 Update dependency/license documentation only after the policy decision
  selects an addon-facing posture.
- [ ] 6.2 Document user-facing language for research-only SMPL-X experiments.
- [ ] 6.3 Run the headless editor load.
- [ ] 6.4 Run GDScript tests.
- [ ] 6.5 Run Python parser checks.
- [ ] 6.6 Run `openspec validate assess-smplx-humanoid-character-policy --strict`.
- [ ] 6.7 Run `git diff --check`.
