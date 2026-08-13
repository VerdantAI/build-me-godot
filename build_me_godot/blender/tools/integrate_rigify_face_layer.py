"""Attach Rigify as a face-authoring layer on duplicate QTR body rigs only."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


SEXES = ("Female", "Male")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output")
    destination.add_argument("--in-place", action="store_true")
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def experiment_objects(sex: str) -> tuple[bpy.types.Collection, bpy.types.Object]:
    collection = bpy.data.collections.get(f"Rigify Face Experiment - {sex}")
    if collection is None:
        raise SystemExit(f"Missing experiment collection for {sex}")
    rigs = [
        obj for obj in collection.objects
        if obj.type == "ARMATURE" and obj.name.startswith(f"QTR_{sex}_Rig")
    ]
    if len(rigs) != 1:
        raise SystemExit(f"Expected one duplicate QTR rig for {sex}, found {len(rigs)}")
    return collection, rigs[0]


def integrate(sex: str) -> None:
    collection, body_rig = experiment_objects(sex)
    controls = bpy.data.objects.get(f"RigifyFaceControls_{sex}")
    metarig = bpy.data.objects.get(f"RigifyFaceMetarig_{sex}")
    if controls is None or controls.get("build_me_godot_experiment") != "rigify_face_controls_v1":
        raise SystemExit(f"Missing tagged Rigify controls for {sex}")
    if metarig is None or metarig.get("build_me_godot_experiment") != "rigify_face_v1":
        raise SystemExit(f"Missing tagged Rigify metarig for {sex}")
    if body_rig.data.bones.get("Head") is None:
        raise SystemExit(f"Duplicate QTR rig for {sex} has no Head bone")

    # Repair object references preserved by Blender's collection duplication.
    original = bpy.data.objects.get(f"QTR_{sex}_Rig")
    repaired = 0
    for obj in collection.objects:
        if obj.type != "MESH":
            continue
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE" and modifier.object == original:
                modifier.object = body_rig
                repaired += 1

    # Keep the generated rig independent until its metarig landmarks have been
    # fitted. Parenting an entire generated Rigify armature to QTR Head causes
    # its body-space offsets to drift during QTR body animation.
    world = controls.matrix_world.copy()
    controls.parent = None
    controls.parent_type = "OBJECT"
    controls.parent_bone = ""
    controls.matrix_world = world
    controls["build_me_godot_role"] = "face_authoring_only"
    controls["body_skeleton"] = body_rig.name
    controls["head_attachment"] = "pending_rest_space_bone_constraint"
    controls["export_full_rigify_rig"] = False

    for bone_collection in controls.data.collections_all:
        bone_collection.is_visible = bone_collection.name.startswith("Face")

    metarig.hide_set(True)
    metarig.hide_viewport = True
    metarig.hide_render = True
    metarig["build_me_godot_role"] = "face_landmark_template"
    print(f"{sex}: prepared independent face authoring controls for {body_rig.name}; repaired {repaired} mesh modifiers")


def main() -> None:
    options = arguments()
    output = Path(options.output).expanduser().resolve() if options.output else Path(bpy.data.filepath).resolve()
    if options.output and output.exists():
        raise SystemExit(f"Refusing to overwrite output: {output}")
    for sex in SEXES:
        integrate(sex)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    print(f"Saved QTR + Rigify face-authoring integration: {output}")
    print("Landmark fitting must precede rest-space ORG-face attachment, weights, and export.")


if __name__ == "__main__":
    main()
