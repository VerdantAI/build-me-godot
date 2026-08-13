# Quaternius onboarding mannequins

This directory contains a scoped copy of CC0 Quaternius rigged mannequin assets used by `res://addons/build_me_godot/examples/base_characters.tscn`.

The copy is intentionally limited to:

- `Models_with_rigging/Male_rigged.tscn`
- `Models_with_rigging/Female_Rigged.tscn`
- `Quaternius Meshes/*.tres` self-contained mesh resources referenced by those scenes
- `UAL1_Standard.animation_library.tres` as the shared animation library

The onboarding meshes use simple embedded Godot materials so the addon package does not depend on the local workflow texture cache. These files provide an immediately loadable two-character onboarding scene. They are not required for production projects, and project-specific characters, animations, and generated outputs should remain under `res://build_me_godot/`.
