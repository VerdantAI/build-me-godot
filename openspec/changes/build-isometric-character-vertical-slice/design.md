## Context

This change turns the broad character-generation research into a short
implementation path: create two playable humanoid characters for a
`3d_isometric_party` game assumption.

The target is not cinematic hero fidelity. It is a character that can be
spawned into a Godot play-test scene, viewed from an angled medium-distance
camera, animated on a humanoid skeleton, and visually understood by role,
equipment, color, and silhouette.

## Selected Production Strategy

Use AI for decisions and reference evidence, not as the owner of final topology:

```text
Godot character draft
        |
        v
game-mode profile: 3d_isometric_party
        |
        v
AI-assisted character recipe
        |
        +-- concept sheet / portrait / palette / material refs
        +-- canonical body provider choice
        +-- modular equipment plan
        +-- prop representation plan
        +-- socket and animation expectations
        |
        v
Blender assembly and validation
        |
        v
Godot humanoid scene + report
```

This is intentionally different from:

```text
prompt -> image-to-3D -> arbitrary humanoid mesh -> try to repair it
```

The latter can still provide visual references, but should not be the default
production path for humanoids.

## Target Characters

The first slice should produce two distinct characters that exercise modularity
without requiring an enormous content library:

1. `party_fighter_v1`
   - medium/heavy build;
   - armor or padded gambeson silhouette;
   - sword and shield or two-handed weapon sockets;
   - readable team/material colors from isometric distance;
   - idle, walk, and simple attack/play-test animation evidence.

2. `village_healer_v1`
   - lighter body or robe silhouette;
   - staff, pouch, or book prop;
   - cloth/robe material blocks;
   - idle, walk, and cast/use animation evidence.

These are example fixtures, not copyrighted character targets. Prompts and
reference text should describe original archetypes and production needs rather
than imitate a named game's art.

## Character Recipe Contract

The new durable artifact is a project-local recipe, stored alongside the
character manifest:

```text
res://build_me_godot/characters/<character_id>/recipes/<version>/character_recipe.json
```

Suggested shape:

```json
{
  "schema_version": 1,
  "character_id": "party_fighter",
  "recipe_version": "v1",
  "game_mode_profile_id": "3d_isometric_party",
  "source": {
    "manifest_version": "v3",
    "approved_reference_run": "run_20260815_103000",
    "ai_assistance": [
      {
        "tool": "comfyui",
        "role": "concept_reference",
        "locality": "local_user_managed",
        "license_state": "reviewed_or_user_supplied"
      }
    ]
  },
  "body": {
    "strategy": "canonical_humanoid",
    "provider": "mpfb_external_or_project_base",
    "production_topology_candidate": true,
    "pose_contract": "neutral_a_pose_30deg_v1",
    "scale_meters": 1.8,
    "morph_targets": {},
    "manual_review_required": []
  },
  "equipment": [
    {
      "part_id": "main_weapon",
      "taxonomy": "inorganic_mechanical",
      "representation": "existing_asset_or_proxy_reference",
      "socket": "right_hand",
      "required": true
    }
  ],
  "materials": {
    "palette": ["iron", "worn_leather", "muted_cloth"],
    "texture_budget": "medium",
    "atlas_group": "party_humanoid_v1"
  },
  "animation": {
    "profile": "SkeletonProfileHumanoid",
    "required_clips": ["idle", "walk"],
    "role_clips": ["attack"],
    "retarget_source": "project_humanoid_library"
  },
  "lod": {
    "strategy": "manual_lod",
    "required_levels": ["lod0", "lod1"],
    "impostor_optional": true
  },
  "validation": {
    "camera_profile": "isometric_medium",
    "requires_thumbnail_readability": true,
    "requires_socket_report": true,
    "requires_animation_smoke": true
  },
  "outputs": {
    "blender_work_file": "",
    "godot_scene": "",
    "validation_report": ""
  }
}
```

The recipe is the bridge between AI and production. AI may draft or amend it,
but every provider entry must carry locality, license state, provenance, and
manual-review markers.

## Provider Roles

### Canonical Body Provider

Preferred first targets:

- user-managed MPFB2 / MakeHuman inside Blender;
- existing project-provided humanoid base mesh;
- permissively licensed CC0/example bodies already accepted by the project.

The provider must produce or point to a conventional mesh/rig that can be
validated against the humanoid contract. It must not require SMPL-X by default.

### Concept And Texture Reference Provider

Preferred orchestrator:

- user-managed ComfyUI endpoint with explicitly configured local workflows.

Candidate local/open model classes:

- permissively licensed image models for concept sheets, portraits, palettes,
  decal ideas, and material references;
- model licenses are checked separately from ComfyUI code.

The addon records outputs and provenance but does not install nodes, pull
models, or mutate ComfyUI.

### Recipe Drafting Provider

Optional:

- local Ollama or another local LLM endpoint already configured by the user.

The model can propose structured JSON for the recipe from project context,
prompt text, and approved references. The proposal must be validated and shown
for review before durable state changes.

### Proxy 3D Provider

Allowed only for reference/proxy use in this slice:

- TRELLIS;
- TripoSR;
- Hunyuan3D after custom license review;
- similar local image-to-3D tools with reviewed code and weight licenses.

Use cases:

- helmet silhouette proxy;
- weapon or staff rough blockout;
- backpack or accessory volume;
- material/normal/displacement inspiration.

Proxy outputs remain immutable references unless a separate production
conversion path is approved.

## Blender Assembly

Blender automation should consume the recipe and approved references, then
create duplicate-only work under the character folder. The first prototype can
be simple and deterministic:

- import or create the canonical body;
- place approved reference planes;
- link or append reviewed modular equipment assets;
- create simple proxy props from primitives where no asset exists;
- assign material placeholders from the palette;
- verify humanoid skeleton naming/profile expectations;
- add or verify sockets for hands, head, back, belt, and optional off-hand;
- export a Godot-readable scene asset;
- write validation reports and preview renders.

Automation should make the character playable, not perfect. Unresolved issues
become validation warnings in the manifest rather than hidden failures.

## Godot Import And Play-Test Scene

Each character must register:

- final `.tscn` path;
- imported mesh/material resources;
- animation library or clip paths;
- sockets/attachment nodes;
- validation report path;
- preview thumbnails from the isometric camera.

The slice should include a small play-test scene or fixture that can spawn both
characters and cycle idle/walk/role animations. This fixture is for validation,
not a sample game.

## Quality Gates

A character is accepted for this slice only when:

- all durable files are under `res://build_me_godot/`;
- source provider paths and local model roots are not copied into the addon;
- no unlicensed or research-only provider output is promoted to final asset;
- the body uses a conventional rigged mesh, not a raw reconstruction mesh;
- Godot `SkeletonProfileHumanoid` compatibility is reported;
- required sockets exist;
- idle and walk animation smoke tests pass or have explicit known limitations;
- an isometric thumbnail/readability render exists;
- a manifest points to the final scene and reports warnings.

## Implementation Phases

### Phase 1: Contract And Fixtures

Add recipe schema, fixtures for `party_fighter_v1` and `village_healer_v1`,
validation helpers, and deterministic headless inspection.

No external provider execution is required in this phase. Fixture recipes may
refer to existing project/example rigs and placeholder equipment.

### Phase 2: Godot Workflow Integration

Expose recipe creation from an approved reference run and
`3d_isometric_party` profile. Add manifest links, changed-path reporting, and
warnings for missing providers, missing equipment, or incomplete animation
sets.

### Phase 3: Blender Assembly Prototype

Add a disabled-by-default, explicit Blender job that reads the recipe and
creates a project-local work file/export package. Start with existing bases and
simple modular props before integrating MPFB automation.

### Phase 4: AI-Assisted Recipe Drafting

Allow optional local Ollama or equivalent local LLM assistance to draft recipe
JSON. Validate, diff, and require user acceptance. Do not treat model output as
trusted.

### Phase 5: External Provider Adapters

Add readiness-only provider records for MPFB/MakeHuman, ComfyUI concept
workflows, and optional proxy 3D providers. Execution remains explicit and
user-managed. Provider scorecards are scoped to `3d_isometric_party`.

### Phase 6: Play-Test Acceptance

Add a validation fixture that loads both generated character scenes in Godot,
checks required nodes/resources, and records preview/readability evidence.

## Research Notes

Current tool signals support this plan:

- MPFB2/MakeHuman is the strongest production-oriented canonical human
  candidate because it lives in Blender and exposes controlled human variation,
  while source licensing keeps it external.
- ComfyUI is a strong local orchestrator for image/reference generation but is
  GPL-licensed and should remain user-managed.
- SMPL-X-backed systems are architecturally relevant but should remain
  research-only by default because standard SMPL-X licensing is not a
  permissive production dependency.
- TRELLIS, TripoSR, Hunyuan3D, and similar image-to-3D systems are useful for
  proxy/reference geometry, but their topology and provider licenses make them
  inappropriate as the default humanoid production substrate.
- CC0 or permissively licensed asset stores are strategically important:
  shipping a play-test-ready slice quickly is easier through modular assembly
  than through bespoke model generation.

## Open Questions

- Should the first body provider be MPFB automation or an existing project
  humanoid base fixture?
- Which exact CC0/permissive equipment kits should be blessed for the first
  fixture characters?
- Should `character_recipe.json` be nested under the existing character
  manifest or remain a separate versioned artifact linked from it?
- How strict should LOD acceptance be for the first slice: required LOD1 mesh,
  or documented LOD plan plus isometric thumbnail evidence?
- Should the initial play-test fixture live in the addon tests, under
  `res://build_me_godot/`, or both?
