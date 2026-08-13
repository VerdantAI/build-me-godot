# Facial rigging experiments

Facial animation is additive to the stable Quaternius body rigs. The original
male and female mannequins in `field_engineers.blend` remain immutable. Every
experiment starts from a full duplicate and preserves the
`neutral_a_pose_30deg_v1` body pose, humanoid bone names, and sockets.

## Candidate order

1. **Blender Rigify** — first authoring experiment. Fit its face metarig to a
   duplicated mannequin, author expressions, then bake portable deformation
   bones and/or morph targets for glTF. Rigify is never a Godot runtime
   dependency.
2. **Momentum Human Rig (MHR)** — Apache-2.0 facial-expression reference with
   expression blendshapes. Not downloaded or integrated.
3. **BlenRig 6** — GPL-3.0 optional Blender authoring alternative. Not bundled.
4. **ARKit Blendshape Helper** — rejected for now because its repository does
   not publish a clear license.

## Rigify phase 1

Run the preparation tool explicitly with a new output path:

```bash
blender -b build_me_godot/blender/field_engineers.blend \
  --python build_me_godot/blender/tools/prepare_rigify_face_experiment.py -- \
  --sex both --in-place
```

The baseline file currently contains duplicate female and male experiment
collections created by this command. The tool makes mesh and armature data
single-user and adds a Rigify human metarig. It does not automatically
fit facial landmarks, generate the final control rig, transfer weights, alter
topology, or overwrite an existing file. Those steps require visual artist
review because automatic landmark placement is not production topology.

After manual landmark fitting, generate the control rigs explicitly:

```bash
blender --factory-startup -b build_me_godot/blender/field_engineers.blend \
  --python build_me_godot/blender/tools/generate_rigify_face_controls.py -- \
  --in-place
```

Generating controls before landmark fitting is useful only as a technical
baseline; it does not produce valid facial deformation weights.

The committed experiment is currently at that technical-baseline stage. To
reapply whole-rig placement and uniform height scaling to the duplicate
mannequins (including existing generated controls), run:

```bash
blender -b build_me_godot/blender/field_engineers.blend \
  --python build_me_godot/blender/tools/fit_rigify_face_baseline.py -- \
  --in-place
```

This height/head-anchor fit aligns the generated `ORG-face` height to the QTR
`Head` midpoint. It is deliberately not a facial landmark fit and does not bind
the duplicate meshes. The file tags both remaining requirements explicitly.

Attach the generated controls as a face-authoring layer on the duplicated QTR
body rigs and hide Rigify's body controls with:

```bash
blender -b build_me_godot/blender/field_engineers.blend \
  --python build_me_godot/blender/tools/integrate_rigify_face_layer.py -- \
  --in-place
```

This repairs duplicated mesh modifiers so they target the duplicate QTR body
rig and exposes only Rigify's face control collections. The generated rig stays
independent until landmark fitting; object-parenting the whole Rigify rig to
QTR `Head` causes offsets during body animation. A rest-space constraint from
Rigify's internal `ORG-face` chain is a later, reviewed step. The script does
not merge or weight face bones and tags the full Rigify rig as excluded from
production export.

The eventual Godot export must keep the Quaternius-compatible humanoid body
skeleton and use Godot `SkeletonProfileHumanoid` for body retargeting. Facial
deformation is exported as an additive layer. For morph-target export, enable
glTF **Export Deformation Bones Only**.
