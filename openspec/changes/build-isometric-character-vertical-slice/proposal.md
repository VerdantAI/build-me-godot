## Why

Build Me Godot has enough broad research tracks. The next useful step is a
vertical slice that proves the tool can get through one or two actual
play-test-ready characters for a concrete game assumption.

The selected assumption is `3d_isometric_party`: a Baldur's Gate-style party
RPG camera where readable silhouette, modular equipment, animation reliability,
and importable Godot scenes matter more than photorealistic pore detail or
arbitrary generated topology.

The original hypothesis was that AI could generate a usable mesh. Current
research and local constraints point to a better production path: AI should
drive character briefs, references, recipes, texture/material guidance, and
proxy geometry, while Blender and Godot own the production body, modular
equipment, rig, sockets, LODs, validation, and final scene assembly.

## What Changes

- Add a focused OpenSpec implementation plan for producing two
  `3d_isometric_party` humanoid characters.
- Introduce a versioned `character_recipe.json` contract that turns AI output
  into concrete body, equipment, material, socket, animation, LOD, and
  validation decisions.
- Prefer MPFB/MakeHuman-style canonical humanoid generation or existing CC0 /
  permissive rigged bases for production bodies.
- Use ComfyUI and local/open models as optional external orchestrators for
  reference sheets, portraits, palettes, decals, and material concepts.
- Keep TRELLIS, TripoSR, Hunyuan3D, and similar image-to-3D tools as
  reference/proxy providers for props or difficult components, not final
  humanoid production topology.
- Use Blender automation to assemble duplicate-only work files, attach modular
  equipment, validate sockets/scale/silhouette, create LOD handoff artifacts,
  and export Godot-ready assets.
- Register the final character scenes and validation reports in the existing
  character manifest under `res://build_me_godot/`.

## Out Of Scope

- No new foundation model training.
- No automatic installation of Blender addons, ComfyUI nodes, model weights,
  Python packages, asset packs, or hosted services.
- No SMPL-X production dependency unless a separate license decision enables
  it.
- No claim that AI reconstruction meshes are production topology.
- No general solution for VR, FPS, settlement-sim crowds, or low-poly
  high-volume games in this slice.
- No custom retargeting system beside Godot `SkeletonProfileHumanoid`.

## Relationship To Other Changes

- Builds on `add-godot-character-generation-workflow`, which already owns
  character manifests, reference runs, approval gates, and Blender handoff.
- Depends on `add-game-mode-profile-workflow` for the `3d_isometric_party`
  profile and budget assumptions.
- Narrows `evaluate-canonical-human-topology-providers` into a practical
  MPFB/MakeHuman or permissive-base production experiment.
- Uses `research-organic-inorganic-representation-planning` for armor, weapons,
  helmets, backpacks, tools, and other non-organic character parts.
- Keeps `assess-smplx-humanoid-character-policy` intact by treating SMPL-X as
  research-only unless separately licensed.
