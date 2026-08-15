## Context

The addon already records project context, character metadata, rigged mesh
slots, prompts, run history, approvals, and downstream guidance. It also
reports Ollama readiness as an optional local capability. The missing piece is
a structured description of the game being targeted.

Game mode affects:

- prompt language and reference-sheet needs;
- texture, material, and atlas strategy;
- mesh density and deformation expectations;
- skeleton and socket priorities;
- LOD, impostor, or sprite strategy;
- how many characters might be visible at once;
- whether close-up face/hands matter;
- whether outputs are production candidates or only concept/reference assets.

## Goals / Non-Goals

**Goals**

- Make game-mode profile capture visible in the Godot editor, before or during
  character draft creation.
- Provide quick preset selection for common modes.
- Provide a survey for custom games and mixed-mode projects.
- Let a local Ollama model assist with profile drafting when configured.
- Persist selected profiles as project-local data and copy the relevant
  snapshot into each character manifest.
- Use the profile to adjust defaults and validation expectations without
  silently running external tools.
- Expose profile state through deterministic headless JSON commands.

**Non-goals**

- A full game-design questionnaire.
- Automatic hosted chat or telemetry.
- Automatic model pulls or Ollama installation.
- Replacing manual art direction.
- Locking a project to one mode forever; characters can override the project
  default when a hero/NPC/crowd asset needs different treatment.

## Game-Mode Profile Shape

Profiles should be versioned JSON records. A project default lives under:

```text
res://build_me_godot/project/game_mode_profile.json
```

Each character manifest stores a snapshot or override under a field equivalent
to:

```json
{
  "game_mode_profile": {
    "schema_version": 1,
    "profile_id": "first_person_vr",
    "display_name": "First-person VR",
    "source": "preset",
    "camera": {
      "distance_class": "vr_close",
      "primary_view": "first_person",
      "close_inspection": true
    },
    "volume": {
      "expected_simultaneous_characters": 4,
      "named_character_ratio": 0.8
    },
    "budgets": {
      "mesh": "hero",
      "texture": "hero",
      "rig": "hero_closeup",
      "materials": "high"
    },
    "lod": {
      "strategy": "manual_lod",
      "requires_impostors": false
    },
    "priorities": [
      "hand_deformation",
      "material_scale",
      "interaction_anchors",
      "collision_proxies"
    ],
    "validation": {
      "requires_closeup_renders": true,
      "requires_far_readability": false,
      "requires_crowd_budget": false
    },
    "notes": "Project-specific overrides remain editable."
  }
}
```

The exact manifest field names may follow existing `CharacterStore` patterns,
but the data must remain stable enough for agents and downstream Blender
automation.

## Baseline Presets

The first built-in presets should match the research assumptions:

| Profile ID | Primary UI label | Default implication |
| --- | --- | --- |
| `3d_isometric_party` | 3D isometric party RPG | readable medium-distance characters with modular equipment and occasional portrait close-ups |
| `3d_isometric_settlement` | 3D isometric settlement sim | high-volume workers with shared rigs, atlases, LODs, and job silhouettes |
| `first_person_vr` | First-person VR | close stereo inspection, hands, interaction anchors, collision, and high material confidence |
| `first_person_fps` | First-person FPS | world bodies plus optional first-person arms, weapon sockets, hit zones, and combat-distance readability |
| `low_poly_high_volume` | Low-poly / high-volume | simplified canonical variants, palette swaps, batching, and tiny-thumbnail readability |
| `custom` | Custom / mixed | survey-defined values with optional Ollama assistance |

Preset copy should be concise. The UI should not try to teach the entire
pipeline in visible text; details can live in tooltips and docs.

## Editor UX

### Quick Dropdown

The character dock should expose a compact game-mode selector near project
context and character metadata:

- default value from the project profile if one exists;
- selectable baseline presets;
- `custom` option;
- reset-to-project-default action;
- per-character override indicator.

Changing the dropdown updates draft state only. It does not requeue generation,
alter already approved runs, or rewrite external assets.

### Survey

When `custom` is selected, or when the user chooses to refine a preset, the
dock should open a survey with constrained controls:

- camera/view style;
- expected simultaneous characters;
- named hero versus repeated variant mix;
- target platform class;
- close-up face/hands importance;
- modular equipment and sockets;
- texture/material budget;
- LOD/impostor/sprite expectations;
- notes for art direction.

The survey writes structured profile fields, not only prose. The profile may
also store optional notes for human context.

### Optional Ollama Chat

If Ollama readiness passes for a configured local model, the survey can offer
an assisted chat mode. The chat should:

- use only local project context and user-entered answers;
- send no data to hosted services;
- request structured JSON conforming to the profile schema;
- show the proposed profile diff before saving;
- allow the user to accept, edit, or discard the proposal;
- record that the source was `ollama_assisted` and include model provenance.

If Ollama is missing or the configured model is unavailable, the same workflow
remains usable through dropdown and survey controls.

## Pipeline Effects

The selected game-mode profile should influence defaults and validation, not
override explicit user choices.

Prompt/reference generation:

- isometric party profiles prefer full-body reference sheets with equipment
  readability and optional portrait notes;
- settlement profiles prefer job silhouettes, color/material families, and
  variant-friendly references;
- VR profiles emphasize hands, interaction surfaces, material scale, and
  close-up view evidence;
- FPS profiles include weapon/equipment socket visibility and may request
  first-person arm references separately;
- low-poly profiles emphasize silhouette, color blocks, and simplified forms.

Blender/conformance guidance:

- writes the profile snapshot into `mesh_guidance.json`;
- records budget classes and validation priorities;
- flags outputs that are too dense, too detailed, or not detailed enough for
  the selected mode;
- suggests LOD, atlas, impostor, or separate first-person-arm follow-up work
  where applicable.

Provider evaluation:

- copies `profile_id` and budget assumptions into provider scorecards;
- prevents comparing providers across unrelated game modes without an explicit
  cross-mode note;
- keeps dense AI reconstruction as reference-only for low-poly/high-volume
  modes unless a simplification path exists.

## Data Boundaries

- Project profiles live under `res://build_me_godot/project/`.
- Character-specific snapshots live in
  `res://build_me_godot/characters/<character_id>/character.json`.
- Ollama chat transcripts, if stored at all, live under the character or
  project folder and are redacted from support reports by default.
- No profile, survey, or chat data is stored in `addons/build_me_godot/`.
- No prompts or project metadata are sent to remote endpoints by this change.

## Agent Contract

Agents should be able to:

- inspect project and character game-mode profiles as JSON;
- set a profile by preset ID;
- apply a supplied custom profile JSON after validation;
- ask for the survey questions/schema without UI automation;
- run optional Ollama-assisted drafting only when a local model is already
  configured and the user explicitly requests it;
- see changed paths and validation warnings in deterministic JSON output.

Suggested commands, following existing CLI style:

```text
profile inspect --character-id field_engineer
profile set-preset --character-id field_engineer --profile-id first_person_fps
profile validate --profile-json res://build_me_godot/project/custom_profile.json
profile apply --character-id field_engineer --profile-json ...
profile survey-schema
```

The exact command names may follow existing CLI conventions.

## Risks / Trade-offs

- Too many options can slow draft creation. The default path should be the
  dropdown, with survey/chat as refinement tools.
- Presets can overfit named reference games. The schema should store the
  production assumption, not copyrighted game names or imitative art direction.
- Ollama output can be plausible but wrong. It must propose structured data for
  review, not silently edit durable workflow state.
- Character-specific overrides can diverge from the project default. The UI
  should make overrides visible and easy to reset.

## Migration Plan

1. Add profile schema, baseline presets, and validation helpers.
2. Add project default profile storage and character snapshot fields.
3. Add dock dropdown and custom survey UI.
4. Propagate profile snapshots into prompts, mesh guidance, and conformance
   artifacts.
5. Add optional Ollama-assisted profile drafting behind readiness checks.
6. Add headless profile inspect/set/validate commands.
7. Add tests and documentation.

## Open Questions

- Should a new project default profile be required before any character draft,
  or should `custom_unset` allow draft creation with warnings?
- Should a character store a full profile snapshot, a reference to the project
  profile, or both?
- Which profile fields should be considered prompt defaults versus validation
  requirements?
- Should Ollama chat transcripts be saved by default, summarized only, or
  discarded after structured profile acceptance?
