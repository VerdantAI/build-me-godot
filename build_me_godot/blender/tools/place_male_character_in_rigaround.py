from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"
ASSET_BLEND = ROOT / "assets" / "library" / "kenney_animated_characters_1.blend"
MALE_TEXTURE = ROOT / "assets" / "library" / "kenney_animated_characters_1_textures" / "survivorMaleB.png"


def remove_existing_character() -> None:
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith("Rigaround_Male_") or obj.name.startswith("Kenney_"):
            bpy.data.objects.remove(obj, do_unlink=True)

    for collection in list(bpy.data.collections):
        if collection.name.startswith("Rigaround Male Character") or collection.name.startswith("Kenney Animated Characters 1"):
            bpy.data.collections.remove(collection)


def append_character_collection() -> bpy.types.Collection:
    with bpy.data.libraries.load(str(ASSET_BLEND), link=False) as (source, target):
        target.collections = ["Kenney Animated Characters 1"]
        target.actions = [name for name in source.actions if name in {"Kenney_Idle", "Kenney_Jump", "Kenney_Run"}]

    collection = bpy.data.collections["Kenney Animated Characters 1"]
    collection.name = "Rigaround Male Character"
    bpy.context.scene.collection.children.link(collection)
    return collection


def configure_character(collection: bpy.types.Collection) -> None:
    image = bpy.data.images.load(str(MALE_TEXTURE), check_existing=True)

    for obj in collection.objects:
        obj.name = f"Rigaround_Male_{obj.name.removeprefix('Kenney_')}"
        obj.location = (0.0, 0.0, 0.0)
        obj.rotation_euler = (0.0, 0.0, 0.0)
        obj.scale = (1.0, 1.0, 1.0)

        if obj.type == "MESH":
            for material in obj.data.materials:
                material.name = "Rigaround_Male_Survivor_Skin"
                material.use_nodes = True
                nodes = material.node_tree.nodes
                links = material.node_tree.links
                principled = nodes.get("Principled BSDF")
                texture = nodes.new(type="ShaderNodeTexImage")
                texture.name = "Survivor Male B Texture"
                texture.image = image
                if principled and "Base Color" in principled.inputs:
                    links.new(texture.outputs["Color"], principled.inputs["Base Color"])

        if obj.type == "ARMATURE":
            obj.show_in_front = True
            obj.animation_data_create()
            obj.animation_data.action = bpy.data.actions.get("Kenney_Idle")


def frame_camera() -> None:
    camera = bpy.data.objects.get("Camera")
    if camera:
        camera.location = (3.0, -5.0, 2.4)
        camera.rotation_euler = (1.2, 0.0, 0.52)
        camera.data.lens = 45

    light = bpy.data.objects.get("Light")
    if light:
        light.location = (2.5, -3.0, 4.0)
        light.data.energy = 600


def main() -> None:
    remove_existing_character()
    collection = append_character_collection()
    configure_character(collection)
    frame_camera()
    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print(f"Placed rigged male character in {RIGAROUND}")


if __name__ == "__main__":
    main()
