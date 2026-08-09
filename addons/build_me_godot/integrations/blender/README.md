# Blender integration

The Blender scripts create and validate a standardized humanoid proxy from an immutable reconstruction. They are automation and validation aids, not automatic production retopology.

`build_humanoid_character.requirements.json` is the machine-readable builder contract. It declares the minimum Blender version, required operators, configuration fields, pose contract, and expected output/report fields. The environment CLI's explicit `--deep-check` runs `probe_builder.py` with Blender factory settings to verify those operators without opening or changing a project file.

The character build configuration must provide project-relative or absolute paths for `source_mesh`, `views_dir`, `output_dir`, and `animation_asset`. Build Me Godot passes the Godot project root explicitly; the scripts do not assume a particular repository layout.

The builder originated in Inhuman Entertainment's MIT-licensed Burb Sweeper humanoid pipeline and was generalized for Build Me Godot. See `ATTRIBUTIONS.md`.
