# Field Engineers Character Pipeline

This project uses reusable humanoid base rigs as the stable production foundation, then builds city-worker identity through reference images, modular clothing, tools, materials, and validation.

## Current Base Assets

- Primary base library: `assets/library/quaternius_humanoid_bases_with_animations.blend`
- Working Blender scene: `field_engineers.blend`
- Previous experiment scene: `Rigaround.blend`
- Source archive: `assets/downloads/quaternius_ik_rigged.zip`

The Quaternius male and female bases are the preferred foundation. They replace the earlier Kenney-rig-plus-transferred-mannequin experiment because they include human-proportioned meshes, correctly attached armatures, and a larger compatible action set.

## Core Rule

Do not start by deforming the base meshes.

Keep the male and female mannequins stable as reusable rigged bases. Character identity should come from modular wardrobe, equipment, materials, and silhouettes. Body deformation is a later proportion-variant step, not the first character-design step.

## Reference-First Workflow

1. Render control images from Blender.
   - Use the Quaternius male/female rigs.
   - Render front, side, back, and 3/4 views.
   - Include neutral A-pose and a small set of utility poses such as walk, crouch, pickup/interact.
   - Use these renders as pose, silhouette, depth, and line controls for ComfyUI.

2. Generate reference sheets in ComfyUI.
   - Use OpenPose or pose ControlNet for pose consistency.
   - Use depth, Canny, or lineart ControlNet for silhouette and clothing-structure control.
   - Use IPAdapter, Qwen Image Edit, or a similar reference-conditioning workflow for outfit and face consistency.
   - Use Face Detailer only after body/clothing design is locked.

3. Define city-worker archetypes.
   - Surveyor
   - Construction foreman
   - Utility inspector
   - Road crew worker
   - Field engineer

4. Produce design sheets per archetype.
   - Front, side, and back full-body views.
   - Helmet or hat detail.
   - Vest, jacket, pants, boots, and gloves detail.
   - Tool and accessory callouts.
   - Color/material swatches.

5. Build modular Blender assets.
   - Hard hats.
   - Safety vests with reflective strips.
   - Work boots.
   - Gloves.
   - Tool belts.
   - Radios.
   - Tablets or clipboards.
   - Survey poles.
   - Total station and tripod.
   - Traffic cones and markers.

6. Fit and attach modules to rigs.
   - Prefer separate reusable meshes over baking gear into the body.
   - Parent rigid props to stable bones.
   - Weight flexible clothing to the armature only when it must deform.
   - Validate with idle, walk, jog, crouch, jump, and interact actions.

7. Create variants.
   - Reuse the same gear modules with alternate materials.
   - Vary vest colors, helmet colors, jacket types, dirt/wear levels, and tool loadouts.
   - Keep socket names and rig conventions stable.

## ComfyUI Guidance

Recommended control stack:

- Pose/OpenPose ControlNet: body pose and view.
- Depth or Canny/lineart ControlNet: silhouette and clothing boundaries.
- Reference conditioning: character/outfit consistency.
- Upscale/detail pass: only after the sheet is accepted.

Avoid training a LoRA at the start. First generate, curate, and model from reference sheets. Train a small LoRA later only after a recurring named character has 15-30 approved reference images.

## Migration Target

When moving into `/home/buddha/verdant/build-me-godot`, generated project data should live under:

`res://build_me_godot/`

Recommended local layout:

```text
build_me_godot/
  blender/
    field_engineers.blend
    assets/library/
    assets/downloads/
    tools/
  characters/
    field_engineers/
      references/
      manifests/
      exports/
```

Do not put project character outputs inside `addons/build_me_godot/`; that directory is the addon package.

## Validation Checks

Before committing to a character asset:

- Meshes have armature modifiers targeting the intended rig.
- Vertex groups match the rig where deformation is expected.
- Rigid props are bone-parented to stable socket/bone names.
- Idle, walk, jog, crouch, jump, and interact actions do not cause severe clipping.
- Reference images and generated outputs have clear license/provenance notes.

