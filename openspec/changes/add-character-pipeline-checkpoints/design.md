## Context

The `build-isometric-character-vertical-slice` work has proven a practical
shape for the first character:

```text
approved concept/reference
        |
        v
validated character recipe
        |
        v
rigged humanoid base + animation library
        |
        v
Blender assembly/export
        |
        v
Godot scene wrapper + animation smoke
```

Without checkpoints, every iteration risks repeating expensive or manual work.
With checkpoints, a user can change one thing, such as material palette or
helmet choice, and resume from the correct stage without rebuilding the base
body or regenerating concept art.

## Checkpoint Model

Add a project-local checkpoint index per character:

```text
res://build_me_godot/characters/<character_id>/checkpoints/<version>/checkpoint_index.json
```

Suggested shape:

```json
{
  "schema_version": 1,
  "character_id": "field_engineer",
  "version": "v1",
  "game_mode_profile_id": "3d_isometric_party",
  "stages": {
    "base_body": {
      "status": "valid",
      "path": "res://build_me_godot/bases/humanoid/quaternius_male/base.glb",
      "digest": "sha256:...",
      "provider_id": "project_rigged_meshes",
      "license_state": "reviewed",
      "pose_contract": "neutral_a_pose_30deg_v1",
      "skeleton_profile": "SkeletonProfileHumanoid",
      "animation_compatible": true
    },
    "references": {
      "status": "valid",
      "paths": [],
      "source_run_id": "city_worker_reference",
      "digest": "sha256:..."
    },
    "recipe": {
      "status": "valid",
      "path": "res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json",
      "digest": "sha256:..."
    },
    "assembly": {
      "status": "valid",
      "report": "res://build_me_godot/characters/field_engineer/assembly/v1/assembly_report.json",
      "inputs": ["base_body", "references", "recipe"],
      "digest": "sha256:..."
    },
    "godot_scene": {
      "status": "valid",
      "path": "res://build_me_godot/characters/field_engineer/field_engineer.tscn",
      "inputs": ["assembly"],
      "digest": "sha256:..."
    },
    "animation_smoke": {
      "status": "valid",
      "report": "res://build_me_godot/characters/field_engineer/reports/v1/animation_smoke.json",
      "inputs": ["base_body", "godot_scene"]
    },
    "readability": {
      "status": "pending",
      "report": "",
      "inputs": ["godot_scene"]
    }
  }
}
```

Each stage records:

- `status`: `valid`, `stale`, `failed`, `missing`, or `pending`;
- input stage names and source paths;
- content digests for local files where practical;
- provider IDs and license state where an external source contributes;
- warnings that should be visible in the Godot dock and CLI output.

## Base Character Reuse

Reusable bases should be first-class provider outputs. A base checkpoint is
valid only if it records:

- source path and digest;
- code/content/license records;
- skeleton root and major bone map;
- pose contract;
- scale in meters;
- Godot `SkeletonProfileHumanoid` compatibility;
- available animation libraries or retarget sources;
- game-mode compatibility notes such as `isometric`, `vr_closeup`, or
  `low_poly_high_volume`.

The checkpoint should support several base families:

- `project_rigged_meshes`: checked-in or user-copied local bases already
  reviewed for license and project use;
- `mpfb_external_export`: user-managed MPFB/MakeHuman export from Blender;
- `asset_store_import`: manually imported asset-store character with recorded
  license;
- `animation_library_only`: a shared animation library such as the current
  Quaternius example library;
- `research_reference`: SMPL-X, TRELLIS, TripoSR, Hunyuan3D, HumanGaussian,
  SHERT, or similar outputs that can inform decisions but cannot become
  production topology without a separate approval record.

## AI Compatibility

Starting from rigged bases does not remove AI from the workflow. It changes AI
from "invent a complete production mesh" to safer tasks:

- select the closest reviewed base for a character role and game mode;
- estimate morph values or MPFB preset/macro targets;
- propose recipe JSON from a concept sheet;
- generate or revise albedo, roughness, normal, decal, and palette maps;
- produce material references and readable isometric thumbnails;
- generate proxy references for equipment that will be rebuilt procedurally or
  with existing assets;
- identify stale checkpoints after a prompt, base, recipe, or asset changes.

Potential interference points:

- AI-generated texture maps may not align with UVs unless the base UV layout is
  part of the checkpoint.
- AI-suggested anatomy changes may exceed the base morph range and require a
  new base or manual modeling.
- Animation reuse can break if the base skeleton rest pose, bone map, or scale
  drifts.
- Cached concept references can become misleading if the production base and
  equipment plan diverge too far from the approved art.

These are validation problems, not blockers.

## Resume And Invalidation Rules

The checkpoint system should invalidate downstream stages when upstream inputs
change:

| Changed input | Stale stages |
| --- | --- |
| prompt only | recipe draft, maybe references |
| approved reference image | recipe, assembly, readability |
| base body mesh or rig | assembly, Godot scene, animation smoke, readability |
| animation library | Godot scene, animation smoke |
| recipe body/equipment/material plan | assembly, Godot scene, readability |
| exported GLB | Godot scene, animation smoke, readability |
| game-mode profile | recipe, assembly, readability and budget checks |

The UI and CLI should expose a simple action model:

- `checkpoint-status`;
- `resume-from <stage>`;
- `mark-reviewed <stage>`;
- `invalidate <stage>`;
- `explain-stale`.

No resume action should silently download, install, or mutate external tools.

## Godot Dock Implications

The dock should eventually show checkpoints as a compact stage list:

```text
Base        valid     Quaternius male, humanoid, idle/walk
References  valid     6 images, qwen local run
Recipe      valid     3d_isometric_party, medium texture budget
Assembly    valid     GLB exported, placeholders excluded
Scene       valid     AnimationPlayer + sockets
Animation   valid     Idle/Walk smoke passed
Readability pending   thumbnail not captured
```

This can be implemented as a status panel before adding any heavy rebuild UI.

## Validation

Add tests for:

- checkpoint index read/write and unknown-field preservation;
- digest-based stale detection;
- downstream invalidation;
- `SkeletonProfileHumanoid` and pose-contract metadata on base checkpoints;
- refusal to mark research-only topology as a production base;
- CLI output for valid, stale, failed, and pending stages;
- generated scene resume from existing assembly without rerunning concept or
  Blender work;
- no writes into `addons/build_me_godot/` or external tool directories.
