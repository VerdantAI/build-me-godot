## 1. Research Register

- [ ] 1.1 Add research records for PartCrafter, OmniPart, MeshArt,
  CAD-Recode, NURBGen, SGS-1, Meshtron, and current monolithic reconstruction
  providers.
- [ ] 1.2 Record exact source URLs, reviewed dates, code licenses,
  model/data licenses, automatic-download behavior, hosted-service features,
  hardware requirements, and output representations.
- [ ] 1.3 Classify each provider as accepted, candidate, research-only,
  reference-only, blocked, or unknown.

## 2. Representation Plan Contract

- [ ] 2.1 Define a versioned `representation_plan.json` schema for assets and
  character-associated props.
- [ ] 2.2 Add taxonomy fields for organic, inorganic mechanical, architectural,
  hybrid wearable, flexible/cloth, effect/volume, decal/marking, and unknown
  mixed assets.
- [ ] 2.3 Add component representation fields for organic mesh, hard-surface
  mesh, primitive, lathed/revolved, curve, CAD code, BRep/STEP, NURBS,
  cloth/flexible mesh, shader/volume, decal/texture, and residual reference
  mesh.
- [ ] 2.4 Add component fields for material slots, articulation, sockets,
  collision, LOD, production candidacy, provider provenance, and review notes.

## 3. Manual Fixtures

- [ ] 3.1 Create manual representation-plan fixtures for a Labmarket droid,
  furniture with moving parts, a hand tool or weapon, an architectural prop,
  an organic contrast asset, and a hybrid wearable.
- [ ] 3.2 Add validation fixtures for missing components, invalid
  representation classes, missing pivots on articulated parts, and monolithic
  mesh fallback warnings.
- [ ] 3.3 Store fixtures under project-local test data, not under generated
  addon output folders.

## 4. Blender Procedural Prototype

- [ ] 4.1 Add a disabled-by-default prototype that reads a representation plan
  and creates simple Blender primitives, curves, pivots, sockets, materials,
  collisions, and LOD placeholders.
- [ ] 4.2 Keep generated Blender work under `res://build_me_godot/` or
  repository-local workflow data, never under `addons/build_me_godot/`.
- [ ] 4.3 Add validation reports for part count, pivot alignment, material
  assignment, collision proxy presence, and export readiness.

## 5. Provider Benchmarks

- [ ] 5.1 Benchmark PartCrafter and OmniPart as part-aware mesh providers only
  with user-managed local checkouts and manually staged weights.
- [ ] 5.2 Benchmark MeshArt as an articulation-structure reference and record
  category limitations.
- [ ] 5.3 Benchmark CAD-Recode/NURBGen-style outputs as procedural CAD
  references without executing generated code outside an approved sandbox.
- [ ] 5.4 Benchmark Meshtron-style artist-topology output as a mesh-quality
  branch, not a primitive/CAD replacement.
- [ ] 5.5 Compare every provider against object taxonomy, game-mode profile,
  production candidacy, and local-only policy.

## 6. Optional Planner Assistance

- [ ] 6.1 Define a manual-first planner UI or headless command that records
  component representation choices.
- [ ] 6.2 Add an optional local Ollama-assisted planner draft only after the
  game-mode profile workflow and environment readiness checks exist.
- [ ] 6.3 Require planner proposals to be reviewable JSON and block geometry
  execution until user approval.

## 7. Documentation And Validation

- [ ] 7.1 Document the organic versus inorganic distinction and when
  monolithic reconstruction should remain reference-only.
- [ ] 7.2 Document generated CAD/Python code execution risks and sandbox
  requirements.
- [ ] 7.3 Run the headless editor load.
- [ ] 7.4 Run GDScript tests.
- [ ] 7.5 Run Python parser checks.
- [ ] 7.6 Run `openspec validate research-organic-inorganic-representation-planning --strict`.
- [ ] 7.7 Run `git diff --check`.
