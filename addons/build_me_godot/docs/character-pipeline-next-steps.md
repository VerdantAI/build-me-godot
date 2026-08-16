# Character Pipeline Next Steps

Build Me Godot is currently aimed at play-test-ready Godot characters and
assets, not new model training or bespoke replacement tools. The preferred
path is to reuse reviewed rigged bases, permissively licensed asset libraries,
Blender, ComfyUI, Godot import tooling, optional asset-store tools, and local
orchestrators before adding custom generation code.

## Current Field Engineer State

The `field_engineer` slice now starts after concept art. It uses the reviewed
Quaternius-style humanoid base as production topology, records an approved
post-concept recipe, assembles a Godot scene, validates animation-library
availability, and renders an isometric readability preview.

The current assembly applies:

- a character-local, non-destructive body variant using coarse scale controls;
- material overrides for body, hair, and eyes;
- non-emissive PBR material export so Godot does not import the character as a
  glowing white surface;
- checkpoint evidence for body variant, material overrides, readability, and
  animation smoke;
- export exclusion for placeholder accessories.

The current base has one body material slot, so it cannot separate skin,
shirt, pants, gloves, and boots without a richer base, UV-aware repaint, or a
semantic provider such as MPFB/MakeHuman. Reports must continue to state this
limitation instead of implying full costume customization.

## Next Implementation Order

1. Build the reusable shape library path.
2. Explicitly import and license-review at least one common field-engineer
   accessory, preferably a hard hat, clipboard, or hand tool.
3. Replace field-engineer placeholder equipment with reusable-shape references
   in the approved recipe.
4. Teach Blender assembly to resolve `source_kind: reusable_shape`, attach the
   asset to the stable humanoid socket, apply transform/material overrides, and
   record shape provenance in `assembly_report.json`.
5. Add shape digests to checkpoint dependencies and mark assembly/readability
   stale when a referenced shape changes.
6. Add production-readiness validation that rejects reference-only, blockout,
   unclear-license, or unreviewed reusable shapes.
7. Rebuild and reimport the field engineer in the companion example project.
8. Compare the updated isometric preview against the base characters and
   confirm at least one role-specific accessory is visible at camera distance.

## Hard Blockers

The next blocker is not concept art or humanoid rigging. The blocker is
reviewed production accessory input:

- the addon must not download asset packs automatically;
- third-party model files belong under `res://build_me_godot/assets/`, not
  inside `addons/build_me_godot/`;
- every promoted accessory needs source, license, digest, scale/socket, and
  game-mode fit metadata;
- procedural primitives remain blockout/reference aids unless promoted with
  explicit review evidence.

Until at least one reviewed accessory is imported, the field engineer can be
considered a valid pipeline/animation/readability smoke test, but not a
meaningfully customized production character.

## Recommended Asset Search Policy

For common hard-surface accessories, search before generating:

```text
project reusable shape match
        |
        v
reviewed local or asset-store source
        |
        v
explicit user-approved import
        |
        v
procedural blockout or AI generation only as fallback
```

First-source candidates remain Quaternius and Kenney because their catalogs
are commonly used in game prototypes and have permissive CC0-style posture for
many packs. Individual Poly Pizza assets may be useful, but each model page
must be reviewed separately. Meshy or other generated-asset services should
remain reference-only or candidate sources until their exact output/license
terms are recorded for the project.

## Later Work

After the reusable accessory loop works, revisit semantic humanoid morphing.
MPFB/MakeHuman is the preferred bridge because it exposes artist-meaningful
human controls while keeping topology, rigging, and Blender ownership clear.
SMPL-X-backed research systems remain useful references, but should not become
a bundled default dependency unless code and model licenses, installation
burden, game-engine export, and runtime representation all fit the project
policy.
