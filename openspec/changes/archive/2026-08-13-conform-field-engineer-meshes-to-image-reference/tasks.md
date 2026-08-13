## 1. Dependency and Provider Review

- [x] 1.1 Update `addons/build_me_godot/LICENSES.md` with exact reviewed
  records for candidate conformance providers before any provider metadata is
  packaged.
- [x] 1.2 Keep TripoSR as the first allowed proxy reconstruction provider and
  verify the exact repository/weight revision still matches the existing MIT
  review.
- [x] 1.3 Review TripoSG code, weights, RMBG dependency, transitive model
  licenses, VRAM requirements, and automatic-download behavior before marking
  it available.
- [x] 1.4 Review TRELLIS model artifacts, submodule licenses, output formats,
  VRAM/runtime requirements, and ComfyUI support before marking it available.
- [x] 1.5 Review InstantMesh code, model-card license, Zero123++ lineage,
  texture-map export behavior, and dependency stack before marking it
  available.
- [x] 1.6 Review Wonder3D only as a multiview/normal-map reference technique
  unless dependency and resolution constraints are acceptable.
- [x] 1.7 Review MV-Adapter and any LoRA/adapter artifacts independently,
  including base-model compatibility and commercial-use terms.
- [x] 1.8 Record Stable Fast 3D and Hunyuan3D as rejected default dependencies
  unless the project explicitly changes its permissive-only provider policy.

## 2. Conformance Artifact Contract

- [x] 2.1 Define `conformance_plan.json`, `provider_inputs.json`, proxy mesh,
  overlay, and report path conventions under
  `res://build_me_godot/characters/<character_id>/conformance/<version>/`.
- [x] 2.2 Extend the character manifest to reference conformance status,
  selected reference version, conformance plan path, provider provenance,
  approval state, and changed paths.
- [x] 2.3 Preserve unknown manifest fields and avoid writing conformance outputs
  under `addons/build_me_godot/`.
- [x] 2.4 Add schema fixtures for draft, provider-ready, provider-missing,
  proxy-generated, approved, failed, and complete conformance states.

## 3. Field-Engineer Semantic Targets

- [x] 3.1 Add a field-engineer target extractor that records hardhat/helmet,
  hi-vis garment, boots, gloves, utility belt, radio, clipboard/tablet, tools,
  safety glasses, badges/logos, and color/material swatches from prompt and
  approved reference metadata.
- [x] 3.2 Map prop candidates to stable sockets without inventing new socket
  names unless a versioned schema migration is included.
- [x] 3.3 Store uncertain detections as review notes instead of silently
  generating assets.
- [x] 3.4 Add negative/avoidance targets for common failures such as fused tools,
  unreadable logos, asymmetrical boots, malformed hands, and vest geometry
  baked into skin.

## 4. Optional Provider Readiness

- [x] 4.1 Add workflow/provider declarations for image-to-mesh and multiview
  conformance providers, including node classes, commands, input/output formats,
  VRAM class, license record, and manual setup instructions.
- [x] 4.2 Extend environment checks with optional conformance capabilities while
  keeping `check` and `plan` read-only.
- [x] 4.3 Ensure provider checks never download weights, install packages, clone
  repositories, or mutate ComfyUI/Blender installations.
- [x] 4.4 Add support for importing externally produced proxy meshes with
  manually entered provenance when no automated provider is configured.
- [x] 4.5 For every promoted ComfyUI model, custom node, LoRA, adapter, or
  provider, update the install app with read-only detection, install-plan
  output, explicit apply/manual actions, changed-path reporting, license
  records, and post-action verification.
- [x] 4.6 Add install-app tests proving newly declared conformance dependencies
  are reported by `check`, explained by `plan`, applied only by selected
  explicit actions, and verified after installation or manual placement.
- [x] 4.7 Keep unreviewed automatic-download behavior disabled even when an
  upstream provider script would auto-fetch weights by default.

## 5. Blender Handoff

- [x] 5.1 Add a Blender handoff command that reads `conformance_plan.json`,
  places approved reference planes, imports proxy meshes as immutable reference
  objects, and duplicates project rigged meshes into generated work files.
- [x] 5.2 Align references, proxy meshes, and duplicate work meshes to
  `neutral_a_pose_30deg_v1`.
- [x] 5.3 Generate front/side/back silhouette overlay reports comparing the
  rigged meshes to the approved references and any proxy meshes.
- [x] 5.4 Tag source rigged meshes and proxy meshes as reference-only and block
  export of those objects as final production topology.
- [x] 5.5 Emit changed-path reports for generated `.blend`, JSON, image overlay,
  and preview outputs.

## 6. Review and Approval Gates

- [x] 6.1 Add Godot dock or CLI states for `conformance_draft`,
  `conformance_prepared`, `conformance_review`, `conformance_approved`, and
  `conformance_failed`.
- [x] 6.2 Disable conformance approval until required references, rigged meshes,
  provider provenance, and validation reports exist.
- [x] 6.3 Require explicit user approval before downstream Blender automation
  applies conformance guidance to generated work meshes.
- [x] 6.4 Add support/report export that redacts prompts and local machine paths
  by default.

## 7. Validation

- [x] 7.1 Add tests proving source mesh files, source rigs, stable bone names,
  sockets, and humanoid profile settings are unchanged by conformance prep.
- [x] 7.2 Add tests for missing approved reference versions, missing rigged
  mesh slots, missing provider outputs, invalid proxy mesh paths, and rejected
  provider licenses.
- [x] 7.3 Add parser checks for new JSON schemas and Blender handoff metadata.
- [x] 7.4 Add mock-provider tests for TripoSR-style proxy output without running
  external model inference.
- [x] 7.5 Run the headless editor load, GDScript tests, Python parser checks,
  OpenSpec validation, and `git diff --check` before handoff.

## 8. Documentation

- [x] 8.1 Document field-engineer image-to-mesh best practices: clean front
  view, centered subject, alpha/background normalization, minimal occlusion,
  preserved multiview labels, explicit safety-workwear prompts, and artist
  review.
- [x] 8.2 Document provider policy: optional, local, user-installed,
  license-reviewed, no automatic downloads, and proxy-only outputs.
- [x] 8.3 Add examples of conformance plan inspection and agent CLI usage.
- [x] 8.4 Update `ATTRIBUTIONS.md` only after a provider or adapter becomes an
  acknowledged optional integration.
