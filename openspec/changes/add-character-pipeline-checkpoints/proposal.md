## Why

Build Me Godot should not regenerate every character artifact on every pass.
The current vertical slice already shows that the fastest reliable path starts
from a rigged humanoid base, adds AI-assisted references and recipe decisions,
assembles project-local outputs in Blender, and registers a Godot scene. That
pipeline needs durable checkpoints so artists and agents can resume from the
last valid stage instead of rerunning concept, body, assembly, import, and
animation work every time.

Reusable rigged and animated base characters should generally improve the AI
workflow rather than interfere with it. They constrain the hard parts:
topology, skeleton, animation compatibility, scale, and sockets. AI remains
useful for selecting a base, proposing morph/material/equipment decisions,
creating concept/reference images, drafting recipes, generating texture/decal
maps, and producing proxy references for difficult components.

## What Changes

- Add an OpenSpec change for character pipeline checkpoints.
- Define durable checkpoint records for reusable bases, approved references,
  recipes, Blender assembly, Godot import, animation smoke, and readability
  evidence.
- Treat rigged/animated bases as cached provider outputs with license,
  provenance, skeleton, pose, and game-mode compatibility metadata.
- Add resume semantics so the addon can decide whether a checkpoint is still
  valid or must be invalidated because upstream inputs changed.
- Prefer reusing permissive project assets, user-managed MPFB/MakeHuman
  exports, and reviewed animation libraries before invoking expensive local AI
  reconstruction/generation providers.
- Keep checkpoints under `res://build_me_godot/`, never inside the addon.

## Out Of Scope

- No automatic download or installation of base characters, animation packs,
  Blender addons, ComfyUI nodes, model weights, or Python packages.
- No hosted avatar platform dependency.
- No promotion of AI reconstruction meshes to production topology merely
  because they are cached.
- No custom retargeting system beside Godot `SkeletonProfileHumanoid`.
- No cache format that hides provider license or provenance information.

## References Reviewed

- Godot 4 retargeting docs: https://docs.godotengine.org/en/4.1/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot animation retargeting article:
  https://godotengine.org/article/animation-retargeting-in-godot-4-0/
- MPFB getting started and preset workflow:
  https://static.makehumancommunity.org/mpfb/docs/getting_started.html
- MPFB asset creation overview:
  https://static.makehumancommunity.org/mpfb/docs/assets/asset_creation_intro.html
- Adobe Mixamo FAQ:
  https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Ready Player Me full-body avatar docs:
  https://docs.readyplayer.me/ready-player-me/api-reference/avatars/full-body-avatars

## Research Summary

Reusable rigged bases do not block the AI workflow if the pipeline treats them
as canonical production substrates. Godot's retargeting guidance explicitly
expects shared animation through `SkeletonProfileHumanoid`, common bone names,
compatible rests, and imported `AnimationLibrary` resources. MPFB supports
stored human presets, morph controls, rigging, skins, hair, eyes, clothes, and
asset-authoring tools in Blender. Mixamo provides biped humanoid animations
and documents requirements that match our constraints: clean humanoid mesh,
neutral/default pose, centered scene, no extra helper objects, and no large
appendages during auto-rigging. Ready Player Me demonstrates the same
production principle with full-body, skinned, Mixamo-compatible avatars and
LOD/atlas options, though its hosted/commercial terms make it a research
comparison rather than a default local dependency.

The main risks are cache invalidation and representation drift, not AI
incompatibility. If a base mesh or animation library changes, downstream
texture maps, sockets, preview thumbnails, animation smoke reports, and
imported Godot resources may become stale. The checkpoint system must track
input digests and stage dependencies so stale artifacts are visible and
regenerable.
