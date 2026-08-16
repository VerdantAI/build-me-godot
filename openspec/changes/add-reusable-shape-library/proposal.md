## Why

Build Me Godot should not generate common accessories and hard-surface parts
one character at a time. The field-engineer vertical slice showed the problem:
procedural placeholder shapes are useful for socket tests, scale checks, and
readability previews, but they are not good production assets. Common objects
such as hard hats, belts, tools, clipboards, boots, pouches, glasses, cables,
panels, wheels, crates, barrels, and handles should be reusable project assets
with reviewed license metadata.

The system needs a reusable shape library so characters and props can reference
known shapes by ID, apply per-character transforms/material overrides, and
reserve generation for unusual or missing objects. This keeps generation cost
down, improves quality, makes checkpoints meaningful, and aligns with the
project goal: create infrastructure for play-test-ready Godot characters and
assets by reusing permissive tools and asset stores before writing bespoke
generation code.

## What Changes

- Add an OpenSpec change for a project-local reusable shape library.
- Define reusable shapes as reviewed project assets stored under
  `res://build_me_godot/assets/`, never inside the addon.
- Require recipes to reference common shapes by stable asset ID instead of
  regenerating them per character.
- Add provenance, license, source URL, source digest, socket compatibility,
  scale, material slots, collision, LOD, and game-mode fit metadata for each
  reusable shape.
- Add an asset search/import decision point before procedural or AI generation
  for common objects.
- Keep procedural placeholders as blockout/reference aids unless explicitly
  promoted with review evidence.

## Out Of Scope

- No automatic download from Quaternius, Kenney, Poly Pizza, Meshy, asset
  stores, GitHub, or model hosting services.
- No bundled third-party asset packs inside the addon.
- No generated hard-surface placeholder is promoted to production merely
  because it fits a socket.
- No custom asset marketplace client is implemented by this change.
- No change to the current humanoid base, `neutral_a_pose_30deg_v1` contract,
  or Godot `SkeletonProfileHumanoid` retargeting policy.

## References

- Quaternius assets and FAQ: https://quaternius.com/?page_id=12 and
  https://quaternius.com/faq.html
- Kenney assets: https://kenney.nl/assets
- Kenney Factory Kit on OpenGameArt: https://opengameart.org/content/factory-kit
- Poly Pizza public-domain asset catalog: https://poly.pizza/
- Existing candidate registry:
  `addons/build_me_godot/integrations/hard_surface_asset_candidates.json`

## Current Status

Candidate source metadata now exists for common hard-surface accessory
providers, but no third-party model files are downloaded, bundled, or promoted.
The field-engineer assembly deliberately excludes placeholder accessories from
the production GLB, so the reusable-shape library is the next required step
before the character can satisfy meaningful production customization.

## Next Steps

1. Define the project-local `shape_library.json` and per-shape `shape.json`
   metadata format.
2. Add a read-only lookup service that can answer whether a recipe part already
   has a compatible reviewed reusable shape.
3. Add an explicit import/review workflow for user-owned or asset-store shapes;
   imported files must land under `res://build_me_godot/assets/`.
4. Import one reviewed accessory for the field engineer and record source URL,
   license, digest, game-mode fit, socket compatibility, and production status.
5. Update Blender assembly to resolve `source_kind: reusable_shape` and attach
   it to stable humanoid sockets.
6. Add checkpoint invalidation and production-readiness checks for reusable
   shape digests and license state.
