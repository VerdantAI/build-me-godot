## Customization Layers

Meaningful humanoid customization should be layered so each step can be
validated independently:

```text
reviewed rigged base
        |
        v
safe body variant controls
        |
        v
material and texture identity
        |
        v
modular clothing / hair / accessories
        |
        v
socketed props and equipment
        |
        v
animation, collision, LOD, readability validation
```

This avoids the fragile path of replacing production topology with a generated
mesh. AI can still help by drafting recipes, producing concept references,
suggesting material palettes, and estimating which reusable parts to select.

## Phase 1: Current Base Customization

The current Quaternius-style base is useful because it is already rigged,
animated, and importable. Its limitation is that it is not a semantic morph
system. Phase 1 should only apply safe, non-destructive changes:

- object-level scale offsets for height and coarse proportions;
- optional duplicate mesh edits only in character-local Blender work files;
- material overrides for skin, hair, eye, and body/clothing texture slots;
- reusable shape attachments for hard hat, vest, belt, boots, clipboard, and
  tools;
- isometric readability validation after each assembly.

Phase 1 should not pretend that these controls are equivalent to real body
morphs. Reports should explicitly state which customizations are supported by
the base and which are approximations.

The current field-engineer implementation proves this first slice. It applies
coarse body scale controls and material overrides in the character-local
assembly file, records unresolved material slots, and exports non-emissive PBR
material factors for Godot. This is enough for an animation/readability smoke
test, but it is not enough for production identity because the base has only
one body material slot and no semantic body or clothing morphs.

## Phase 2: Reusable Shape And Material Library

The most visible improvement for isometric characters will often come from
silhouette and color:

- hard hats, helmets, hair, hats;
- vests, armor, robes, jackets, backpacks;
- belts, pouches, boots, gloves;
- hand tools, weapons, books, radios, clipboards;
- palette/material presets for occupation, faction, class, or team.

These should be reusable library assets, not generated per character. Character
recipes should reference `shape_id` and `material_preset_id` with per-character
overrides.

## Phase 3: MPFB/MakeHuman Morph Bridge

MPFB/MakeHuman is the preferred research-to-implementation bridge for real
semantic body/face customization because it already exposes artist-meaningful
human parameters. If the user has MPFB installed, Build Me Godot can treat it
as an optional external provider:

```text
recipe body_variant
        |
        v
MPFB/MakeHuman preset or Blender automation
        |
        v
rigged/exported humanoid candidate
        |
        v
Godot humanoid validation
```

The bridge should record exact provider provenance and license state. It must
not install MPFB, MakeHuman, Python packages, or assets automatically.

## Recipe Fields

Suggested additions:

```json
{
  "body_variant": {
    "provider": "project_base_transform_controls",
    "variant_id": "field_engineer_stocky_v1",
    "controls": {
      "height_scale": 0.98,
      "shoulder_width": 1.08,
      "torso_width": 1.06,
      "head_scale": 0.98,
      "limb_thickness": 1.04
    },
    "limitations": [
      "coarse object-level transforms only",
      "not a semantic body morph provider"
    ]
  },
  "material_overrides": {
    "skin": "sun_tan_light",
    "hair": "brown_short",
    "body_primary": "canvas_jacket_olive",
    "body_secondary": "safety_yellow"
  },
  "equipment": [
    {
      "part_id": "helmet",
      "source_kind": "reusable_shape",
      "shape_id": "hard_hat_basic",
      "socket": "head"
    }
  ]
}
```

## Validation

Customization validation should report:

- whether the body variant is non-destructive;
- whether source assets are untouched;
- whether skeleton/profile compatibility remains valid;
- whether material overrides resolved to known slots;
- whether reusable shapes were production-ready or reference-only;
- whether animation smoke still passes;
- whether isometric readability improved or regressed;
- whether the output still differs meaningfully from the base.

## Definition Of Meaningful Difference

For an isometric play-test character, meaningful difference does not require a
new topology. It does require enough visible changes that a player can
understand role and identity at the target camera distance:

- distinct silhouette from head/chest/hips/hand equipment;
- distinct material palette;
- at least one role-specific accessory;
- body proportion or stance variation where available;
- readable preview evidence.

If the only difference is manifest metadata, recipe text, or hidden checkpoint
state, the character is not meaningfully customized.

## Current Blocker

The remaining field-engineer blocker is reviewed silhouette equipment. The
system has candidate metadata for permissive hard-surface sources, but no
reviewed project-local reusable hard hat, clipboard, belt, boot, pouch, or tool
has been imported yet. Until at least one reviewed accessory is resolved from a
reusable shape library and included in the assembly, the field engineer remains
`partial` for meaningful customization.
