#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
import math
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path.cwd()
POSE_CONTRACT = "neutral_a_pose_30deg_v1"
EXCLUDED_BODY_MESH_NAMES = {
    "Icosphere",
    "QTR_Male_Icosphere",
    "QTR_Female_Icosphere",
}
EXCLUDED_BODY_NAME_FRAGMENTS = (
    "sphere.005",
    "icosphere",
)


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--recipe", required=True)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--output-dir", required=True)
    return parser.parse_args(argv)


def resolve(path):
    text = str(path)
    if text.startswith("res://"):
        return PROJECT_ROOT / text.removeprefix("res://")
    candidate = Path(text)
    return candidate if candidate.is_absolute() else PROJECT_ROOT / candidate


def res_path(path):
    path = Path(path).resolve()
    try:
        return "res://" + str(path.relative_to(PROJECT_ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def ensure_project_output(path):
    resolved = resolve(path).resolve()
    project = PROJECT_ROOT.resolve()
    addon = (project / "addons" / "build_me_godot").resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise RuntimeError(f"Output must be inside the Godot project: {path}") from exc
    try:
        resolved.relative_to(addon)
        raise RuntimeError(f"Output must not be inside the addon package: {path}")
    except ValueError:
        pass
    resolved.mkdir(parents=True, exist_ok=True)
    return resolved


def load_json(path):
    resolved = resolve(path)
    with resolved.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def make_collection(name, parent=None):
    collection = bpy.data.collections.new(name)
    (parent.children if parent else bpy.context.scene.collection.children).link(collection)
    return collection


def move_to(obj, target):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    target.objects.link(obj)


def material(name, color):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def import_body(recipe, collection, report):
    rigged_meshes = recipe.get("body", {}).get("rigged_meshes", {})
    source = rigged_meshes.get("primary") or rigged_meshes.get("secondary")
    if not source:
        report["warnings"].append("No body mesh path is recorded in the recipe.")
        return []
    source_path = resolve(source)
    if not source_path.exists():
        report["warnings"].append(f"Body mesh is missing: {source}")
        return []
    before = set(bpy.data.objects)
    if source_path.suffix.lower() in [".glb", ".gltf"]:
        bpy.ops.import_scene.gltf(filepath=str(source_path))
    else:
        report["warnings"].append(f"Unsupported body mesh format: {source}")
        return []
    imported = [obj for obj in bpy.data.objects if obj not in before]
    body_objects = []
    for obj in imported:
        if should_exclude_body_object(obj):
            report["warnings"].append(f"Excluded helper body object from production export: {obj.name}")
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        move_to(obj, collection)
        obj["source"] = source
        obj["recipe_role"] = "body_reference_or_work_basis"
        obj["pose_contract"] = recipe.get("body", {}).get("pose_contract", "")
        body_objects.append(obj)
    report["body_source"] = source
    report["body_objects"] = [obj.name for obj in body_objects]
    return body_objects


def should_exclude_body_object(obj):
    if obj.type in {"LIGHT", "CAMERA"}:
        return True
    if obj.type != "MESH":
        return False
    normalized = obj.name.lower()
    if obj.name in EXCLUDED_BODY_MESH_NAMES or (obj.data and obj.data.name in EXCLUDED_BODY_MESH_NAMES):
        return True
    return any(fragment in normalized for fragment in EXCLUDED_BODY_NAME_FRAGMENTS)


def add_reference_planes(recipe, collection, report):
    references = recipe.get("source", {}).get("reference_outputs", {})
    positions = {
        "front": (-2.0, -3.0, 1.2, 0.0),
        "front_3q": (-3.4, -2.0, 1.2, -0.45),
        "right": (3.0, -1.0, 1.2, 1.5708),
        "back": (2.0, 3.0, 1.2, 3.1416),
        "left": (-3.0, 1.0, 1.2, -1.5708),
    }
    for view, path in references.items():
        if view not in positions:
            continue
        image_path = resolve(path)
        if not image_path.exists():
            report["warnings"].append(f"Reference image missing: {path}")
            continue
        image = bpy.data.images.load(str(image_path), check_existing=True)
        obj = bpy.data.objects.new(f"REF_{view}", None)
        obj.empty_display_type = "IMAGE"
        obj.data = image
        obj.empty_display_size = 1.8
        obj.location = positions[view][0:3]
        obj.rotation_euler = (math.radians(90), 0.0, positions[view][3])
        obj["source"] = path
        obj["reference_only"] = True
        obj["export_exclude"] = True
        collection.objects.link(obj)
        report["reference_images"].append(path)


def add_socket_empties(recipe, collection, report):
    defaults = {
        "head": (0.0, 0.0, 1.65),
        "chest": (0.0, -0.08, 1.25),
        "hips": (0.0, -0.06, 0.95),
        "hand_l": (0.42, -0.04, 0.95),
        "hand_r": (-0.42, -0.04, 0.95),
        "back": (0.0, 0.18, 1.22),
        "feet": (0.0, 0.0, 0.08),
        "hands": (0.0, -0.04, 0.95),
    }
    for socket in recipe.get("sockets", []):
        if not isinstance(socket, dict):
            continue
        name = str(socket.get("name", "socket"))
        obj = bpy.data.objects.new(f"SOCKET_{name}", None)
        obj.empty_display_type = "ARROWS"
        obj.empty_display_size = 0.12
        obj.location = defaults.get(name, (0.0, 0.0, 1.0))
        obj["socket_name"] = name
        obj["parent_bone"] = str(socket.get("parent_bone", ""))
        obj["required"] = bool(socket.get("required", False))
        collection.objects.link(obj)
        report["sockets"].append({"name": name, "parent_bone": obj["parent_bone"], "required": obj["required"]})


def add_placeholder_equipment(recipe, collection, report):
    mats = {
        "primitive": material("recipe_placeholder_blue", (0.18, 0.35, 0.8, 1.0)),
        "hard_surface_mesh": material("recipe_hard_surface_gray", (0.42, 0.42, 0.42, 1.0)),
        "cloth_or_flexible_mesh": material("recipe_cloth_yellow", (0.85, 0.68, 0.18, 1.0)),
        "existing_asset": material("recipe_existing_asset_green", (0.22, 0.55, 0.26, 1.0)),
    }
    socket_positions = {
        "head": (0.0, 0.0, 1.78),
        "chest": (0.0, -0.13, 1.22),
        "hips": (0.0, -0.12, 0.92),
        "hand_l": (0.55, -0.05, 0.95),
        "hand_r": (-0.55, -0.05, 0.95),
        "back": (0.0, 0.25, 1.22),
        "feet": (0.0, 0.0, 0.05),
    }
    for part in recipe.get("equipment", []):
        if not isinstance(part, dict):
            continue
        representation = str(part.get("representation", "primitive"))
        socket = str(part.get("socket", "hand_r"))
        location = socket_positions.get(socket, (0.0, -0.2, 1.0))
        if representation == "cloth_or_flexible_mesh":
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
            obj = bpy.context.object
            obj.scale = (0.55, 0.04, 0.35)
        elif socket == "hand_r":
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.035, depth=0.9, location=location, rotation=(math.radians(90), 0.0, 0.0))
            obj = bpy.context.object
        elif socket == "hand_l":
            bpy.ops.mesh.primitive_cube_add(size=0.28, location=location)
            obj = bpy.context.object
            obj.scale = (0.75, 0.08, 1.0)
        else:
            bpy.ops.mesh.primitive_cube_add(size=0.22, location=location)
            obj = bpy.context.object
        obj.name = f"EQUIP_{part.get('part_id', 'part')}"
        obj["part_id"] = str(part.get("part_id", ""))
        obj["socket"] = socket
        obj["representation"] = representation
        obj["production_status"] = str(part.get("production_status", "planned"))
        obj["export_exclude"] = not bool(part.get("promote_to_production", False))
        obj["placeholder"] = True
        obj.data.materials.append(mats.get(representation, mats["primitive"]))
        move_to(obj, collection)
        report["equipment"].append({
            "part_id": obj["part_id"],
            "socket": socket,
            "representation": representation,
            "object": obj.name,
            "promote_to_production": not bool(obj["export_exclude"]),
            "export_excluded": bool(obj["export_exclude"]),
        })


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def ensure_ignored_source_dir(output_dir):
    source_dir = output_dir / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    gdignore = source_dir / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("", encoding="utf-8")
    return source_dir


def production_export_objects():
    objects = []
    for obj in bpy.data.objects:
        if bool(obj.get("export_exclude", False)):
            continue
        if obj.type not in {"ARMATURE", "MESH"}:
            continue
        objects.append(obj)
    return objects


def export_production_glb(path, report):
    objects = production_export_objects()
    report["exported_objects"] = [obj.name for obj in objects]
    if not objects:
        raise RuntimeError("No production mesh or armature objects are available for GLB export")
    bpy.ops.object.select_all(action="DESELECT")
    active = next((obj for obj in objects if obj.type == "ARMATURE"), objects[0])
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        use_visible=True,
        export_yup=True,
    )


def main():
    global PROJECT_ROOT
    options = args()
    PROJECT_ROOT = options.project_root.resolve()
    recipe = load_json(options.recipe)
    if recipe.get("game_mode_profile_id") != "3d_isometric_party":
        raise RuntimeError("Isometric assembly currently requires game_mode_profile_id=3d_isometric_party")
    if recipe.get("body", {}).get("pose_contract") != POSE_CONTRACT:
        raise RuntimeError(f"Recipe body must declare pose_contract={POSE_CONTRACT}")
    output_dir = ensure_project_output(options.output_dir)
    report = {
        "schema_version": 1,
        "status": "assembled",
        "character_id": recipe.get("character_id", ""),
        "recipe_version": recipe.get("recipe_version", ""),
        "recipe_path": res_path(resolve(options.recipe)),
        "warnings": [],
        "body_source": "",
        "body_objects": [],
        "reference_images": [],
        "sockets": [],
        "equipment": [],
        "outputs": {}
    }

    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = make_collection(f"{recipe.get('character_id', 'character')}_ISOMETRIC_ASSEMBLY")
    body = make_collection("BODY", root)
    references = make_collection("REFERENCES", root)
    sockets = make_collection("SOCKETS", root)
    equipment = make_collection("EQUIPMENT_PLACEHOLDERS", root)

    import_body(recipe, body, report)
    add_reference_planes(recipe, references, report)
    add_socket_empties(recipe, sockets, report)
    add_placeholder_equipment(recipe, equipment, report)

    source_dir = ensure_ignored_source_dir(output_dir)
    blend_path = source_dir / f"{recipe.get('character_id', 'character')}_{recipe.get('recipe_version', 'v1')}_isometric_assembly.blend"
    glb_path = output_dir / f"{recipe.get('character_id', 'character')}_{recipe.get('recipe_version', 'v1')}_isometric_assembly.glb"
    report_path = output_dir / "assembly_report.json"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_production_glb(glb_path, report)
    report["outputs"] = {
        "blender_work_file": res_path(blend_path),
        "godot_import_asset": res_path(glb_path),
        "assembly_report": res_path(report_path)
    }
    write_json(report_path, report)


if __name__ == "__main__":
    main()
