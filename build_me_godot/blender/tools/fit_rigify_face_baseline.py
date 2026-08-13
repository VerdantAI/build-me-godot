"""Align prepared Rigify metarigs to duplicate Quaternius mannequin baselines.

This performs only whole-rig placement and uniform height scaling. It deliberately
does not claim to fit face landmarks or bind/replace the mannequin mesh.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


SEXES = ("Female", "Male")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output")
    destination.add_argument("--in-place", action="store_true")
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def world_bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners))),
        Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners))),
    )


def duplicate_armature(sex: str) -> bpy.types.Object:
    collection = bpy.data.collections.get(f"Rigify Face Experiment - {sex}")
    if collection is None:
        raise SystemExit(f"Missing experiment collection for {sex}")
    candidates = [
        obj for obj in collection.objects
        if obj.type == "ARMATURE" and obj.name.startswith(f"QTR_{sex}_Rig")
    ]
    if len(candidates) != 1:
        raise SystemExit(f"Expected one duplicate {sex} mannequin armature, found {len(candidates)}")
    return candidates[0]


def fit(sex: str) -> None:
    metarig = bpy.data.objects.get(f"RigifyFaceMetarig_{sex}")
    if metarig is None or metarig.get("build_me_godot_experiment") != "rigify_face_v1":
        raise SystemExit(f"Missing tagged prepared metarig for {sex}")
    source = duplicate_armature(sex)
    source_min, source_max = world_bounds(source)

    metarig.location = (0.0, 0.0, 0.0)
    metarig.rotation_euler = (0.0, 0.0, 0.0)
    metarig.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()
    meta_min, meta_max = world_bounds(metarig)
    scale = (source_max.z - source_min.z) / (meta_max.z - meta_min.z)
    metarig.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    meta_min, meta_max = world_bounds(metarig)

    source_center = (source_min + source_max) * 0.5
    meta_center = (meta_min + meta_max) * 0.5
    head = source.data.bones.get("Head")
    if head is None:
        raise SystemExit(f"Duplicate QTR rig for {sex} has no Head bone")
    head_anchor = source.matrix_world @ ((head.head_local + head.tail_local) * 0.5)
    metarig.location += Vector((
        head_anchor.x - meta_center.x,
        head_anchor.y - meta_center.y,
        source_min.z - meta_min.z,
    ))
    metarig["baseline_fit"] = "quaternius_bounds_v1"
    metarig["face_landmark_fit_required"] = True
    metarig["weights_required"] = True
    metarig["manual_fit_required"] = True
    controls = bpy.data.objects.get(f"RigifyFaceControls_{sex}")
    if controls is not None:
        if controls.get("build_me_godot_experiment") != "rigify_face_controls_v1":
            raise SystemExit(f"Refusing to align untagged object: {controls.name}")
        parent = controls.parent
        parent_type = controls.parent_type
        parent_bone = controls.parent_bone
        controls.parent = None
        controls.matrix_world = metarig.matrix_world.copy()
        controls.location = metarig.location.copy()
        controls.rotation_euler = metarig.rotation_euler.copy()
        controls.scale = metarig.scale.copy()
        bpy.context.view_layer.update()
        world = controls.matrix_world.copy()
        if parent is not None:
            controls.parent = parent
            controls.parent_type = parent_type
            controls.parent_bone = parent_bone
            controls.matrix_world = world
            bpy.context.view_layer.update()
        controls["baseline_fit"] = "quaternius_bounds_v1"
        controls["face_landmark_fit_required"] = True
        controls["weights_required"] = True
        org_face = controls.data.bones.get("ORG-face")
        if org_face is None:
            raise SystemExit(f"Generated Rigify controls for {sex} have no ORG-face bone")
        face_z = (controls.matrix_world @ org_face.head_local).z
        z_offset = head_anchor.z - face_z
        controls.location.z += z_offset
        metarig.location.z += z_offset
        bpy.context.view_layer.update()
        controls["head_anchor_z_offset"] = z_offset
        metarig["head_anchor_z_offset"] = z_offset
    print(f"{sex}: baseline scale={scale:.6f}, location={tuple(round(v, 6) for v in metarig.location)}")


def main() -> None:
    options = arguments()
    bpy.context.scene.frame_set(0)
    output = Path(options.output).expanduser().resolve() if options.output else Path(bpy.data.filepath).resolve()
    if options.output and output.exists():
        raise SystemExit(f"Refusing to overwrite output: {output}")
    for sex in SEXES:
        fit(sex)
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    print(f"Saved baseline-aligned metarigs: {output}")
    print("Face-landmark fitting and mesh weighting are still required.")


if __name__ == "__main__":
    main()
