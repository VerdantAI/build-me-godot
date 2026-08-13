from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"
LIBRARY = ROOT / "assets" / "library"
ASSET_BLEND = LIBRARY / "rigaround_highres_animated_mannequin.blend"
LICENSE_NOTE = LIBRARY / "rigaround_highres_animated_mannequin_LICENSES.txt"


KEEP_OBJECTS = {
    "Rigaround_HighRes_mannequin_body",
    "Rigaround_HighRes_mannequin_joints",
    "Rigaround_Kenney_Weight_Donor",
    "Rigaround_Male_Root",
}

KEEP_ACTIONS = {
    "Kenney_Idle",
    "Kenney_Run",
    "Kenney_Jump",
}


def mark_asset(id_block, description: str, tags: tuple[str, ...]) -> None:
    if not getattr(id_block, "asset_data", None):
        id_block.asset_mark()
    id_block.asset_data.description = description
    existing = {tag.name for tag in id_block.asset_data.tags}
    for tag in tags:
        if tag not in existing:
            id_block.asset_data.tags.new(tag)


def purge_scene() -> None:
    for obj in list(bpy.data.objects):
        if obj.name not in KEEP_OBJECTS:
            bpy.data.objects.remove(obj, do_unlink=True)

    for action in list(bpy.data.actions):
        if action.name not in KEEP_ACTIONS:
            bpy.data.actions.remove(action)

    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def build_collection() -> bpy.types.Collection:
    collection = bpy.data.collections.new("Rigaround HighRes Animated Mannequin")
    bpy.context.scene.collection.children.link(collection)

    for name in KEEP_OBJECTS:
        obj = bpy.data.objects.get(name)
        if obj is not None and obj.name not in collection.objects:
            collection.objects.link(obj)

    return collection


def mark_assets(collection: bpy.types.Collection) -> None:
    mark_asset(
        collection,
        "High-resolution CC0 mannequin bound to the Kenney animated character rig with idle, run, and jump actions.",
        ("CC0", "rigged", "animated", "mannequin", "character"),
    )

    armature = bpy.data.objects.get("Rigaround_Male_Root")
    if armature:
        mark_asset(
            armature,
            "Animation armature for the Rigaround high-resolution mannequin.",
            ("rig", "armature", "animated", "character"),
        )

    for name in ("Rigaround_HighRes_mannequin_body", "Rigaround_HighRes_mannequin_joints"):
        obj = bpy.data.objects.get(name)
        if obj:
            mark_asset(
                obj,
                "High-resolution mannequin mesh bound to Rigaround_Male_Root.",
                ("CC0", "mesh", "skinned", "mannequin"),
            )

    donor = bpy.data.objects.get("Rigaround_Kenney_Weight_Donor")
    if donor:
        donor.hide_viewport = True
        donor.hide_render = True

    for action_name in KEEP_ACTIONS:
        action = bpy.data.actions.get(action_name)
        if action:
            action.use_fake_user = True
            mark_asset(
                action,
                f"Rigaround reusable character animation: {action_name.removeprefix('Kenney_').lower()}.",
                ("animation", "character", "Kenney"),
            )


def write_license_note() -> None:
    note = (
        "Rigaround HighRes Animated Mannequin\n\n"
        "Mesh source: Prototyping Mannequin by burning_barb\n"
        "Source URL: https://burning-barb.itch.io/mannequin\n"
        "Mesh license: Creative Commons Zero v1.0 Universal (CC0)\n\n"
        "Rig and animations source: Kenney Animated Characters 1\n"
        "Source URL: https://opengameart.org/content/animated-characters-1\n"
        "Rig/animation license: CC0 as distributed with the downloaded pack.\n"
    )
    LICENSE_NOTE.write_text(note, encoding="utf-8")
    text = bpy.data.texts.new("Rigaround HighRes Animated Mannequin Licenses")
    text.write(note)


def main() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    purge_scene()
    collection = build_collection()
    mark_assets(collection)
    write_license_note()
    bpy.ops.wm.save_as_mainfile(filepath=str(ASSET_BLEND))
    print(f"Saved rigged high-res mannequin asset: {ASSET_BLEND}")


if __name__ == "__main__":
    main()
