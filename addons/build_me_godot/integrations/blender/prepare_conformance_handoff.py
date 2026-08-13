#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


POSE_CONTRACT = "neutral_a_pose_30deg_v1"
PROJECT_ROOT = Path.cwd()
VIEW_LAYOUT = {
    "front": {"location": (-1.6, -2.2, 1.2), "rotation": (1.5708, 0.0, 0.0), "projection_axes": ("x", "z")},
    "right": {"location": (2.2, -0.8, 1.2), "rotation": (1.5708, 0.0, 1.5708), "projection_axes": ("y", "z")},
    "back": {"location": (1.6, 2.2, 1.2), "rotation": (1.5708, 0.0, 3.1416), "projection_axes": ("x", "z")},
    "left": {"location": (-2.2, 0.8, 1.2), "rotation": (1.5708, 0.0, -1.5708), "projection_axes": ("y", "z")},
}
AXIS_INDEX = {"x": 0, "y": 1, "z": 2}


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--conformance-plan", default="")
    parser.add_argument("--mesh-guidance", default="")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--output-dir", required=True)
    parsed = parser.parse_args(argv)
    if not parsed.conformance_plan and not parsed.mesh_guidance:
        parser.error("--conformance-plan or --mesh-guidance is required")
    return parsed


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


def make_collection(name, parent=None):
    collection = bpy.data.collections.new(name)
    (parent.children if parent else bpy.context.scene.collection.children).link(collection)
    return collection


def move_to(obj, target):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    target.objects.link(obj)


def tag_reference(obj, source, purpose):
    obj["source"] = source
    obj["purpose"] = purpose
    obj["reference_only"] = True
    obj["export_exclude"] = True
    obj.hide_select = True


def align_object(obj):
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    obj["pose_contract"] = POSE_CONTRACT


def add_image_reference(name, path, view, collection, report):
    source = resolve(path)
    if not source.exists():
        report["warnings"].append(f"Reference image missing: {path}")
        return
    image = bpy.data.images.load(str(source), check_existing=True)
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "IMAGE"
    obj.data = image
    obj.empty_display_size = 1.8
    obj.color[3] = 0.45
    tag_reference(obj, str(path), "Approved image reference")
    layout = VIEW_LAYOUT.get(str(view), VIEW_LAYOUT["front"])
    obj.location = layout["location"]
    obj.rotation_euler = layout["rotation"]
    obj["view"] = str(view)
    obj["pose_contract"] = POSE_CONTRACT
    collection.objects.link(obj)
    report["reference_images"].append(str(path))


def import_meshes(path, collection, purpose, report, duplicate_work=False, work_collection=None):
    source = resolve(path)
    if not source.exists():
        report["warnings"].append(f"Mesh missing: {path}")
        return []
    before = set(bpy.data.objects)
    extension = source.suffix.lower()
    if extension in [".glb", ".gltf"]:
        bpy.ops.import_scene.gltf(filepath=str(source))
    elif extension == ".obj":
        bpy.ops.wm.obj_import(filepath=str(source))
    else:
        report["warnings"].append(f"Unsupported mesh extension: {path}")
        return []
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type in ["MESH", "ARMATURE", "EMPTY"]]
    for obj in imported:
        move_to(obj, collection)
        align_object(obj)
        tag_reference(obj, str(path), purpose)
    if duplicate_work and work_collection:
        for obj in imported:
            if obj.type != "MESH":
                continue
            duplicate = obj.copy()
            duplicate.data = obj.data.copy()
            duplicate.name = f"{obj.name}_CONFORMANCE_WORK"
            align_object(duplicate)
            duplicate["source_reference"] = str(path)
            duplicate["generated_work_file"] = True
            duplicate["reference_only"] = False
            duplicate["export_exclude"] = False
            duplicate.hide_select = False
            work_collection.objects.link(duplicate)
            report["work_meshes"].append(duplicate.name)
    report["reference_meshes"].append(str(path))
    return imported


def bounds_3d(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        return None
    return {
        "min": [round(min(point[index] for point in points), 5) for index in range(3)],
        "max": [round(max(point[index] for point in points), 5) for index in range(3)],
        "size": [round(max(point[index] for point in points) - min(point[index] for point in points), 5) for index in range(3)],
    }


def provider_proxy_outputs(plan):
    outputs = []
    for provider in plan.get("providers", []):
        if not isinstance(provider, dict):
            continue
        provider_outputs = provider.get("outputs", {})
        if isinstance(provider_outputs, dict):
            outputs.extend(str(value) for value in provider_outputs.values() if str(value))
    return outputs


def object_bounds(objects, axes):
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            points.append((world[AXIS_INDEX[axes[0]]], world[AXIS_INDEX[axes[1]]]))
    if not points:
        return None
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return {"min_x": min(xs), "max_x": max(xs), "min_y": min(ys), "max_y": max(ys)}


def bounds_delta(source_bounds, proxy_bounds):
    if not source_bounds or not proxy_bounds:
        return {}
    source_width = max(source_bounds["max_x"] - source_bounds["min_x"], 0.0001)
    source_height = max(source_bounds["max_y"] - source_bounds["min_y"], 0.0001)
    proxy_width = max(proxy_bounds["max_x"] - proxy_bounds["min_x"], 0.0001)
    proxy_height = max(proxy_bounds["max_y"] - proxy_bounds["min_y"], 0.0001)
    return {
        "width_delta_ratio": round((proxy_width - source_width) / source_width, 4),
        "height_delta_ratio": round((proxy_height - source_height) / source_height, 4),
    }


def svg_rect(bounds, color, label):
    if not bounds:
        return ""
    width = max(bounds["max_x"] - bounds["min_x"], 0.0001)
    height = max(bounds["max_y"] - bounds["min_y"], 0.0001)
    scale = min(260.0 / width, 300.0 / height)
    x = 320.0 + bounds["min_x"] * scale
    y = 360.0 - bounds["max_y"] * scale
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{width * scale:.2f}" height="{height * scale:.2f}" fill="none" stroke="{color}" stroke-width="3"/><text x="{x:.2f}" y="{max(y - 8.0, 18.0):.2f}" fill="{color}" font-size="14">{label}</text>'


def write_silhouette_overlays(output_dir, report, source_collection, proxy_collection, work_collection):
    overlay_dir = output_dir / "overlays"
    overlay_dir.mkdir(parents=True, exist_ok=True)
    source_objects = list(source_collection.objects)
    proxy_objects = list(proxy_collection.objects)
    work_objects = list(work_collection.objects)
    report["silhouette_overlays"] = {}
    for view in ["front", "right", "back"]:
        axes = VIEW_LAYOUT[view]["projection_axes"]
        source_bounds = object_bounds(source_objects, axes)
        proxy_bounds = object_bounds(proxy_objects, axes)
        work_bounds = object_bounds(work_objects, axes)
        overlay = {
            "schema_version": 1,
            "view": view,
            "pose_contract": POSE_CONTRACT,
            "projection_axes": list(axes),
            "source_bounds": source_bounds,
            "proxy_bounds": proxy_bounds,
            "work_bounds": work_bounds,
            "proxy_delta": bounds_delta(source_bounds, proxy_bounds),
            "work_delta": bounds_delta(source_bounds, work_bounds),
            "reference_only": True,
        }
        json_path = overlay_dir / f"{view}_silhouette_overlay.json"
        svg_path = overlay_dir / f"{view}_silhouette_overlay.svg"
        svg = "\n".join([
            '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420" viewBox="0 0 640 420">',
            '<rect width="640" height="420" fill="#f8f8f8"/>',
            f'<text x="24" y="32" fill="#222" font-size="18">{view} silhouette overlay</text>',
            svg_rect(source_bounds, "#1f77b4", "source"),
            svg_rect(proxy_bounds, "#d62728", "proxy"),
            svg_rect(work_bounds, "#2ca02c", "work"),
            "</svg>",
        ])
        json_path.write_text(json.dumps(overlay, indent=2) + "\n")
        svg_path.write_text(svg + "\n")
        report["silhouette_overlays"][view] = {
            "report": res_path(json_path),
            "preview": res_path(svg_path),
        }
        report["changed_paths"].extend([res_path(json_path), res_path(svg_path)])


def clothing_shell_candidates(plan):
    targets = plan.get("field_engineer_targets", {})
    silhouette = set(targets.get("silhouette", []))
    candidates = []
    templates = {
        "helmet": {"asset_id": "hardhat_shell", "region": "head", "socket": "head", "kind": "separate_attachment"},
        "vest": {"asset_id": "hi_vis_vest_shell", "region": "torso", "socket": "chest", "kind": "clothing_shell"},
        "tool_belt": {"asset_id": "utility_belt_shell", "region": "hips", "socket": "hips", "kind": "separate_attachment"},
        "boots": {"asset_id": "work_boot_overlays", "region": "feet", "socket": "feet", "kind": "clothing_shell"},
        "gloves": {"asset_id": "work_glove_overlays", "region": "hands", "socket": "hands", "kind": "clothing_shell"},
    }
    for target, template in templates.items():
        if target in silhouette:
            candidate = dict(template)
            candidate["source_target"] = target
            candidate["review_required"] = True
            candidates.append(candidate)
    return candidates


def build_conformance_guidance(plan, report, source_collection, proxy_collection, work_collection):
    source_bounds = bounds_3d(list(source_collection.objects))
    proxy_bounds = bounds_3d(list(proxy_collection.objects))
    work_bounds = bounds_3d(list(work_collection.objects))
    targets = plan.get("field_engineer_targets", {})
    warnings = list(report.get("warnings", []))
    if not proxy_bounds:
        warnings.append("No proxy mesh bounds were available; guidance is based on source mesh and image references only.")
    guidance = {
        "schema_version": 1,
        "character_id": plan.get("character_id", ""),
        "reference_version": plan.get("reference_version", ""),
        "pose_contract": plan.get("pose_contract", ""),
        "source_plan": report.get("source_plan", ""),
        "status": "guidance_ready",
        "bounds": {
            "source": source_bounds,
            "proxy": proxy_bounds,
            "work": work_bounds,
        },
        "silhouette_overlays": report.get("silhouette_overlays", {}),
        "body_region_scale_hints": {
            view: overlay.get("proxy_delta", {})
            for view, overlay in _load_overlay_reports(report).items()
            if overlay.get("proxy_delta", {})
        },
        "clothing_shell_candidates": clothing_shell_candidates(plan),
        "prop_candidates": targets.get("props", []),
        "material_targets": targets.get("materials", []),
        "color_targets": targets.get("colors", []),
        "validation_constraints": plan.get("validation_constraints", {}),
        "reference_only_collections": [
            "APPROVED_IMAGE_REFERENCES",
            "SOURCE_RIGGED_MESH_REFERENCES",
            "AI_PROXY_MESH_REFERENCES",
        ],
        "editable_collections": ["GENERATED_CONFORMANCE_WORK_MESHES"],
        "warnings": warnings,
        "blockers": [],
        "changed_paths": [],
    }
    constraints = guidance["validation_constraints"]
    if not constraints.get("source_meshes_immutable", False) or constraints.get("production_topology_from_proxy_allowed", True):
        guidance["blockers"].append("Conformance constraints would allow source/proxy topology mutation.")
        guidance["status"] = "blocked"
    return guidance


def _load_overlay_reports(report):
    overlays = {}
    for view, paths in report.get("silhouette_overlays", {}).items():
        report_path = paths.get("report", "")
        source = resolve(report_path)
        if source.exists():
            overlays[view] = json.loads(source.read_text())
    return overlays


def main():
    global PROJECT_ROOT
    options = args()
    PROJECT_ROOT = Path(options.project_root).resolve()
    plan_input = options.conformance_plan if options.conformance_plan else options.mesh_guidance
    plan_path = resolve(plan_input)
    output_dir = resolve(options.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    plan = json.loads(plan_path.read_text())
    if plan.get("pose_contract") != POSE_CONTRACT:
        raise RuntimeError(f"Conformance plan must declare pose_contract={POSE_CONTRACT!r}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    root = make_collection("CONFORMANCE_HANDOFF")
    images = make_collection("APPROVED_IMAGE_REFERENCES", root)
    source_meshes = make_collection("SOURCE_RIGGED_MESH_REFERENCES", root)
    proxy_meshes = make_collection("AI_PROXY_MESH_REFERENCES", root)
    work_meshes = make_collection("GENERATED_CONFORMANCE_WORK_MESHES", root)

    report = {
        "schema_version": 1,
        "character_id": plan.get("character_id", ""),
        "reference_version": plan.get("reference_version", ""),
        "pose_contract": plan.get("pose_contract", ""),
        "source_plan": res_path(plan_path),
        "reference_images": [],
        "reference_meshes": [],
        "work_meshes": [],
        "collections": {
            "root": root.name,
            "images": images.name,
            "source_meshes": source_meshes.name,
            "proxy_meshes": proxy_meshes.name,
            "work_meshes": work_meshes.name,
        },
        "validation_constraints": plan.get("validation_constraints", {}),
        "warnings": [],
        "changed_paths": [],
    }

    for view, path in plan.get("source_references", {}).items():
        add_image_reference(f"REF_{view}", path, view, images, report)
    rigged = plan.get("rigged_meshes", {})
    for key in ["primary", "secondary"]:
        path = rigged.get(key, "")
        if path:
            import_meshes(path, source_meshes, f"Source {key} rigged mesh reference", report, True, work_meshes)
    for path in provider_proxy_outputs(plan):
        import_meshes(path, proxy_meshes, "AI reconstruction proxy reference", report, False, None)
    report["bounds"] = {
        "source": bounds_3d(list(source_meshes.objects)),
        "proxy": bounds_3d(list(proxy_meshes.objects)),
        "work": bounds_3d(list(work_meshes.objects)),
    }

    blend_path = output_dir / f"{plan.get('character_id', 'character')}_{plan.get('reference_version', 'v0')}_conformance_handoff.blend"
    report_path = output_dir / "conformance_handoff_report.json"
    guidance_path = output_dir / "conformance_guidance.json"
    report["blend"] = res_path(blend_path)
    report["report"] = res_path(report_path)
    report["guidance"] = res_path(guidance_path)
    report["alignment"] = {
        "pose_contract": POSE_CONTRACT,
        "mesh_origin": [0.0, 0.0, 0.0],
        "mesh_rotation_euler": [0.0, 0.0, 0.0],
        "mesh_scale": [1.0, 1.0, 1.0],
        "reference_views": {view: VIEW_LAYOUT[view]["location"] for view in VIEW_LAYOUT},
    }
    write_silhouette_overlays(output_dir, report, source_meshes, proxy_meshes, work_meshes)
    guidance = build_conformance_guidance(plan, report, source_meshes, proxy_meshes, work_meshes)
    guidance["changed_paths"].append(report["guidance"])
    guidance_path.write_text(json.dumps(guidance, indent=2) + "\n")
    report["changed_paths"].extend([report["blend"], report["report"], report["guidance"]])
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("BUILD_ME_GODOT_CONFORMANCE_HANDOFF=" + json.dumps(report, sort_keys=True))
    bpy.ops.wm.quit_blender()


if __name__ == "__main__":
    main()
