# Blender integration

The Blender scripts create and validate a standardized humanoid proxy from an immutable reconstruction. They are automation and validation aids, not automatic production retopology.

`build_humanoid_character.requirements.json` is the machine-readable builder contract. It declares the minimum Blender version, required operators, configuration fields, pose contract, and expected output/report fields. The environment CLI's explicit `--deep-check` runs `probe_builder.py` with Blender factory settings to verify those operators without opening or changing a project file.

The character build configuration must provide project-relative or absolute paths for `source_mesh`, `views_dir`, `output_dir`, and `animation_asset`. Build Me Godot passes the Godot project root explicitly; the scripts do not assume a particular repository layout.

The builder originated in Inhuman Entertainment's MIT-licensed Burb Sweeper humanoid pipeline and was generalized for Build Me Godot. See `ATTRIBUTIONS.md`.

## Isometric recipe assembly

`assemble_isometric_character.py` is the first post-concept vertical-slice
builder for `3d_isometric_party` characters. It reads a validated
`character_recipe.json`, imports the project-provided humanoid body as a
project-local work basis, places approved reference images, creates socket
empties, adds primitive placeholder equipment, saves a `.blend` work file, and
writes `assembly_report.json`.

Run it only as an explicit Blender action, for example:

```bash
blender -b --factory-startup \
  --python addons/build_me_godot/integrations/blender/assemble_isometric_character.py \
  -- \
  --recipe res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json \
  --project-root /path/to/godot/project \
  --output-dir res://build_me_godot/characters/field_engineer/assembly/v1
```

The script does not install Blender addons, ComfyUI nodes, Python packages,
model weights, or asset packs. It refuses output directories outside the Godot
project or inside `addons/build_me_godot/`.

## Reusable character checkpoints

The character pipeline should reuse reviewed rigged bases and animation
libraries whenever possible. Checkpoints let a later run skip concept
generation, body selection, Blender assembly, or Godot scene registration when
the recorded inputs and digests still match.

Reusable bases do not replace AI assistance. They make the AI work safer by
freezing topology, skeleton, rest pose, scale, sockets, and UV assumptions.
AI can still select a reviewed base, draft a recipe, propose morph/material
changes, create texture/decal maps, plan modular equipment, and generate proxy
references for components that will be rebuilt or reviewed.

The reviewed candidate families are recorded in
`res://addons/build_me_godot/integrations/reusable_base_candidates.json`:

- project-provided rigged meshes and reviewed user imports are production
  candidates when license, pose, scale, and `SkeletonProfileHumanoid`
  compatibility are recorded;
- user-managed MPFB/MakeHuman exports are production candidates only after
  explicit local installation and asset/output license review;
- shared animation libraries are checkpointed independently from character
  textures and equipment;
- SMPL-X-backed, TRELLIS, TripoSR, Hunyuan3D, SHERT, HumanGaussian, HAHA, and
  similar research outputs remain immutable references unless a separate
  production conversion and license decision exists.

Checkpoint records are project-local and belong under
`res://build_me_godot/characters/<character_id>/checkpoints/<version>/`.
