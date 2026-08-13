## 1. OpenSpec and Command Contract

- [x] 1.1 Document the automated local proxy-and-fit process, provider command
  contract, setup-app obligations, and hard blockers.
- [x] 1.2 Add spec deltas for explicit proxy generation and duplicate-only
  conformance guidance.

## 2. Proxy Generation

- [x] 2.1 Add `generate-proxy` to the character CLI with stable JSON output.
- [x] 2.2 Implement a provider command runner that consumes
  `provider_inputs.json`, writes proxy meshes under the conformance folder, and
  records provider provenance without installing or downloading anything.
- [x] 2.3 Add mock-provider tests for successful proxy generation, failed
  command, missing output mesh, rejected provider id, and absent configured
  command.
- [x] 2.4 Update conformance plan and manifest state transitions for generated
  proxy outputs.

## 3. Blender Guidance

- [x] 3.1 Extend Blender handoff to import generated proxy meshes and record
  proxy bounds in the handoff report.
- [x] 3.2 Emit `conformance_guidance.json` with silhouette/bounds deltas,
  field-engineer clothing shell candidates, prop/socket candidates, material
  targets, warnings, and changed paths.
- [x] 3.3 Keep all source rigged meshes, proxy meshes, and reference planes
  tagged reference-only and excluded from production export.
- [x] 3.4 Add parser tests for the guidance JSON and Blender handoff metadata.

## 4. Environment / Install App

- [x] 4.1 Ensure the environment check and install plan report TripoSR command
  readiness as the promoted automated provider path.
- [x] 4.2 Confirm setup utilities remain read-only for checks/plans and do not
  clone repositories, install Python packages, download model weights, or write
  into ComfyUI/Blender.
- [x] 4.3 Add or update tests for setup-plan output and verification check IDs.
- [x] 4.4 Add an explicit setup-app action to stage reviewed TripoSR model
  files without installing TripoSR or mutating external tool directories.
- [x] 4.5 Document that Ollama is analysis-only for this workflow and is not
  the TripoSR execution wrapper.
- [x] 4.6 Add explicit setup-app actions for the local ComfyUI Flowty TripoSR
  node with GPL-3.0 license messaging and no bundled code.
- [x] 4.7 Add explicit setup-app checks/actions for placing the reviewed
  TripoSR checkpoint where the Flowty ComfyUI node can load it.

## 5. Documentation and Validation

- [x] 5.1 Document the expected operator/agent process after
  `prepare-conformance`: configure provider, generate proxy, run Blender
  guidance, review in Blender/Godot, approve conformance.
- [x] 5.2 Run headless editor load, GDScript tests, Python parser checks,
  OpenSpec validation, and `git diff --check`.
