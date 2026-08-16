## 1. Research And Policy

- [x] 1.1 Record reviewed reusable-base candidates, including project bases,
  MPFB/MakeHuman exports, manually imported asset-store characters, and shared
  animation libraries.
- [x] 1.2 For each candidate, record code/content license, commercial-use
  posture, source URL or local source, required manual install steps, skeleton
  profile, pose contract, scale, UV assumptions, and game-mode fit.
- [x] 1.3 Document why reusable rigged bases are compatible with AI-assisted
  recipe, texture, material, equipment, and validation workflows.
- [x] 1.4 Define which provider families are production candidates versus
  immutable research references.

## 2. Checkpoint Contract

- [x] 2.1 Add `checkpoint_index.json` schema version 1 under
  `res://build_me_godot/characters/<character_id>/checkpoints/<version>/`.
- [x] 2.2 Define stage statuses: `valid`, `stale`, `failed`, `missing`, and
  `pending`.
- [x] 2.3 Record stage inputs, paths, digests, provider IDs, license states,
  warnings, and reviewed timestamps.
- [x] 2.4 Preserve unknown fields when checkpoint records are updated.

## 3. Resume And Invalidation

- [x] 3.1 Implement digest-based stale detection for local files.
- [x] 3.2 Implement downstream invalidation rules for prompt, reference,
  recipe, base body, animation library, assembly, and game-mode changes.
- [x] 3.3 Add CLI or dock actions for checkpoint status, resume-from-stage,
  mark-reviewed, invalidate-stage, and explain-stale.
- [x] 3.4 Ensure resume actions never install dependencies, download models, or
  mutate external tool directories.

## 4. Base Character Checkpoints

- [x] 4.1 Add a base-body checkpoint validator for source path, digest,
  license state, `neutral_a_pose_30deg_v1`, scale, and
  `SkeletonProfileHumanoid` compatibility.
- [x] 4.2 Add animation-library checkpoint validation for Idle and Walk smoke
  evidence.
- [x] 4.3 Block production-base status for research-only or unclear-license
  topology.
- [x] 4.4 Allow manually reviewed project bases and user-managed MPFB exports
  to be reused across characters.

## 5. Vertical Slice Integration

- [x] 5.1 Write checkpoints for the current field-engineer path after recipe
  approval, Blender assembly, Godot scene registration, and animation smoke.
- [x] 5.2 Support resuming from an existing valid base body and animation
  library when generating another `3d_isometric_party` character.
- [x] 5.3 Add tests proving concept/reference generation is skipped when a
  valid approved-reference checkpoint already exists.
- [x] 5.4 Add tests proving Blender assembly is skipped when base, recipe, and
  reference digests match an existing valid assembly checkpoint.

## 6. Documentation And Validation

- [x] 6.1 Document checkpoint stages, invalidation rules, and user-visible
  resume behavior.
- [x] 6.2 Document the recommended cached path: reusable rigged base,
  AI-assisted recipe/materials, Blender assembly, Godot import, animation
  smoke, readability capture.
- [x] 6.3 Run headless editor load.
- [x] 6.4 Run GDScript tests.
- [x] 6.5 Run Python parser checks if Python integration code changes.
- [x] 6.6 Run `openspec validate add-character-pipeline-checkpoints --strict`.
- [x] 6.7 Run `git diff --check`.
