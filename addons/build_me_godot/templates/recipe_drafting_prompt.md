# Isometric Character Recipe Draft Prompt

You are drafting a structured Build Me Godot character recipe after concept
art has already been approved. Return JSON only. Do not invent installed
providers, downloaded model weights, commercial license approvals, or final
asset paths.

The target game-mode profile is `3d_isometric_party`: medium-distance angled
camera, readable silhouette, modular equipment, shared humanoid animation,
medium texture budget, and project-local Godot import.

Use this policy:

- Prefer `project_rigged_meshes`, MPFB/MakeHuman exports, or other
  user-reviewed canonical humanoid bodies for production topology.
- Do not choose SMPL-X, SHERT, HumanGaussian, HAHA, TRELLIS, TripoSR,
  Hunyuan3D, or other reconstruction providers as production humanoid body
  topology.
- Use reconstruction providers only as `proxy_reference` inputs unless a
  separate license and production-conversion decision is provided.
- Use primitives or existing project assets before proposing custom generated
  meshes for weapons, tools, helmets, pouches, belts, and simple props.
- Set `automatic_downloads_allowed` to `false` for every provider record.
- Use `license_state: "reviewed_or_user_supplied"` only when the input context
  explicitly says that provider or asset has been reviewed.

Required top-level fields:

```json
{
  "schema_version": 1,
  "character_id": "",
  "display_name": "",
  "recipe_version": "",
  "reference_version": "",
  "game_mode_profile_id": "3d_isometric_party",
  "source": {},
  "body": {},
  "equipment": [],
  "sockets": [],
  "materials": {},
  "animation": {},
  "lod": {},
  "validation": {},
  "outputs": {}
}
```

Use these representation classes only:

```text
existing_asset
organic_mesh
hard_surface_mesh
primitive
lathed_or_revolved
curve
cad_code
brep_or_step
nurbs_surface
cloth_or_flexible_mesh
shader_or_volume
decal
proxy_reference
existing_asset_or_proxy_reference
```

Return a conservative draft. If uncertain, add a warning or
`manual_review_required` entry rather than filling in false certainty.
