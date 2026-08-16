## Why

The current field-engineer slice proves the character pipeline can select a
rigged base, assemble it, import it into Godot, validate animation libraries,
and render an isometric readability preview. It does not yet prove meaningful
character customization. The field engineer still reads as the original
Quaternius-style male base with recipe intent attached.

Build Me Godot needs a customization stack that changes identity while
preserving play-test reliability. The goal is not to sculpt arbitrary topology
or train new models. The goal is to reuse rigged bases, permissive asset
libraries, Blender, Godot import tools, ComfyUI references, and optional
user-managed morph providers so a character can become visually distinct
through body proportions, materials, clothing, hair, accessories, sockets,
animation fit, and game-mode readability.

## What Changes

- Add an implementation plan for meaningful humanoid base customization.
- Define layered customization stages: base selection, non-destructive body
  variant, material identity, modular clothing/accessories, socketed props,
  animation/readability validation, and checkpoint invalidation.
- Support a first pragmatic path using the current project rigged base plus
  material overrides and reusable shape assets.
- Define a later MPFB/MakeHuman bridge for semantic body/face morphs when the
  user has that environment installed.
- Keep AI image/reference outputs as guidance and review evidence rather than
  production topology.
- Preserve `neutral_a_pose_30deg_v1`, Godot `SkeletonProfileHumanoid`, and
  project-local outputs under `res://build_me_godot/`.

## Out Of Scope

- No automatic installation of MPFB, MakeHuman, Blender extensions, ComfyUI
  nodes, Python packages, model weights, or third-party assets.
- No bundled SMPL-X dependency or SMPL-X production path.
- No destructive edits to source base meshes.
- No custom retargeting system beside Godot `SkeletonProfileHumanoid`.
- No promotion of AI reconstruction meshes as production humanoid topology.

## Implementation Direction

The first implementation should customize the existing field engineer enough
to read as a distinct play-test character from an isometric camera:

1. Keep the current rigged base as the production body substrate.
2. Add recipe fields for body variant controls that are safe for this base:
   height/scale, head scale, shoulder width, torso width, limb thickness, and
   optional mesh-object visibility where supported.
3. Add material override support for skin, hair, eye, shirt/body, roughness,
   and simple color ramps or texture swaps.
4. Replace procedural accessory placeholders with reusable-shape references as
   soon as reviewed assets are imported.
5. Rebuild the field-engineer assembly and validate animation/readability.
6. Record where the current base is insufficient and whether MPFB/MakeHuman
   should become the recommended morph-capable provider.

## Current Status

Phase-1 body/material customization is implemented for the `field_engineer`
slice. The approved recipe records coarse project-base body controls, material
overrides, customization limitations, and checkpoint dependencies. Blender
assembly applies those changes to the character-local work file, exports only
production body/armature objects, and writes non-emissive PBR material factors
so Godot does not import the character as a glowing white fallback.

The result is still partial. The current rigged base exposes only a single
body material slot, so skin/clothing/boots cannot be independently customized
without texture repainting, a richer base, or an MPFB/MakeHuman-style semantic
provider. The field engineer also still lacks reviewed production accessories;
placeholder equipment is intentionally reference-only and excluded from the
production GLB.

## Next Steps

1. Complete the reusable-shape library path for common field-engineer
   accessories.
2. Import at least one reviewed hard hat, clipboard, tool, pouch, belt, or boot
   asset through an explicit user-owned action.
3. Replace placeholder equipment in the recipe with `source_kind:
   reusable_shape` references.
4. Rebuild the field-engineer assembly and confirm the main example scene shows
   a visible reviewed accessory at isometric camera distance.
5. Add production-readiness validation that fails when required silhouette
   customization depends on reference-only, blockout, unclear-license, or
   unreviewed assets.
