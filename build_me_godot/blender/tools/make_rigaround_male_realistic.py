from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"


def make_mat(name: str, color: tuple[float, float, float, float], roughness: float = 0.55) -> bpy.types.Material:
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
    return mat


def bone_world(armature: bpy.types.Object, bone_name: str, at_tail: bool = False) -> Vector:
    bone = armature.data.bones[bone_name]
    local = bone.tail_local if at_tail else bone.head_local
    return armature.matrix_world @ local


def clear_previous_details() -> None:
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Rigaround_Realistic_"):
            bpy.data.objects.remove(obj, do_unlink=True)


def add_uv_sphere(
    name: str,
    location: Vector,
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    bone: str | None = None,
    segments: int = 32,
    rings: int = 16,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    if parent and bone:
        world_matrix = obj.matrix_world.copy()
        obj.parent = parent
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        obj.matrix_world = world_matrix
    return obj


def add_ellipsoid_between(
    name: str,
    start: Vector,
    end: Vector,
    radius: tuple[float, float],
    material: bpy.types.Material,
    parent: bpy.types.Object | None = None,
    bone: str | None = None,
) -> bpy.types.Object:
    center = (start + end) * 0.5
    length = max((end - start).length, 0.01)
    obj = add_uv_sphere(name, center, (radius[0], radius[1], length * 0.5), material, segments=24, rings=12)
    direction = end - start
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    if parent and bone:
        world_matrix = obj.matrix_world.copy()
        obj.parent = parent
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        obj.matrix_world = world_matrix
    return obj


def improve_base_mesh(mesh: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    mesh.data.materials.clear()
    for mat in (mats["skin"], mats["shirt"], mats["pants"], mats["shoes"]):
        mesh.data.materials.append(mat)

    for poly in mesh.data.polygons:
        z = mesh.matrix_world @ mesh.data.vertices[poly.vertices[0]].co
        avg_z = sum((mesh.matrix_world @ mesh.data.vertices[i].co).z for i in poly.vertices) / len(poly.vertices)
        avg_y = sum((mesh.matrix_world @ mesh.data.vertices[i].co).y for i in poly.vertices) / len(poly.vertices)
        if avg_z < 0.22:
            poly.material_index = 3
        elif avg_z < 1.08:
            poly.material_index = 2
        elif avg_z < 1.72 and abs(avg_y) < 0.6:
            poly.material_index = 1
        else:
            poly.material_index = 0

    mesh.data.update()
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.shade_smooth()
    mesh.select_set(False)

    if not mesh.modifiers.get("Realistic_Surface_Smoothing"):
        smooth = mesh.modifiers.new("Realistic_Surface_Smoothing", "WEIGHTED_NORMAL")
        smooth.keep_sharp = True


def add_head_details(armature: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    head = bone_world(armature, "Head")
    face_forward = Vector((0.0, -1.0, 0.0))

    add_uv_sphere(
        "Rigaround_Realistic_Hair",
        head + Vector((0.0, 0.015, 0.235)),
        (0.19, 0.16, 0.12),
        mats["hair"],
        armature,
        "Head",
        segments=32,
        rings=12,
    )

    for side in (-1, 1):
        add_uv_sphere(
            f"Rigaround_Realistic_Eye_{'L' if side < 0 else 'R'}",
            head + Vector((0.055 * side, -0.16, 0.08)),
            (0.025, 0.014, 0.018),
            mats["eye"],
            armature,
            "Head",
            segments=24,
            rings=12,
        )
        add_uv_sphere(
            f"Rigaround_Realistic_Brow_{'L' if side < 0 else 'R'}",
            head + Vector((0.055 * side, -0.165, 0.118)),
            (0.045, 0.01, 0.008),
            mats["hair"],
            armature,
            "Head",
            segments=16,
            rings=8,
        )
        add_uv_sphere(
            f"Rigaround_Realistic_Ear_{'L' if side < 0 else 'R'}",
            head + Vector((0.155 * side, -0.01, 0.055)),
            (0.025, 0.012, 0.05),
            mats["skin"],
            armature,
            "Head",
            segments=16,
            rings=8,
        )

    add_uv_sphere("Rigaround_Realistic_Nose", head + face_forward * 0.18 + Vector((0, 0, 0.035)), (0.03, 0.055, 0.045), mats["skin"], armature, "Head", segments=20, rings=10)
    add_uv_sphere("Rigaround_Realistic_Mouth", head + face_forward * 0.175 + Vector((0, 0, -0.055)), (0.065, 0.01, 0.012), mats["lip"], armature, "Head", segments=20, rings=8)
    add_uv_sphere("Rigaround_Realistic_Beard_Shadow", head + face_forward * 0.165 + Vector((0, 0, -0.11)), (0.11, 0.012, 0.055), mats["stubble"], armature, "Head", segments=24, rings=8)


def add_body_volume(armature: bpy.types.Object, mats: dict[str, bpy.types.Material]) -> None:
    chest = bone_world(armature, "Chest")
    hips = bone_world(armature, "Hips")
    add_uv_sphere(
        "Rigaround_Realistic_Shirt_Torso",
        (chest + hips) * 0.5 + Vector((0, -0.01, 0.02)),
        (0.22, 0.115, 0.34),
        mats["shirt"],
        armature,
        "Chest",
        segments=32,
        rings=16,
    )

    limb_specs = [
        ("LeftArm", "LeftForeArm", "Rigaround_Realistic_Left_Upper_Arm", mats["skin"], (0.04, 0.04)),
        ("LeftForeArm", "LeftHand", "Rigaround_Realistic_Left_Forearm", mats["skin"], (0.034, 0.034)),
        ("RightArm", "RightForeArm", "Rigaround_Realistic_Right_Upper_Arm", mats["skin"], (0.04, 0.04)),
        ("RightForeArm", "RightHand", "Rigaround_Realistic_Right_Forearm", mats["skin"], (0.034, 0.034)),
        ("LeftUpLeg", "LeftLeg", "Rigaround_Realistic_Left_Thigh", mats["pants"], (0.06, 0.05)),
        ("LeftLeg", "LeftFoot", "Rigaround_Realistic_Left_Calf", mats["pants"], (0.045, 0.04)),
        ("RightUpLeg", "RightLeg", "Rigaround_Realistic_Right_Thigh", mats["pants"], (0.06, 0.05)),
        ("RightLeg", "RightFoot", "Rigaround_Realistic_Right_Calf", mats["pants"], (0.045, 0.04)),
    ]
    for start_bone, end_bone, name, mat, radius in limb_specs:
        add_ellipsoid_between(
            name,
            bone_world(armature, start_bone),
            bone_world(armature, end_bone),
            radius,
            mat,
            armature,
            start_bone,
        )


def main() -> None:
    armature = bpy.data.objects.get("Rigaround_Male_Root")
    mesh = bpy.data.objects.get("Rigaround_Male_characterMedium")
    if armature is None or mesh is None:
        raise RuntimeError("Expected Rigaround male mesh and armature in the scene")

    clear_previous_details()

    mats = {
        "skin": make_mat("Rigaround_Realistic_Warm_Skin", (0.78, 0.55, 0.42, 1.0), 0.72),
        "shirt": make_mat("Rigaround_Realistic_Cotton_Shirt", (0.08, 0.16, 0.21, 1.0), 0.82),
        "pants": make_mat("Rigaround_Realistic_Denim_Pants", (0.045, 0.075, 0.12, 1.0), 0.78),
        "shoes": make_mat("Rigaround_Realistic_Dark_Shoes", (0.025, 0.022, 0.02, 1.0), 0.62),
        "hair": make_mat("Rigaround_Realistic_Dark_Hair", (0.025, 0.018, 0.012, 1.0), 0.65),
        "eye": make_mat("Rigaround_Realistic_Eye_White", (0.92, 0.9, 0.84, 1.0), 0.35),
        "lip": make_mat("Rigaround_Realistic_Lips", (0.55, 0.26, 0.22, 1.0), 0.68),
        "stubble": make_mat("Rigaround_Realistic_Beard_Shadow", (0.12, 0.09, 0.075, 1.0), 0.8),
    }

    improve_base_mesh(mesh, mats)
    add_head_details(armature, mats)
    add_body_volume(armature, mats)

    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print(f"Updated {RIGAROUND} with more realistic male visual details")


if __name__ == "__main__":
    main()
