## Why

Build Me Godot cannot choose useful character-generation, conformance, LOD,
texture, rigging, or validation defaults from provider capability alone. A
first-person VR character, an FPS enemy, an isometric party member, an
isometric settlement worker, and a low-poly crowd unit all need different
budgets, camera-readability checks, and asset-volume assumptions.

The Godot editor tool should therefore capture the target game mode before
prompting, generation, conformance, and provider research decisions become
durable workflow state. The simplest UI can be a dropdown with known presets.
When the project does not fit a preset, the tool should provide a short survey.
If a local Ollama model is configured and ready, the survey may also become a
local chat that proposes a structured game-mode profile for user review.

## What Changes

- Add a Godot game-mode profile workflow to project and character draft state.
- Provide baseline selectable presets for `3d_isometric_party`,
  `3d_isometric_settlement`, `first_person_vr`, `first_person_fps`, and
  `low_poly_high_volume`.
- Add a survey path for custom or mixed game assumptions.
- Add an optional local Ollama chat-assistant path that proposes profile JSON
  from user answers and project context, but never applies it without review.
- Propagate the selected profile into prompt defaults, reference generation
  settings, mesh guidance, conformance plans, provider scorecards, and
  validation gates.
- Keep all profile data project-local under `res://build_me_godot/`.

## Out Of Scope

- No hosted LLM or remote inference path is added.
- No Ollama model is installed, pulled, downloaded, or started automatically.
- No provider is selected automatically solely because a game mode was chosen.
- No production budgets are enforced as hard engine limits until later
  implementation proposals define exact validators.

## Relationship To Other Changes

- Extends `add-godot-character-generation-workflow` by making game-mode profile
  capture part of Godot-owned draft state.
- Feeds `evaluate-canonical-human-topology-providers`, which already requires
  provider research to declare a game assumption.
- Consumes `installation-environment-utilities` readiness for optional Ollama
  availability, without replacing setup checks.
