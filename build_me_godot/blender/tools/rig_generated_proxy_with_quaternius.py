from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


TEMPLATE_BLEND = (
    Path(__file__).resolve().parents[1]
    / "assets"
    / "library"
    / "quaternius_humanoid_bases_with_animations.blend"
)
ARMATURE_NAME = "QTR_Male_Rig"
DONOR_NAME = "QTR_Male_SuperHero_Male"
DEFAULT_ACTION = "Rig_Test"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_glb", type=Path)
    parser.add_argument("output_glb", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--action", default=DEFAULT_ACTION)
    if "--" in __import__("sys").argv:
        argv = __import__("sys").argv[__import__("sys").argv.index("--") + 1 :]
    else:
        argv = []
    return parser.parse_args(argv)


def bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
    if not points:
        raise RuntimeError("No mesh vertices found for bounds")
    return (
        Vector((min(v.x for v in points), min(v.y for v in points), min(v.z for v in points))),
        Vector((max(v.x for v in points), max(v.y for v in points), max(v.z for v in points))),
    )


def import_template() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(TEMPLATE_BLEND))


def import_generated_mesh(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh objects imported from {path}")
    for obj in meshes:
        obj.name = f"Generated_{obj.name}"
        obj.data.name = f"{obj.name}_Mesh"
    return meshes


def align_to_donor(meshes: list[bpy.types.Object], donor: bpy.types.Object) -> None:
    source_min, source_max = bounds_for(meshes)
    donor_min, donor_max = bounds_for([donor])

    source_size = source_max - source_min
    donor_size = donor_max - donor_min
    scale = donor_size.z / source_size.z

    source_center = (source_min + source_max) * 0.5
    donor_center = (donor_min + donor_max) * 0.5

    for obj in meshes:
        for vertex in obj.data.vertices:
            world = obj.matrix_world @ vertex.co
            aligned = Vector(
                (
                    (world.x - source_center.x) * scale + donor_center.x,
                    (world.y - source_center.y) * scale + donor_center.y,
                    (world.z - source_min.z) * scale + donor_min.z,
                )
            )
            vertex.co = obj.matrix_world.inverted() @ aligned
        obj.data.update()


def transfer_weights(target: bpy.types.Object, donor: bpy.types.Object) -> None:
    target.vertex_groups.clear()
    for group in donor.vertex_groups:
        target.vertex_groups.new(name=group.name)

    modifier = target.modifiers.new("Quaternius_Transferred_Weights", "DATA_TRANSFER")
    modifier.object = donor
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.layers_vgroup_select_src = "ALL"
    modifier.layers_vgroup_select_dst = "NAME"
    modifier.mix_mode = "REPLACE"
    modifier.mix_factor = 1.0

    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = target
    target.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    target.select_set(False)


def bind_meshes(
    meshes: list[bpy.types.Object], donor: bpy.types.Object, armature: bpy.types.Object
) -> None:
    for obj in meshes:
        transfer_weights(obj, donor)
        modifier = obj.modifiers.new("Quaternius_Armature", "ARMATURE")
        modifier.object = armature
        obj.parent = armature


def prune_for_export(meshes: list[bpy.types.Object], armature: bpy.types.Object) -> None:
    keep = set(meshes)
    keep.add(armature)

    for pose_bone in armature.pose.bones:
        pose_bone.custom_shape = None

    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)


def evaluated_vertices_world(obj: bpy.types.Object) -> list[Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    evaluated = obj.evaluated_get(depsgraph)
    return [evaluated.matrix_world @ vertex.co.copy() for vertex in evaluated.data.vertices]


def max_delta(first: list[Vector], second: list[Vector]) -> float:
    return max((b - a).length for a, b in zip(first, second))


def apply_animation(armature: bpy.types.Object, action_name: str) -> bpy.types.Action:
    if action_name == "Rig_Test":
        return create_rig_test_action(armature)

    action = bpy.data.actions.get(action_name)
    if action is None:
        raise RuntimeError(f"Action not found: {action_name}")
    armature.animation_data_create()
    armature.animation_data.action = action
    bpy.context.scene.frame_start = int(action.frame_range[0])
    bpy.context.scene.frame_end = int(action.frame_range[1])
    return action


def create_rig_test_action(armature: bpy.types.Object) -> bpy.types.Action:
    animation_data = armature.animation_data_create()
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)
    animation_data.action = bpy.data.actions.new("Rig_Test")

    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")

    pose_bones = armature.pose.bones
    for bone in pose_bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)

    scene = bpy.context.scene
    frames = (0, 16, 32)
    for frame in frames:
        scene.frame_set(frame)
        for bone in pose_bones:
            bone.rotation_euler = (0.0, 0.0, 0.0)
            bone.location = (0.0, 0.0, 0.0)

        if frame == 16:
            rotations = {
                "spine_02": (0.0, math.radians(3), 0.0),
                "upperarm_l": (math.radians(8), 0.0, math.radians(-4)),
                "upperarm_r": (math.radians(-8), 0.0, math.radians(4)),
                "lowerarm_l": (math.radians(6), 0.0, 0.0),
                "lowerarm_r": (math.radians(-6), 0.0, 0.0),
                "thigh_l": (math.radians(4), 0.0, 0.0),
                "calf_l": (math.radians(-4), 0.0, 0.0),
            }
            for name, rotation in rotations.items():
                if name in pose_bones:
                    pose_bones[name].rotation_euler = rotation

        for bone in pose_bones:
            bone.keyframe_insert("rotation_euler", frame=frame)
            bone.keyframe_insert("location", frame=frame)

    bpy.ops.object.mode_set(mode="OBJECT")
    action = armature.animation_data.action
    if action is None:
        raise RuntimeError("Failed to create rig test action")
    scene.frame_start = 0
    scene.frame_end = 32
    return action


def isolate_active_action(armature: bpy.types.Object, action: bpy.types.Action) -> None:
    animation_data = armature.animation_data_create()
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)
    animation_data.action = action
    for other in list(bpy.data.actions):
        if other != action:
            bpy.data.actions.remove(other)


def validate(meshes: list[bpy.types.Object], action: bpy.types.Action) -> dict:
    scene = bpy.context.scene
    start = int(action.frame_range[0])
    midpoint = max(start + 1, int((action.frame_range[0] + action.frame_range[1]) / 2))
    scene.frame_set(start)
    first = {obj.name: evaluated_vertices_world(obj) for obj in meshes}
    scene.frame_set(midpoint)
    second = {obj.name: evaluated_vertices_world(obj) for obj in meshes}

    return {
        "action": action.name,
        "frame_start": start,
        "frame_midpoint": midpoint,
        "mesh_deformation_delta": {
            obj.name: max_delta(first[obj.name], second[obj.name]) for obj in meshes
        },
        "meshes": [
            {
                "name": obj.name,
                "vertices": len(obj.data.vertices),
                "polygons": len(obj.data.polygons),
                "materials": len(obj.data.materials),
                "vertex_groups": len(obj.vertex_groups),
                "modifiers": [modifier.type for modifier in obj.modifiers],
            }
            for obj in meshes
        ],
    }


def export_selected(meshes: list[bpy.types.Object], armature: bpy.types.Object, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        use_visible=True,
        export_animations=True,
        export_animation_mode="ACTIVE_ACTIONS",
        export_nla_strips=False,
        export_leaf_bone=False,
        export_armature_object_remove=False,
        export_yup=True,
    )


def main() -> None:
    args = parse_args()
    import_template()

    armature = bpy.data.objects.get(ARMATURE_NAME)
    donor = bpy.data.objects.get(DONOR_NAME)
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError(f"Armature not found: {ARMATURE_NAME}")
    if donor is None or donor.type != "MESH":
        raise RuntimeError(f"Weight donor not found: {DONOR_NAME}")
    donor_name = donor.name

    meshes = import_generated_mesh(args.input_glb)
    align_to_donor(meshes, donor)
    bind_meshes(meshes, donor, armature)
    action = apply_animation(armature, args.action)
    isolate_active_action(armature, action)
    report = validate(meshes, action)
    prune_for_export(meshes, armature)
    report.update(
        {
            "input": str(args.input_glb),
            "output": str(args.output_glb),
            "template": str(TEMPLATE_BLEND),
            "armature": armature.name,
            "weight_donor": donor_name,
            "method": "quaternius_donor_weight_transfer",
        }
    )
    export_selected(meshes, armature, args.output_glb)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
