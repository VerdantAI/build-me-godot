from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE_BLEND = ROOT / "assets" / "downloads" / "burning_barb_mannequin.blend"
LIBRARY = ROOT / "assets" / "library"
ASSET_BLEND = LIBRARY / "burning_barb_prototyping_mannequin.blend"
LICENSE_TEXT = LIBRARY / "burning_barb_prototyping_mannequin_LICENSE.txt"


def mark_asset(id_block, description: str, tags: tuple[str, ...]) -> None:
    id_block.asset_mark()
    id_block.asset_data.description = description
    for tag in tags:
        id_block.asset_data.tags.new(tag)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def append_source_collection() -> bpy.types.Collection:
    with bpy.data.libraries.load(str(SOURCE_BLEND), link=False) as (source, target):
        target.collections = ["mannequin_combined"]

    collection = bpy.data.collections["mannequin_combined"]
    collection.name = "Burning Barb Prototyping Mannequin"
    bpy.context.scene.collection.children.link(collection)
    return collection


def prepare_meshes(collection: bpy.types.Collection) -> None:
    for obj in collection.objects:
        obj.name = f"BurningBarb_{obj.name}"
        if obj.type != "MESH":
            continue

        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            if modifier.type == "MIRROR":
                bpy.ops.object.modifier_apply(modifier=modifier.name)

        obj.data.name = obj.name
        bpy.ops.object.shade_smooth()
        mark_asset(
            obj,
            "CC0 higher-resolution mannequin mesh from burning_barb's Prototyping Mannequin.",
            ("CC0", "mannequin", "male", "mesh"),
        )

    mark_asset(
        collection,
        "CC0 higher-resolution mannequin collection from burning_barb's Prototyping Mannequin.",
        ("CC0", "mannequin", "male", "mesh"),
    )


def add_license_note() -> None:
    note = (
        "Prototyping Mannequin by burning_barb\n"
        "Source: https://burning-barb.itch.io/mannequin\n"
        "License: Creative Commons Zero v1.0 Universal (CC0)\n"
        "Downloaded for local Blender asset-library experimentation.\n"
    )
    LICENSE_TEXT.write_text(note, encoding="utf-8")
    text = bpy.data.texts.new("Burning Barb Prototyping Mannequin License")
    text.write(note)


def main() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    clear_scene()
    collection = append_source_collection()
    prepare_meshes(collection)
    add_license_note()
    bpy.ops.wm.save_as_mainfile(filepath=str(ASSET_BLEND))
    print(f"Saved mannequin asset library blend: {ASSET_BLEND}")


if __name__ == "__main__":
    main()
