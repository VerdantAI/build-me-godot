## 1. Planning And Schema

- [x] Add recipe schema fields for `body_variant`,
  `material_overrides`, reusable shape references, and customization
  limitations.
- [x] Define allowed phase-1 body controls for the current project base.
- [x] Define material slot naming and fallback behavior for the current base.
- [x] Define a validation score or report section for "meaningful difference
  from base."

## 2. Current Field Engineer

- [x] Inspect the current base mesh/material slots and record what can be
  changed safely.
- [x] Add a field-engineer body variant that uses only non-destructive,
  character-local transforms or duplicate mesh edits.
- [x] Add material overrides for skin/hair/body colors appropriate to the
  field-engineer reference.
- [ ] Replace placeholder equipment with reusable-shape references once
  reviewed assets are explicitly imported.
- [x] Rebuild the field-engineer assembly and readability preview.

## 3. Addon And Blender Support

- [x] Update recipe validation to accept and validate customization layers.
- [x] Update Blender assembly to apply material overrides without mutating
  source assets.
- [x] Update Blender assembly to apply safe body variant controls and record
  limitations.
- [x] Ensure placeholders remain reference-only unless reviewed and promoted.
- [x] Record customization evidence in assembly reports and checkpoints.

## 4. Checkpoints

- [x] Include body variant controls and material override digests in checkpoint
  dependencies.
- [x] Mark assembly/readability stale when customization controls change.
- [x] Keep base body checkpoints valid when only character-local
  customization changes.
- [ ] Fail production readiness when customization depends on unclear-license
  or reference-only assets.

## 5. MPFB/MakeHuman Research Bridge

- [ ] Define a readiness check for user-managed MPFB/MakeHuman availability.
- [ ] Map recipe body controls to MPFB/MakeHuman preset or parameter concepts.
- [ ] Validate exported MPFB/MakeHuman candidates against
  `neutral_a_pose_30deg_v1` and Godot `SkeletonProfileHumanoid`.
- [ ] Decide whether MPFB/MakeHuman should become the recommended provider for
  semantic body/face variants.

## 6. Tests

- [x] Add parser tests for recipes with body variants and material overrides.
- [x] Add store/checkpoint tests for customization invalidation.
- [x] Add Blender parser checks for customization application.
- [x] Add a headless Godot load test for a customized field-engineer scene.

## 7. Current Handoff Notes

- [x] Confirm generated field-engineer GLB exports only production body/armature
  objects and excludes placeholder accessories.
- [x] Confirm generated material overrides export as non-emissive PBR material
  factors and import into Godot with emission disabled.
- [x] Sync the fixed `field_engineer` output into the companion example project
  and force a headless reimport.
- [ ] Add a reusable-shape production accessory to move customization status
  from `partial` to `meaningfully_customized`.
- [ ] Revisit MPFB/MakeHuman only after the reusable accessory path works.
