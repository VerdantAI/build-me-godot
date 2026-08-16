## 1. Recipe Contract

- [x] 1.1 Define `character_recipe.json` schema version 1 for
  `3d_isometric_party` characters.
- [x] 1.2 Include body strategy, provider provenance, equipment parts,
  representation classes, sockets, material palette, texture budget,
  animation requirements, LOD strategy, validation requirements, and output
  paths.
- [x] 1.3 Add validation for missing profile ID, missing body strategy,
  unreviewed provider license states, missing required sockets, invalid
  representation classes, and attempts to promote proxy/research topology.
- [x] 1.4 Add fixture recipes for `party_fighter_v1` and
  `village_healer_v1`.

## 2. Character Manifest Integration

- [x] 2.1 Link approved recipe versions from the existing character manifest
  without breaking unknown-field preservation.
- [x] 2.2 Add headless JSON commands or extend existing commands to inspect,
  validate, create, approve, and supersede recipe versions.
- [x] 2.3 Record changed paths, validation warnings, provider provenance, and
  explicit user approval states.
- [x] 2.4 Keep recipe files and outputs under
  `res://build_me_godot/characters/<character_id>/`.

## 3. Game-Mode Integration

- [x] 3.1 Require the recipe to declare `3d_isometric_party` or another
  explicit profile before validation can pass.
- [x] 3.2 Populate recipe defaults from the selected game-mode profile without
  overwriting explicit character choices.
- [x] 3.3 Add isometric-specific validation expectations for silhouette,
  equipment readability, medium texture budgets, modular sockets, and LOD
  handoff.

## 4. AI-Assisted Reference And Recipe Drafting

- [x] 4.1 Add a reviewed prompt/template contract that asks local AI tools for
  structured recipe suggestions rather than arbitrary prose.
- [ ] 4.2 Add optional local Ollama recipe drafting behind existing readiness
  checks and explicit user action.
- [ ] 4.3 Validate AI-proposed recipe JSON, show a diff, and require user
  acceptance before durable files change.
- [x] 4.4 Allow ComfyUI reference runs to attach concept sheets, portraits,
  palettes, decal references, and material references to recipe source data.
- [x] 4.5 Ensure no hosted model, model download, or ComfyUI mutation occurs
  automatically.

## 5. Production Body Provider Path

- [x] 5.1 Add readiness-only records for external MPFB2/MakeHuman and
  project-provided humanoid base meshes.
- [x] 5.2 Implement the first recipe-to-body path with either an existing
  project humanoid fixture or a user-managed MPFB/MakeHuman export.
- [x] 5.3 Validate `neutral_a_pose_30deg_v1`, Godot
  `SkeletonProfileHumanoid`, scale, skeleton naming, and deformation smoke
  assumptions.
- [x] 5.4 Keep SMPL-X-backed providers research-only unless a separate license
  decision record explicitly enables production use.

## 6. Modular Equipment And Props

- [x] 6.1 Define fixture equipment plans for fighter weapon/shield/armor and
  healer staff/robe/pouch/book components.
- [x] 6.2 Prefer existing project assets, CC0/permissive asset-store content,
  or Blender primitives before custom mesh generation.
- [x] 6.3 Use representation-planning classes for hard-surface, cloth,
  flexible, decal, and residual/proxy parts.
- [x] 6.4 Allow TRELLIS/TripoSR/Hunyuan3D-style outputs only as immutable
  proxy/reference inputs unless a reviewed conversion path exists.

## 7. Blender Assembly Prototype

- [x] 7.1 Add an explicit Blender job that reads a validated recipe and creates
  duplicate-only project-local work files.
- [x] 7.2 Place reference planes, import or create the body, attach modular
  equipment, create placeholder props, assign material placeholders, and verify
  sockets.
- [x] 7.3 Export a Godot-readable asset package and write a structured
  assembly report.
- [x] 7.4 Avoid writing into external Blender addons, MPFB directories,
  ComfyUI directories, or source asset-pack directories.

## 8. Godot Scene And Play-Test Acceptance

- [x] 8.1 Register final character scene paths, animation paths, sockets,
  materials, LOD outputs, preview thumbnails, and validation reports in the
  character manifest.
- [x] 8.2 Add a small play-test fixture that can load both slice characters and
  cycle idle, walk, and one role animation where available.
- [ ] 8.3 Add isometric camera thumbnail/readability evidence for each
  accepted character.
- [ ] 8.4 Mark slice completion only when both characters are importable,
  inspectable, and spawnable in Godot.

## 9. Documentation And Validation

- [x] 9.1 Document the vertical-slice workflow, provider boundaries, recipe
  schema, and acceptance criteria.
- [x] 9.2 Add tests for recipe validation, manifest linking, profile defaults,
  provider license gating, proxy-topology blocking, Blender report parsing,
  and Godot scene registration.
- [x] 9.3 Run headless editor load.
- [x] 9.4 Run GDScript tests.
- [x] 9.5 Run Python parser checks.
- [x] 9.6 Run `openspec validate build-isometric-character-vertical-slice --strict`.
- [x] 9.7 Run `git diff --check`.
