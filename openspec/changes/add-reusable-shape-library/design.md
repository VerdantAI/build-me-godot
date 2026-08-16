## Context

Character generation should compose from reusable production substrates:

```text
reviewed asset library
    hard_hat_basic
    clipboard_square
    wrench_lowpoly
    tool_belt_modular
        |
        v
character recipe
    field_engineer equips hard_hat_basic + clipboard_square
    foreman equips hard_hat_basic + radio + vest
    mechanic equips tool_belt_modular + wrench_lowpoly
        |
        v
Blender/Godot assembly
    attach to stable sockets
    apply transforms/material overrides
    export play-test-ready scene
```

This is different from asking an AI model to generate every prop per
character. Generation should happen only after the library lookup cannot
satisfy the request or when the requested asset is specific enough that reuse
would be misleading.

## Asset Storage

Reusable shapes should live in project-owned paths:

```text
res://build_me_godot/assets/
  reusable_shapes/
    shape_library.json
    hard_hat_basic/
      hard_hat_basic.glb
      shape.json
      LICENSE.txt
      preview.png
    clipboard_square/
      clipboard_square.glb
      shape.json
      LICENSE.txt
      preview.png
```

The addon may include schemas, import helpers, UI, and metadata templates, but
must not include downloaded third-party model files.

## Shape Metadata

Each reusable shape should declare:

- stable `shape_id`;
- display name and semantic tags;
- taxonomy and representation class;
- source provider, source URL, source license, review status, reviewer, and
  review date;
- source file digest and imported file digest;
- game-mode fit, polygon budget, texture budget, and LOD availability;
- socket compatibility, default transform, attachment rules, and pivot;
- material slots and allowed material overrides;
- collision strategy;
- preview image and validation report paths;
- whether the asset is production-ready, blockout-only, or reference-only.

## Recipe Usage

Character recipes should refer to reusable shapes by ID:

```json
{
  "part_id": "helmet",
  "socket": "head",
  "source_kind": "reusable_shape",
  "shape_id": "hard_hat_basic",
  "transform_override": {
    "location": [0.0, 0.03, 0.08],
    "rotation_degrees": [0.0, 0.0, 0.0],
    "scale": [1.0, 1.0, 1.0]
  },
  "material_overrides": {
    "shell": "safety_yellow"
  }
}
```

The assembly tool can then resolve the shape, attach it to the socket, apply
overrides, and record exactly which reusable asset version was used.

## Search Before Generate

For common objects, the tool should run this decision path:

```text
requested part
    |
    v
project reusable shape match?
    | yes -> reuse
    | no
    v
reviewed local/vendor asset available?
    | yes -> import into reusable library
    | no
    v
user-approved search/download/import?
    | yes -> stage as candidate, review license, import
    | no
    v
placeholder blockout or explicit generation request
```

The default action for common hard-surface accessories should be lookup and
reuse, not procedural generation.

## Checkpoints

Reusable shapes should integrate with character checkpoints:

- recipes record `shape_id` and shape version/digest;
- assembly checkpoints depend on referenced shape digests;
- if a reusable shape changes, dependent assemblies become stale;
- if only transform/material overrides change, only assembly/readability stages
  need refresh;
- reference-only or blockout shapes cannot satisfy production readiness.

## Open Questions

- Should reusable shapes use a single global `shape_library.json`, one
  `shape.json` per asset, or both?
- Should imported shapes be normalized in Blender once at library import time
  or during each character assembly?
- How much UI should exist in the Godot dock versus a standalone installer or
  asset-management helper?
- Should the first implementation target accessories only, or all common props
  and environment parts?

## First Implementation Slice

The first implementation should stay narrow and unblock the field engineer:

1. Use both a project index and per-shape metadata:
   `res://build_me_godot/assets/reusable_shapes/shape_library.json` for
   lookup, plus `shape.json` beside each imported asset for provenance.
2. Support `candidate`, `blockout`, `reference_only`, `production_ready`, and
   `rejected` statuses.
3. Start with accessories only: hard hat, clipboard, hand tool, belt/pouch, and
   boots.
4. Treat Quaternius and Kenney packs as preferred first searches when the user
   has explicitly imported or staged them, because their common game-prototype
   assets usually fit the permissive policy.
5. Require per-asset review for Poly Pizza and generated-asset marketplaces.
6. Attach the first reviewed shape to the existing `head`, `hand_l`, `hand_r`,
   `hips`, or `feet` sockets before broadening the library.

This slice should not add a marketplace client or automatic downloader. The
installer/setup app may report missing reviewed shapes and describe explicit
user actions, but import and download remain user-controlled.
