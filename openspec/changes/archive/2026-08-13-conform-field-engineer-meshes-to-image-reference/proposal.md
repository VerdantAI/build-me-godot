## Why

The field-engineer workflow can now produce and approve image references, but
the next step is still underspecified: how the existing rigged character meshes
should be conformed toward the approved reference without treating generated
pixels or reconstructed meshes as production topology.

Current image-to-mesh systems are useful for fast proxy geometry, silhouettes,
surface hints, texture/color extraction, and prop discovery. They are not a
safe replacement for the project rig, stable humanoid/socket names, the
`neutral_a_pose_30deg_v1` pose contract, or artist-reviewed production mesh
edits. The addon needs a local, repeatable, license-aware conformance contract
that turns an approved field-engineer reference into measurable guidance for
Blender work while preserving source meshes as immutable references.

## What Changes

- Add a field-engineer mesh conformance capability that consumes an approved
  image reference set, the project rigged meshes, and optional user-managed
  reconstruction outputs.
- Define provider metadata for image-to-mesh and multiview/texture guidance
  experiments without installing ComfyUI nodes, Python packages, model weights,
  Blender extensions, or hosted services automatically.
- Persist a project-local conformance plan beneath
  `res://build_me_godot/characters/<character_id>/conformance/<version>/`.
- Use reconstruction meshes only as immutable measurement references and
  validation aids.
- Generate Blender handoff data for non-destructive work files: reference
  planes, proxy meshes, silhouette deltas, clothing/material targets, prop
  candidates, sockets, and validation constraints.
- Add review gates so artists approve conformance targets before any Blender
  automation modifies generated work files.
- Require the installation environment app to manage every newly promoted
  model, node, adapter, or provider with readiness checks, explicit install
  plans, license/provenance records, and post-action verification.
- Update dependency/license review tasks for candidate ComfyUI 3D providers,
  LoRAs/adapters, and model weights before promotion into packaged workflow
  metadata.

## Capabilities

### New Capabilities

- `field-engineer-mesh-conformance`: Image-reference-driven, local-only,
  non-destructive conformance planning for field-engineer character meshes and
  secondary assets.

### Modified Capabilities

- `godot-character-generation-workflow`: The approved reference set becomes an
  input to conformance planning after the existing continuation gate.
- `installation-environment-utilities`: Readiness checks gain optional provider
  declarations, install plans, explicit apply actions, changed-path reporting,
  and verification for promoted image-to-mesh reconstruction and multiview
  texture guidance providers. No provider is installed or downloaded when the
  addon is enabled or during passive checks.

## Impact

- Adds conformance manifest fields and project-local JSON artifacts for
  provider provenance, input references, proxy mesh paths, silhouette metrics,
  material/color targets, and prop/socket candidates.
- Adds Blender automation tasks that create duplicate-only working meshes and
  reference overlays while preserving source rigged meshes.
- Adds validation that the humanoid profile, pose contract, skeleton names,
  sockets, and original mesh files remain stable.
- Extends the install/setup app whenever a new conformance model, node, LoRA,
  adapter, or provider becomes a supported option.
- Adds tests for provider metadata parsing, conformance artifact creation,
  explicit approval gates, immutable source references, and agent-readable
  changed paths.
- Adds documentation of researched provider candidates and license decisions.
