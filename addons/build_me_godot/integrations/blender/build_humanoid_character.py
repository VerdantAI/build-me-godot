#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
import math
import statistics
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path.cwd()
POSE_CONTRACT = "neutral_a_pose_30deg_v1"


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--project-root", required=True, type=Path)
    return parser.parse_args(argv)


def resolve(path):
    path = Path(path)
    return path if path.is_absolute() else PROJECT_ROOT / path


def make_collection(name, parent=None):
    result = bpy.data.collections.new(name)
    (parent.children if parent else bpy.context.scene.collection.children).link(result)
    return result


def move_to(obj, target):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    target.objects.link(obj)


def import_mesh(config, target):
    source = resolve(config["source_mesh"])
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in {source}")
    for obj in meshes:
        move_to(obj, target)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = f"AI_{config['character_name']}_UNTOUCHED"
    obj["source"] = str(source)
    obj["purpose"] = "Immutable AI reconstruction reference"

    axis = config["source_axis"]
    for vertex in obj.data.vertices:
        source_co = tuple(vertex.co)
        vertex.co = tuple(axis[i][0] * source_co[axis[i][1]] for i in range(3))
    vertices = obj.data.vertices
    xs = [v.co.x for v in vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    scale = config["height_m"] / (max(zs) - min(zs))
    center_x = (min(xs) + max(xs)) * 0.5
    center_y = (min(ys) + max(ys)) * 0.5
    floor = min(zs)
    normalized = [((vertex.co.x - center_x) * scale, (vertex.co.y - center_y) * scale, (vertex.co.z - floor) * scale) for vertex in vertices]
    band_low, band_high = config.get("anatomical_center_band", [0.78, 0.96])
    center_band = [point for point in normalized if config["height_m"] * band_low < point[2] < config["height_m"] * band_high]
    anatomical_x = statistics.median(point[0] for point in center_band)
    anatomical_y = statistics.median(point[1] for point in center_band)
    for vertex, point in zip(vertices, normalized):
        vertex.co.x = point[0] - anatomical_x
        vertex.co.y = point[1] - anatomical_y
        vertex.co.z = point[2]
    obj.data.update()
    obj["anatomical_center_offset"] = (anatomical_x, anatomical_y)
    return obj


def add_bone(data, name, head, tail, parent=None, deform=True):
    bone = data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.use_deform = deform
    if parent:
        bone.parent = data.edit_bones[parent]
    return bone


def build_standard_rig(config, target):
    h = config["height_m"]
    p = config["landmarks"]
    data = bpy.data.armatures.new("UniversalHumanoidSkeleton")
    rig = bpy.data.objects.new(f"{config['character_name']}_Rig", data)
    target.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    add_bone(data, "root", (0, 0, 0), (0, 0, h * 0.06))
    add_bone(data, "DEF-hips", (0, 0, h * p["hips"]), (0, 0, h * p["spine"]), "root")
    add_bone(data, "DEF-spine.001", (0, 0, h * p["spine"]), (0, 0, h * p["chest"]), "DEF-hips")
    add_bone(data, "DEF-spine.002", (0, 0, h * p["chest"]), (0, 0, h * p["upper_chest"]), "DEF-spine.001")
    add_bone(data, "DEF-spine.003", (0, 0, h * p["upper_chest"]), (0, 0, h * p["neck"]), "DEF-spine.002")
    add_bone(data, "DEF-neck", (0, 0, h * p["neck"]), (0, 0, h * p["head"]), "DEF-spine.003")
    add_bone(data, "DEF-head", (0, 0, h * p["head"]), (0, 0, h * p["top"]), "DEF-neck")
    for side, sign in (("L", 1), ("R", -1)):
        side_arm = config.get("arms", {}).get(side)
        if side_arm:
            shoulder, elbow, wrist, hand = [tuple(h * value for value in side_arm[joint]) for joint in ("shoulder", "elbow", "wrist", "hand")]
        else:
            shoulder = (h * p["shoulder_x"] * sign, 0, h * p["shoulder_z"])
            elbow = (h * p["elbow_x"] * sign, 0, h * p["elbow_z"])
            wrist = (h * p["wrist_x"] * sign, 0, h * p["wrist_z"])
            hand = (h * p["hand_x"] * sign, 0, h * p["hand_z"])
        add_bone(data, f"DEF-shoulder.{side}", (h * 0.04 * sign, 0, h * p["upper_chest"]), shoulder, "DEF-spine.003")
        add_bone(data, f"DEF-upper_arm.{side}", shoulder, elbow, f"DEF-shoulder.{side}")
        add_bone(data, f"DEF-forearm.{side}", elbow, wrist, f"DEF-upper_arm.{side}")
        add_bone(data, f"DEF-hand.{side}", wrist, hand, f"DEF-forearm.{side}")
        hip = (h * p["leg_x"] * sign, 0, h * p["hips"])
        knee = (h * p["leg_x"] * sign, 0, h * p["knee"])
        ankle = (h * p["leg_x"] * sign, 0, h * p["ankle"])
        toe = (h * p["leg_x"] * sign, -h * p["foot_length"], h * p["toe_z"])
        add_bone(data, f"DEF-thigh.{side}", hip, knee, "DEF-hips")
        add_bone(data, f"DEF-shin.{side}", knee, ankle, f"DEF-thigh.{side}")
        add_bone(data, f"DEF-foot.{side}", ankle, toe, f"DEF-shin.{side}")
        add_bone(data, f"DEF-toe.{side}", toe, (toe[0], toe[1] - h * 0.06, toe[2]), f"DEF-foot.{side}")
    sockets = {
        "hand_r_tool": ("DEF-hand.R", (-0.02, -0.08, 0)),
        "hand_l_tool": ("DEF-hand.L", (0.02, -0.08, 0)),
        "belt_left": ("DEF-hips", (0.18, -0.08, 0)),
        "belt_right": ("DEF-hips", (-0.18, -0.08, 0)),
        "belt_back": ("DEF-hips", (0, 0.12, 0)),
        "back_attachment": ("DEF-spine.002", (0, 0.15, 0.12)),
    }
    for name, (parent, offset) in sockets.items():
        base = data.edit_bones[parent].head
        head = tuple(base[i] + offset[i] for i in range(3))
        tail = (head[0], head[1] - 0.10, head[2])
        add_bone(data, name, head, tail, parent, False)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig["skeleton_contract"] = "Quaternius Universal Animation Library / Godot SkeletonProfileHumanoid"
    return rig


def fit_rig_depth(mesh, rig, axial_maximum_delta, limb_maximum_delta):
    vertices = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]

    def center_y(point, maximum_delta):
        for radius_x, radius_z in ((0.05, 0.04), (0.08, 0.06), (0.12, 0.09)):
            candidates = [vertex.y for vertex in vertices if abs(vertex.x - point.x) <= radius_x and abs(vertex.z - point.z) <= radius_z]
            if len(candidates) >= 20:
                candidates.sort()
                low = candidates[int(len(candidates) * 0.10)]
                high = candidates[int(len(candidates) * 0.90)]
                target = (low + high) * 0.5
                return max(point.y - maximum_delta, min(point.y + maximum_delta, target))
        return point.y

    fitted = {}
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    skip = {"root", "DEF-foot.L", "DEF-foot.R", "DEF-toe.L", "DEF-toe.R"}
    for bone in rig.data.edit_bones:
        if bone.name in skip or not bone.use_deform:
            continue
        old_head_y = bone.head.y
        old_tail_y = bone.tail.y
        maximum_delta = limb_maximum_delta if any(part in bone.name for part in ("arm", "forearm", "hand", "thigh", "shin")) else axial_maximum_delta
        bone.head.y = center_y(bone.head, maximum_delta)
        bone.tail.y = center_y(bone.tail, maximum_delta)
        fitted[bone.name] = [round(bone.head.y - old_head_y, 4), round(bone.tail.y - old_tail_y, 4)]
    bpy.ops.object.mode_set(mode="OBJECT")
    return fitted


def load_actions(path):
    existing_objects = set(bpy.data.objects)
    existing_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(path))
    actions = [action for action in bpy.data.actions if action not in existing_actions]
    for obj in [obj for obj in bpy.data.objects if obj not in existing_objects]:
        bpy.data.objects.remove(obj, do_unlink=True)
    return {action.name: action for action in actions}


def validate_rig_fit(mesh, rig, maximum_distance):
    vertices = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
    joint_bones = [
        "DEF-upper_arm.L", "DEF-forearm.L", "DEF-hand.L",
        "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R",
        "DEF-thigh.L", "DEF-shin.L", "DEF-foot.L",
        "DEF-thigh.R", "DEF-shin.R", "DEF-foot.R",
    ]
    distances = {}
    for name in joint_bones:
        bone = rig.data.bones[name]
        point = rig.matrix_world @ bone.tail_local
        distances[name] = min((point - vertex).length for vertex in vertices)
    worst_bone = max(distances, key=distances.get)
    if distances[worst_bone] > maximum_distance:
        raise RuntimeError(f"Rig fit failed: {worst_bone} is {distances[worst_bone]:.3f} m from the mesh (limit {maximum_distance:.3f} m)")
    return {name: round(distance, 4) for name, distance in distances.items()}


def add_reference(name, path, location, rotation, target, height):
    image = bpy.data.images.load(str(path), check_existing=True)
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "IMAGE"
    obj.data = image
    obj.empty_display_size = height
    obj.color[3] = 0.45
    obj.location = location
    obj.rotation_euler = rotation
    obj["reference_only"] = True
    target.objects.link(obj)


def main():
    global PROJECT_ROOT
    options = args()
    PROJECT_ROOT = options.project_root.resolve()
    config_path = options.config.resolve()
    config = json.loads(config_path.read_text())
    if config.get("pose_contract") != POSE_CONTRACT:
        raise RuntimeError(f"Character config must declare pose_contract={POSE_CONTRACT!r}")
    output = resolve(config["output_dir"])
    output.mkdir(parents=True, exist_ok=True)
    asset = resolve(config["animation_asset"])
    if not asset.exists():
        raise RuntimeError(f"Missing CC0 animation library: {asset}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    reference_root = make_collection("CHARACTER_REFERENCE")
    ai_collection = make_collection("AI_MESH", reference_root)
    references = make_collection("REFERENCES", reference_root)
    production_root = make_collection("CHARACTER_PRODUCTION")
    body = make_collection("BODY", production_root)
    make_collection("CLOTHING", production_root)
    equipment = make_collection("EQUIPMENT", production_root)
    rig_collection = make_collection("RIG", production_root)

    ai_mesh = import_mesh(config, ai_collection)
    production = ai_mesh.copy()
    production.data = ai_mesh.data.copy()
    production.name = f"{config['character_name']}_RetopoProxy_NEEDS_MANUAL_LOOPS"
    body.objects.link(production)
    production["topology_status"] = "Automatic proxy; manual deformation topology required"
    modifier = production.modifiers.new("TriangleBudget", "DECIMATE")
    modifier.ratio = min(1.0, config["triangle_target"] / max(1, len(production.data.loop_triangles)))
    bpy.context.view_layer.objects.active = production
    production.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh_repaired = production.data.validate(verbose=True, clean_customdata=True)
    production.data.update()

    rig = build_standard_rig(config, rig_collection)
    depth_limits = config.get("depth_fit_limits_m", {"axial": 0.06, "limb": 0.25})
    depth_fit = fit_rig_depth(production, rig, depth_limits["axial"], depth_limits["limb"]) if config.get("fit_joint_depth_from_mesh", True) else {}
    bpy.ops.object.select_all(action="DESELECT")
    production.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    automatic_weights = True
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except RuntimeError:
        automatic_weights = False
        armature = production.modifiers.new("CharacterArmature", "ARMATURE")
        armature.object = rig
        production.parent = rig
    mesh_repaired_after_weights = production.data.validate(verbose=True, clean_customdata=True)
    production.data.update()
    bpy.ops.object.select_all(action="DESELECT")
    production.select_set(True)
    bpy.context.view_layer.objects.active = production
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    fit_distances = validate_rig_fit(production, rig, config.get("max_joint_mesh_distance_m", 0.20))

    actions = load_actions(asset)
    selected = config["animations"]
    missing = [name for name in selected if name not in actions]
    if missing:
        raise RuntimeError(f"Animation clips absent from Quaternius library: {missing}")
    for action in actions.values():
        action.use_fake_user = action.name in selected
    rig.animation_data_create()
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis.identity()
    rig.data.pose_position = "POSE"
    rig["animation_source"] = "Quaternius Universal Animation Library Standard, CC0"
    rig["animation_clips"] = ",".join(selected)
    rig["animation_note"] = "Actions require humanoid rest-pose retargeting; do not assign source F-curves directly"

    equipment["manual_replacement_required"] = "belt, pouches, tools, backpack"
    views = resolve(config["views_dir"])
    h = config["height_m"]
    add_reference("REF_front", views / "front.png", (0, 0.45, h / 2), (math.pi / 2, 0, 0), references, h)
    add_reference("REF_back", views / "back.png", (0, -0.45, h / 2), (math.pi / 2, 0, math.pi), references, h)
    add_reference("REF_side", views / "right.png", (-0.55, 0, h / 2), (math.pi / 2, 0, -math.pi / 2), references, h)
    for obj in ai_collection.objects:
        obj.hide_render = True
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_set(0)
    bpy.context.scene.frame_end = int(actions[selected[0]].frame_range[1])
    blend = output / f"{config['character_id']}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))

    bpy.ops.object.select_all(action="DESELECT")
    production.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    glb = output / f"{config['character_id']}.glb"
    export_args = {"filepath": str(glb), "export_format": "GLB", "use_selection": True, "export_animations": False, "export_skins": True, "export_def_bones": False}
    try:
        bpy.ops.export_scene.gltf(**export_args)
    except TypeError:
        export_args.pop("export_def_bones")
        bpy.ops.export_scene.gltf(**export_args)

    report = {
        "character_id": config["character_id"],
        "config": str(config_path),
        "source_mesh": str(resolve(config["source_mesh"])),
        "blend": str(blend),
        "glb": str(glb),
        "ai_triangles": len(ai_mesh.data.loop_triangles),
        "proxy_triangles": len(production.data.loop_triangles),
        "dimensions_m": [round(value, 6) for value in production.dimensions],
        "automatic_weights_completed": automatic_weights,
        "mesh_validation_repaired_data": mesh_repaired,
        "mesh_validation_repaired_after_weights": mesh_repaired_after_weights,
        "maximum_vertex_influences": 4,
        "joint_mesh_distance_m": fit_distances,
        "joint_depth_fit_delta_m": depth_fit,
        "landmark_provenance": config.get("landmark_provenance"),
        "skeleton_bones": [bone.name for bone in rig.data.bones],
        "animation_source": str(asset),
        "animations": selected,
        "animations_embedded": False,
        "animation_delivery": "Shared Godot Animation Library GLB; retarget with SkeletonProfileHumanoid",
        "manual_cleanup_required": True,
    }
    (output / "build_report.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
