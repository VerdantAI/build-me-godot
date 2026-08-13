## Why

The field-engineer conformance workflow can now prepare approved references,
project-local conformance plans, optional proxy slots, and Blender handoff
files. The next bottleneck is still manual: an operator or agent has to run a
reconstruction provider outside the manifest contract, import the proxy mesh by
hand, and decide how the source mannequins should move toward the reference.

Current best practice is not to replace the production rigged mesh with an
image-to-mesh output. The automated path should instead use local,
license-reviewed providers such as TripoSR to create immutable proxy geometry,
then derive measurable, reviewable guidance for duplicate Blender work meshes,
field-engineer clothing overlays, materials, and socketed props.

## What Changes

- Add an explicit `generate-proxy` character CLI operation that runs a
  configured user-managed reconstruction command against prepared provider
  inputs, records outputs under
  `res://build_me_godot/characters/<character_id>/conformance/<version>/proxy_meshes/`,
  and updates provenance in the conformance plan.
- Keep provider execution local and explicit. The addon must not clone
  repositories, install packages, download weights, install ComfyUI nodes, or
  mutate external Blender/ComfyUI installations.
- Extend Blender conformance handoff so imported proxy meshes drive measured
  silhouette and bounding-volume guidance for duplicate-only work meshes.
- Emit a first-pass conformance guidance report that separates source rig
  preservation, editable body silhouette regions, generated clothing shell
  candidates, and socketed field-engineer props.
- Update installation/environment utilities for every promoted provider or
  model/node dependency so setup is detectable, explainable, and verifiable.

## Current Provider Direction

TripoSR remains the first automated provider target because its reviewed code
and weights are MIT, it can run locally, and it is suitable for fast proxy
geometry. TRELLIS and InstantMesh remain candidate imports until their exact
local install, submodule, artifact, and no-hidden-download behavior are modeled
in the setup app. Hunyuan3D partner/API ComfyUI nodes and community-license
model families remain rejected for the default local-only path.

Ollama is useful for optional vision-assisted semantic extraction from the
approved reference images, but it is not a mesh generator. If used, it should
emit reviewable JSON targets only.

## Impact

- Adds a new agent/operator command path after `prepare-conformance`.
- Adds conformance-plan state transitions for proxy generation and automated
  guidance generation.
- Adds tests with a mock reconstruction command; no test may require real model
  weights or network access.
- Adds setup-app checks/plans for the configured provider command and any
  promoted model/node dependency.
- Maintains the existing immutable-source and proxy-not-production-topology
  constraints.
