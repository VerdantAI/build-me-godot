#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import mathutils


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
PROCEDURAL_PRODUCTION_PARTS = {
    "helmet",
    "tool_belt",
    "clipboard",
    "tool",
}
MATERIAL_PRESET_COLORS = {
    "field_engineer_skin_sun_tan_light": (0.72, 0.48, 0.33, 1.0),
    "field_engineer_hair_brown": (0.18, 0.10, 0.055, 1.0),
    "field_engineer_eye_brown": (0.16, 0.09, 0.045, 1.0),
    "field_engineer_canvas_jacket_olive": (0.28, 0.34, 0.20, 1.0),
    "field_engineer_safety_yellow": (0.95, 0.74, 0.12, 1.0),
    "field_engineer_boot_dark": (0.055, 0.045, 0.04, 1.0),
}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--recipe")
    parser.add_argument("--assembly-report")
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--output-dir")
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
        configure_principled_material(existing, color)
        return existing
    mat = bpy.data.materials.new(name)
    configure_principled_material(mat, color)
    return mat


def configure_principled_material(mat, color):
    mat.diffuse_color = color
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled is None:
        principled = nodes.new(type="ShaderNodeBsdfPrincipled")
    if "Base Color" in principled.inputs:
        principled.inputs["Base Color"].default_value = color
    if "Alpha" in principled.inputs:
        principled.inputs["Alpha"].default_value = color[3]
    if "Roughness" in principled.inputs:
        principled.inputs["Roughness"].default_value = 0.82
    if "Metallic" in principled.inputs:
        principled.inputs["Metallic"].default_value = 0.0
    for input_name in ["Emission Color", "Emission"]:
        if input_name in principled.inputs:
            value = principled.inputs[input_name].default_value
            if hasattr(value, "__len__"):
                principled.inputs[input_name].default_value = (0.0, 0.0, 0.0, 1.0)
            else:
                principled.inputs[input_name].default_value = 0.0
    if "Emission Strength" in principled.inputs:
        principled.inputs["Emission Strength"].default_value = 0.0
    output = nodes.get("Material Output")
    if output is None:
        output = nodes.new(type="ShaderNodeOutputMaterial")
    if not principled.outputs["BSDF"].is_linked:
        mat.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])


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
    apply_customization(recipe, body_objects, report)
    return body_objects


def object_original_scale(obj):
    if "bmg_original_scale" not in obj:
        obj["bmg_original_scale"] = [float(obj.scale.x), float(obj.scale.y), float(obj.scale.z)]
    value = obj["bmg_original_scale"]
    return mathutils.Vector((float(value[0]), float(value[1]), float(value[2])))


def reset_customized_body_objects(body_objects):
    for obj in body_objects:
        if "bmg_original_scale" in obj:
            original = object_original_scale(obj)
            obj.scale = (original.x, original.y, original.z)


def apply_body_variant(recipe, body_objects, report):
    variant = recipe.get("body_variant", {})
    evidence = {
        "status": "not_configured",
        "provider": "",
        "variant_id": "",
        "applied_controls": {},
        "ignored_controls": {},
        "non_destructive": True,
        "limitations": [],
    }
    if not isinstance(variant, dict) or not variant:
        evidence["limitations"].append("Recipe has no body_variant.")
        return evidence
    evidence["status"] = "applied"
    evidence["provider"] = str(variant.get("provider", ""))
    evidence["variant_id"] = str(variant.get("variant_id", ""))
    evidence["limitations"] = list(variant.get("limitations", []))
    controls = variant.get("controls", {}) if isinstance(variant.get("controls", {}), dict) else {}
    reset_customized_body_objects(body_objects)
    height = float(controls.get("height_scale", 1.0))
    width = max(float(controls.get("shoulder_width", 1.0)), float(controls.get("torso_width", 1.0)))
    for obj in body_objects:
        original = object_original_scale(obj)
        if obj.type in {"ARMATURE", "MESH"}:
            obj.scale = (original.x * width, original.y, original.z * height)
    evidence["applied_controls"]["height_scale"] = height
    evidence["applied_controls"]["shoulder_width"] = width
    if "torso_width" in controls:
        evidence["applied_controls"]["torso_width"] = float(controls.get("torso_width", 1.0))
    for ignored in ["head_scale", "limb_thickness"]:
        if ignored in controls:
            evidence["ignored_controls"][ignored] = {
                "value": float(controls.get(ignored, 1.0)),
                "reason": "Current base does not expose separate semantic morph or bone-safe object controls for this value.",
            }
    if evidence["provider"] == "project_base_transform_controls":
        evidence["limitations"].append("Applied as coarse local object scale in the character assembly file.")
    return evidence


def material_preset(name):
    color = MATERIAL_PRESET_COLORS.get(str(name), (0.8, 0.8, 0.8, 1.0))
    return material(f"BMG_{name}", color)


def material_matches_slot(obj, mat, tokens):
    for token in tokens:
        lowered = str(token).lower()
        if lowered and (lowered == obj.name.lower() or lowered == mat.name.lower()):
            return True
    return False


def apply_material_overrides(recipe, body_objects, report):
    overrides = recipe.get("material_overrides", {})
    evidence = {
        "status": "not_configured",
        "provider": "",
        "applied_slots": {},
        "unresolved_slots": {},
        "limitations": [],
    }
    if not isinstance(overrides, dict) or not overrides:
        evidence["limitations"].append("Recipe has no material_overrides.")
        return evidence
    evidence["status"] = "applied"
    evidence["provider"] = str(overrides.get("provider", "recipe_material_slot_overrides"))
    evidence["limitations"] = list(overrides.get("limitations", []))
    slot_map = overrides.get("slot_map", {}) if isinstance(overrides.get("slot_map", {}), dict) else {}
    slots = overrides.get("slots", {}) if isinstance(overrides.get("slots", {}), dict) else {}
    # The current base has a single body material, so body_primary is the least misleading visible override.
    preferred_slot_order = ["body_primary", "hair", "eyes", "rubber_or_leather", "body_secondary", "skin"]
    assigned_indices = set()
    for slot in preferred_slot_order:
        if slot not in slots:
            continue
        tokens = slot_map.get(slot, [])
        if not isinstance(tokens, list):
            tokens = [tokens]
        replacement = material_preset(slots[slot])
        applied = []
        for obj in body_objects:
            if not hasattr(obj.data, "materials"):
                continue
            for index, current in enumerate(obj.data.materials):
                assignment_key = (obj.name, index)
                if assignment_key in assigned_indices:
                    continue
                if current and material_matches_slot(obj, current, tokens):
                    obj.data.materials[index] = replacement
                    assigned_indices.add(assignment_key)
                    applied.append({"object": obj.name, "material_index": index, "preset": str(slots[slot])})
        if applied:
            evidence["applied_slots"][slot] = applied
        else:
            evidence["unresolved_slots"][slot] = {
                "preset": str(slots[slot]),
                "reason": "No object/material matched the configured slot_map.",
            }
    if "body_primary" in evidence["applied_slots"] and ("skin" in slots or "body_secondary" in slots):
        evidence["limitations"].append("Current base uses one body material; skin/clothing colors cannot be separated without texture repainting or a richer base.")
    if not evidence["applied_slots"]:
        evidence["status"] = "warning"
        report["warnings"].append("Material overrides were configured but no base material slots were matched.")
    return evidence


def apply_customization(recipe, body_objects, report):
    body_variant = apply_body_variant(recipe, body_objects, report)
    material_overrides = apply_material_overrides(recipe, body_objects, report)
    report["customization"] = {
        "schema_version": 1,
        "body_variant": body_variant,
        "material_overrides": material_overrides,
        "meaningful_difference": {
            "status": "pending_equipment_review",
            "material_identity": bool(material_overrides.get("applied_slots", {})),
            "body_variant": body_variant.get("status") == "applied",
            "silhouette_equipment": False,
            "warnings": [
                "Reusable production accessories are still required for strong field-engineer silhouette."
            ],
        },
    }


def update_customization_equipment_evidence(report):
    customization = report.get("customization", {})
    if not isinstance(customization, dict):
        return
    meaningful = customization.get("meaningful_difference", {})
    if not isinstance(meaningful, dict):
        meaningful = {}
    production_equipment = []
    placeholder_equipment = []
    for part in report.get("equipment", []):
        if not isinstance(part, dict):
            continue
        if bool(part.get("export_excluded", False)):
            placeholder_equipment.append(str(part.get("part_id", "")))
        else:
            production_equipment.append(str(part.get("part_id", "")))
    meaningful["silhouette_equipment"] = bool(production_equipment)
    meaningful["production_equipment"] = production_equipment
    meaningful["placeholder_equipment"] = placeholder_equipment
    warnings = meaningful.get("warnings", [])
    if not isinstance(warnings, list):
        warnings = []
    if not production_equipment and "Reusable production accessories are still required for strong field-engineer silhouette." not in warnings:
        warnings.append("Reusable production accessories are still required for strong field-engineer silhouette.")
    if meaningful.get("material_identity", False) and meaningful.get("body_variant", False) and production_equipment:
        meaningful["status"] = "meaningfully_customized"
    else:
        meaningful["status"] = "partial"
    meaningful["warnings"] = warnings
    customization["meaningful_difference"] = meaningful
    report["customization"] = customization


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


def set_equipment_metadata(obj, part, export_exclude, placeholder):
    obj["part_id"] = str(part.get("part_id", ""))
    obj["socket"] = str(part.get("socket", ""))
    obj["representation"] = str(part.get("representation", "primitive"))
    obj["production_status"] = "generated_procedural" if not export_exclude else str(part.get("production_status", "planned"))
    obj["export_exclude"] = export_exclude
    obj["placeholder"] = placeholder


def add_cube_part(collection, name, location, scale, mat, part, export_exclude=False, placeholder=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    set_equipment_metadata(obj, part, export_exclude, placeholder)
    move_to(obj, collection)
    return obj


def add_cylinder_part(collection, name, location, radius, depth, mat, part, rotation=(0.0, 0.0, 0.0), vertices=24, scale=(1.0, 1.0, 1.0), export_exclude=False, placeholder=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    set_equipment_metadata(obj, part, export_exclude, placeholder)
    move_to(obj, collection)
    return obj


def add_uv_sphere_part(collection, name, location, scale, mat, part, segments=24, ring_count=8, export_exclude=False, placeholder=False):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=ring_count, radius=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    set_equipment_metadata(obj, part, export_exclude, placeholder)
    move_to(obj, collection)
    return obj


def add_procedural_helmet(part, collection, mats, report):
    objects = [
        add_uv_sphere_part(collection, "EQUIP_helmet_shell", (0.0, 0.0, 1.82), (0.18, 0.14, 0.09), mats["helmet"], part),
        add_cube_part(collection, "EQUIP_helmet_brim", (0.0, -0.11, 1.78), (0.24, 0.08, 0.018), mats["helmet"], part),
        add_cylinder_part(collection, "EQUIP_helmet_lamp", (0.0, -0.18, 1.79), 0.035, 0.035, mats["tool"], part, rotation=(math.radians(90), 0.0, 0.0), vertices=16),
    ]
    return record_equipment(part, objects, report, "procedural_hard_surface")


def add_procedural_tool_belt(part, collection, mats, report):
    objects = [
        add_cylinder_part(collection, "EQUIP_tool_belt_band", (0.0, -0.03, 0.92), 0.37, 0.09, mats["belt"], part, vertices=32, scale=(1.0, 0.72, 1.0)),
        add_cube_part(collection, "EQUIP_tool_belt_pouch_l", (0.28, -0.16, 0.88), (0.08, 0.035, 0.12), mats["pouch"], part),
        add_cube_part(collection, "EQUIP_tool_belt_pouch_r", (-0.28, -0.16, 0.88), (0.08, 0.035, 0.12), mats["pouch"], part),
        add_cylinder_part(collection, "EQUIP_tool_belt_loop", (0.0, -0.18, 0.89), 0.055, 0.025, mats["metal"], part, rotation=(math.radians(90), 0.0, 0.0), vertices=16, scale=(1.0, 0.45, 1.0)),
    ]
    return record_equipment(part, objects, report, "procedural_hard_surface")


def add_procedural_clipboard(part, collection, mats, report):
    objects = [
        add_cube_part(collection, "EQUIP_clipboard_board", (0.55, -0.05, 0.96), (0.11, 0.018, 0.18), mats["clipboard"], part),
        add_cube_part(collection, "EQUIP_clipboard_clip", (0.55, -0.075, 1.11), (0.07, 0.012, 0.018), mats["metal"], part),
        add_cube_part(collection, "EQUIP_clipboard_paper", (0.55, -0.078, 0.96), (0.095, 0.006, 0.15), mats["paper"], part),
    ]
    return record_equipment(part, objects, report, "procedural_hard_surface")


def add_procedural_tool(part, collection, mats, report):
    objects = [
        add_cylinder_part(collection, "EQUIP_tool_handle", (-0.55, -0.05, 0.94), 0.025, 0.55, mats["belt"], part, rotation=(math.radians(90), 0.0, 0.0), vertices=16),
        add_cube_part(collection, "EQUIP_tool_head", (-0.55, -0.33, 0.94), (0.12, 0.035, 0.045), mats["metal"], part),
    ]
    return record_equipment(part, objects, report, "procedural_hard_surface")


def record_equipment(part, objects, report, source_kind, export_excluded=False):
    names = [obj.name for obj in objects]
    record = {
        "part_id": str(part.get("part_id", "")),
        "socket": str(part.get("socket", "")),
        "representation": str(part.get("representation", "")),
        "object": names[0] if names else "",
        "objects": names,
        "source_kind": source_kind,
        "promote_to_production": not export_excluded,
        "export_excluded": export_excluded,
    }
    report["equipment"].append(record)
    return record


def add_equipment(recipe, collection, report):
    mats = {
        "primitive": material("recipe_placeholder_blue", (0.18, 0.35, 0.8, 1.0)),
        "hard_surface_mesh": material("recipe_hard_surface_gray", (0.42, 0.42, 0.42, 1.0)),
        "cloth_or_flexible_mesh": material("recipe_cloth_yellow", (0.85, 0.68, 0.18, 1.0)),
        "existing_asset": material("recipe_existing_asset_green", (0.22, 0.55, 0.26, 1.0)),
        "helmet": material("field_engineer_helmet_white", (0.92, 0.88, 0.72, 1.0)),
        "belt": material("field_engineer_belt_dark", (0.08, 0.07, 0.06, 1.0)),
        "pouch": material("field_engineer_pouch_leather", (0.24, 0.16, 0.09, 1.0)),
        "clipboard": material("field_engineer_clipboard_brown", (0.35, 0.22, 0.12, 1.0)),
        "paper": material("field_engineer_paper", (0.86, 0.84, 0.76, 1.0)),
        "metal": material("field_engineer_tool_metal", (0.52, 0.54, 0.55, 1.0)),
        "tool": material("field_engineer_lamp_yellow", (1.0, 0.82, 0.28, 1.0)),
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
        part_id = str(part.get("part_id", ""))
        if part_id in PROCEDURAL_PRODUCTION_PARTS and bool(part.get("promote_to_production", False)):
            if part_id == "helmet":
                add_procedural_helmet(part, collection, mats, report)
            elif part_id == "tool_belt":
                add_procedural_tool_belt(part, collection, mats, report)
            elif part_id == "clipboard":
                add_procedural_clipboard(part, collection, mats, report)
            elif part_id == "tool":
                add_procedural_tool(part, collection, mats, report)
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
        set_equipment_metadata(obj, part, True, True)
        obj.data.materials.append(mats.get(representation, mats["primitive"]))
        move_to(obj, collection)
        record_equipment(part, [obj], report, "placeholder", True)


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


def scene_bounds(objects):
    min_corner = [float("inf"), float("inf"), float("inf")]
    max_corner = [float("-inf"), float("-inf"), float("-inf")]
    saw_bounds = False
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ mathutils.Vector(corner)
            for index in range(3):
                min_corner[index] = min(min_corner[index], world[index])
                max_corner[index] = max(max_corner[index], world[index])
            saw_bounds = True
    if not saw_bounds:
        return mathutils.Vector((0.0, 0.0, 0.9)), 2.0
    minimum = mathutils.Vector(min_corner)
    maximum = mathutils.Vector(max_corner)
    center = (minimum + maximum) * 0.5
    radius = max((maximum - minimum).length * 0.5, 0.75)
    return center, radius


def create_readability_capture(output_dir, recipe, report):
    character_id = str(recipe.get("character_id", "character"))
    version = str(recipe.get("recipe_version", "v1"))
    character_dir = output_dir.parent.parent
    preview_dir = character_dir / "previews" / version
    report_dir = character_dir / "reports" / version
    preview_dir.mkdir(parents=True, exist_ok=True)
    report_dir.mkdir(parents=True, exist_ok=True)
    preview_path = preview_dir / "isometric_readability.png"
    readability_report_path = report_dir / "isometric_readability.json"

    for obj in bpy.data.objects:
        if bool(obj.get("export_exclude", False)) or bool(obj.get("reference_only", False)):
            obj.hide_render = True
    objects = production_export_objects()
    center, radius = scene_bounds(objects)
    bpy.ops.object.light_add(type="SUN", location=(0.0, -3.0, 5.0), rotation=(math.radians(45), 0.0, math.radians(35)))
    sun = bpy.context.object
    sun.name = "READABILITY_Sun"
    sun.data.energy = 2.0

    bpy.ops.object.camera_add(location=(center.x + 3.2, center.y - 4.2, center.z + 2.6), rotation=(math.radians(60), 0.0, math.radians(38)))
    camera = bpy.context.object
    direction = center - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(radius * 2.2, 2.4)
    bpy.context.scene.camera = camera

    engines = {item.identifier for item in bpy.context.scene.render.bl_rna.properties["engine"].enum_items}
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512
    bpy.context.scene.render.film_transparent = False
    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("READABILITY_World")
    bpy.context.scene.world.color = (0.78, 0.80, 0.82)
    bpy.context.scene.render.filepath = str(preview_path)
    bpy.ops.render.render(write_still=True)

    readability = {
        "schema_version": 1,
        "status": "valid" if preview_path.exists() else "failed",
        "character_id": character_id,
        "recipe_version": version,
        "game_mode_profile_id": recipe.get("game_mode_profile_id", ""),
        "preview": res_path(preview_path),
        "camera": {
            "type": "orthographic",
            "ortho_scale": camera.data.ortho_scale,
            "position": [camera.location.x, camera.location.y, camera.location.z],
        },
        "resolution": [512, 512],
        "production_object_count": len(objects),
        "exported_objects": report.get("exported_objects", []),
        "warnings": [],
    }
    if not preview_path.exists():
        readability["warnings"].append("Blender render did not write the preview image.")
    write_json(readability_report_path, readability)
    report["readability"] = readability
    return {
        "readability_preview": res_path(preview_path),
        "readability_report": res_path(readability_report_path),
    }


def remove_existing_equipment():
    for obj in list(bpy.data.objects):
        if str(obj.name).startswith("EQUIP_") or "part_id" in obj:
            bpy.data.objects.remove(obj, do_unlink=True)


def existing_body_objects(report):
    names = set(str(name) for name in report.get("body_objects", []))
    objects = []
    for obj in bpy.data.objects:
        if obj.name in names and obj.type in {"ARMATURE", "MESH"}:
            objects.append(obj)
    if objects:
        return objects
    for obj in bpy.data.objects:
        if obj.type not in {"ARMATURE", "MESH"}:
            continue
        if bool(obj.get("export_exclude", False)) or bool(obj.get("reference_only", False)):
            continue
        if str(obj.name).startswith("EQUIP_") or "part_id" in obj:
            continue
        objects.append(obj)
    return objects


def refresh_equipment_from_recipe(recipe, report):
    remove_existing_equipment()
    collection = bpy.data.collections.get("EQUIPMENT")
    if collection is None:
        collection = make_collection("EQUIPMENT")
    report["equipment"] = []
    add_equipment(recipe, collection, report)
    update_customization_equipment_evidence(report)


def capture_existing_readability(options):
    report_path = resolve(options.assembly_report)
    report = load_json(options.assembly_report)
    outputs = report.get("outputs", {})
    blend_path = resolve(outputs.get("blender_work_file", ""))
    if not blend_path.exists():
        raise RuntimeError(f"Blender work file is missing: {outputs.get('blender_work_file', '')}")
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))
    recipe_path = str(report.get("recipe_path", ""))
    recipe = load_json(recipe_path) if recipe_path else {}
    version = str(recipe.get("recipe_version", report.get("recipe_version", "v1")))
    character_id = str(recipe.get("character_id", report.get("character_id", "character")))
    output_dir = report_path.parent
    if recipe:
        body_objects = existing_body_objects(report)
        report["body_objects"] = [obj.name for obj in body_objects]
        apply_customization(recipe, body_objects, report)
        refresh_equipment_from_recipe(recipe, report)
    glb_path = resolve(outputs.get("godot_import_asset", output_dir / f"{character_id}_{version}_isometric_assembly.glb"))
    export_production_glb(glb_path, report)
    outputs["godot_import_asset"] = res_path(glb_path)
    readability_outputs = create_readability_capture(output_dir, recipe, report)
    outputs.update(readability_outputs)
    report["outputs"] = outputs
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    write_json(report_path, report)


def main():
    global PROJECT_ROOT
    options = args()
    PROJECT_ROOT = options.project_root.resolve()
    if options.assembly_report:
        capture_existing_readability(options)
        return
    if not options.recipe or not options.output_dir:
        raise RuntimeError("--recipe and --output-dir are required unless --assembly-report is provided")
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
    equipment = make_collection("EQUIPMENT", root)

    import_body(recipe, body, report)
    add_reference_planes(recipe, references, report)
    add_socket_empties(recipe, sockets, report)
    add_equipment(recipe, equipment, report)
    update_customization_equipment_evidence(report)

    source_dir = ensure_ignored_source_dir(output_dir)
    blend_path = source_dir / f"{recipe.get('character_id', 'character')}_{recipe.get('recipe_version', 'v1')}_isometric_assembly.blend"
    glb_path = output_dir / f"{recipe.get('character_id', 'character')}_{recipe.get('recipe_version', 'v1')}_isometric_assembly.glb"
    report_path = output_dir / "assembly_report.json"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_production_glb(glb_path, report)
    readability_outputs = create_readability_capture(output_dir, recipe, report)
    report["outputs"] = {
        "blender_work_file": res_path(blend_path),
        "godot_import_asset": res_path(glb_path),
        "assembly_report": res_path(report_path),
        **readability_outputs,
    }
    write_json(report_path, report)


if __name__ == "__main__":
    main()
