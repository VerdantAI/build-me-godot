from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"
ASSET_BLEND = ROOT / "assets" / "library" / "burning_barb_prototyping_mannequin.blend"
ASSET_COLLECTION = "Burning Barb Prototyping Mannequin"


def bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = []
    for obj in objects:
        if obj.type == "MESH":
            points.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
    return (
        Vector((min(v.x for v in points), min(v.y for v in points), min(v.z for v in points))),
        Vector((max(v.x for v in points), max(v.y for v in points), max(v.z for v in points))),
    )


def remove_previous_mannequin() -> None:
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Rigaround_HighRes_"):
            bpy.data.objects.remove(obj, do_unlink=True)

    for collection in list(bpy.data.collections):
        if collection.name.startswith("Rigaround High Resolution Mannequin"):
            bpy.data.collections.remove(collection)


def hide_scene_level_detail_meshes() -> None:
    for obj in bpy.data.objects:
        if obj.name.startswith("Rigaround_Realistic_"):
            obj.hide_viewport = True
            obj.hide_render = True


def append_mannequin_collection() -> bpy.types.Collection:
    with bpy.data.libraries.load(str(ASSET_BLEND), link=False) as (source, target):
        if ASSET_COLLECTION not in source.collections:
            raise RuntimeError(f"Asset collection not found: {ASSET_COLLECTION}")
        target.collections = [ASSET_COLLECTION]

    collection = bpy.data.collections[ASSET_COLLECTION]
    collection.name = "Rigaround High Resolution Mannequin"
    bpy.context.scene.collection.children.link(collection)
    return collection


def align_to_rig(collection: bpy.types.Collection) -> None:
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    min_corner, max_corner = bounds_for(meshes)
    source_height = max_corner.z - min_corner.z
    target_height = 3.72
    scale = target_height / source_height
    center_x = (min_corner.x + max_corner.x) * 0.5
    center_y = (min_corner.y + max_corner.y) * 0.5

    for obj in meshes:
        for vertex in obj.data.vertices:
            vertex.co.x = (vertex.co.x - center_x) * scale
            vertex.co.y = (vertex.co.y - center_y) * scale
            vertex.co.z = (vertex.co.z - min_corner.z) * scale
        obj.data.update()
        obj.name = f"Rigaround_HighRes_{obj.name.removeprefix('BurningBarb_')}"
        obj.data.name = obj.name


def find_weight_donor() -> bpy.types.Object:
    candidates = (
        "Rigaround_Kenney_Weight_Donor",
        "Rigaround_Male_characterMedium",
    )
    for name in candidates:
        obj = bpy.data.objects.get(name)
        if obj and obj.type == "MESH":
            obj.name = "Rigaround_Kenney_Weight_Donor"
            obj.hide_viewport = True
            obj.hide_render = True
            return obj
    raise RuntimeError("Could not find Kenney mesh to use as weight-transfer donor")


def transfer_weights(target: bpy.types.Object, donor: bpy.types.Object) -> None:
    target.vertex_groups.clear()
    for group in donor.vertex_groups:
        target.vertex_groups.new(name=group.name)

    modifier = target.modifiers.new("Rigaround_Transferred_Weights", "DATA_TRANSFER")
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


def bind_to_armature(collection: bpy.types.Collection, donor: bpy.types.Object, armature: bpy.types.Object) -> None:
    for obj in [item for item in collection.objects if item.type == "MESH"]:
        transfer_weights(obj, donor)
        armature_modifier = obj.modifiers.new("Rigaround_Armature", "ARMATURE")
        armature_modifier.object = armature
        obj.parent = armature
        obj.show_in_front = False
        for material in obj.data.materials:
            material.diffuse_color = (0.68, 0.62, 0.55, 1.0)


def preserve_animation_setup(armature: bpy.types.Object) -> None:
    idle = bpy.data.actions.get("Kenney_Idle")
    if idle:
        armature.animation_data_create()
        armature.animation_data.action = idle

    armature.data.display_type = "STICK"
    armature.show_in_front = False


def main() -> None:
    armature = bpy.data.objects.get("Rigaround_Male_Root")
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Could not find Rigaround_Male_Root armature")

    remove_previous_mannequin()
    hide_scene_level_detail_meshes()
    donor = find_weight_donor()
    collection = append_mannequin_collection()
    align_to_rig(collection)
    bind_to_armature(collection, donor, armature)
    preserve_animation_setup(armature)

    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print(f"Merged high-resolution mannequin with rig: {RIGAROUND}")
    for obj in collection.objects:
        if obj.type == "MESH":
            print(obj.name, len(obj.data.vertices), len(obj.vertex_groups), [m.type for m in obj.modifiers])


if __name__ == "__main__":
    main()
