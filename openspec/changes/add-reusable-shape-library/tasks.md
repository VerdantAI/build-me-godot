## 1. Research and Policy

- [x] Confirm preferred first-source asset packs for hard hats, tools,
  clipboards, belts, boots, pouches, crates, wheels, panels, and cables.
- [x] Record license-review rules for CC0, MIT-code repositories, individual
  asset pages, generated-asset marketplaces, and unclear-weight/model sources.
- [x] Decide whether generated assets from services such as Meshy are allowed
  as production reusable shapes or reference-only candidates.

## 2. Schema

- [ ] Define `shape_library.json` and `shape.json` schemas.
- [ ] Define shape status values: `production_ready`, `blockout`,
  `reference_only`, `candidate`, `rejected`.
- [ ] Define shape taxonomy, representation class, semantic tags, socket
  compatibility, material slots, collision metadata, LOD metadata, and
  game-mode fit fields.
- [ ] Add digest/provenance fields that support checkpoint invalidation.

## 3. Godot Addon Workflow

- [ ] Add a reusable-shape lookup service under the addon.
- [ ] Add UI affordances for choosing reusable shapes for recipe parts.
- [ ] Add a warning when a common object would use procedural generation
  before library lookup or explicit user approval.
- [ ] Ensure all imported model assets are written under
  `res://build_me_godot/assets/`.

## 4. Blender Assembly

- [ ] Teach the Blender assembly script to resolve `source_kind:
  reusable_shape`.
- [ ] Attach reusable shapes to stable humanoid sockets with per-recipe
  transform overrides.
- [ ] Preserve source shape metadata in assembly reports.
- [ ] Mark blockout/reference shapes as export-excluded unless explicitly
  promoted with review evidence.

## 5. Checkpoints and Validation

- [ ] Add reusable-shape digests to character checkpoint dependencies.
- [ ] Invalidate assembly/readability checkpoints when referenced shape assets
  change.
- [ ] Add validation that production-ready character assemblies cannot depend
  on blockout/reference-only shapes.
- [ ] Add tests for library lookup, recipe reference resolution, stale
  checkpoint detection, and export exclusion.

## 6. Field Engineer Slice

- [ ] Pick the first accessory target for the field engineer: hard hat,
  clipboard, hand tool, belt/pouch, or boots.
- [ ] Import at least one reviewed reusable hard-hat or worksite accessory
  through an explicit user-managed asset action.
- [ ] Write `shape_library.json` and `shape.json` metadata for that accessory
  under `res://build_me_godot/assets/reusable_shapes/`.
- [ ] Replace the current procedural field-engineer accessory placeholders
  with reusable-shape references.
- [ ] Rebuild the field-engineer assembly and readability preview.
- [ ] Confirm the main example scene shows a reusable asset, not a generated
  placeholder, for at least one common accessory.

## 7. Current Handoff Notes

- [x] Record candidate-only source metadata in
  `addons/build_me_godot/integrations/hard_surface_asset_candidates.json`.
- [x] Document that placeholder equipment is excluded from production export.
- [ ] Implement read-only shape lookup before generation for common objects.
- [ ] Add production-readiness failure for required equipment that resolves
  only to placeholder, blockout, reference-only, or unreviewed shapes.
