from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "downloads" / "quaternius_ik_rigged" / "quaternius_ik_rigged_with_animations" / "addons" / "quaternius_ik_rigged"
GODOT_UE = SOURCE / "Godot - UE"
LIBRARY = ROOT / "assets" / "library"
ASSET_BLEND = LIBRARY / "quaternius_humanoid_bases_with_animations.blend"
LICENSE_NOTE = LIBRARY / "quaternius_humanoid_bases_with_animations_LICENSE.txt"

CORE_TRACKS = (
    "A_TPose",
    "Idle_Loop",
    "Walk_Loop",
    "Jog_Fwd_Loop",
    "Sprint_Loop",
    "Jump_Start",
    "Jump_Loop",
    "Jump_Land",
)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def ensure_texture_aliases() -> None:
    # The glTF references a few Godot-import-style *_png names that are absent in
    # the archive. Blender imports cleanly once those aliases exist.
    aliases = {
        "T_Eye_Normal_png.png": "T_Eye_Normal.png",
        "T_Hair_1_Normal_png.png": "T_Hair_1_Normal.png",
        "T_Hair_2_Normal_png.png": "T_Hair_2_Normal.png",
    }
    for alias, source in aliases.items():
        alias_path = GODOT_UE / alias
        source_path = GODOT_UE / source
        if source_path.exists() and not alias_path.exists():
            alias_path.write_bytes(source_path.read_bytes())


def mark_asset(id_block, description: str, tags: tuple[str, ...]) -> None:
    if not getattr(id_block, "asset_data", None):
        id_block.asset_mark()
    id_block.asset_data.description = description
    existing = {tag.name for tag in id_block.asset_data.tags}
    for tag in tags:
        if tag not in existing:
            id_block.asset_data.tags.new(tag)


def import_character(gltf_name: str, prefix: str, collection_name: str) -> tuple[bpy.types.Collection, bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(GODOT_UE / gltf_name))
    imported = [obj for obj in bpy.data.objects if obj not in before]

    collection = bpy.data.collections.new(collection_name)
    bpy.context.scene.collection.children.link(collection)

    armature = next(obj for obj in imported if obj.type == "ARMATURE")
    armature.name = f"{prefix}_Rig"
    armature.data.name = f"{prefix}_Armature"
    armature.data.display_type = "STICK"
    armature.show_in_front = False

    for obj in imported:
        for source_collection in list(obj.users_collection):
            source_collection.objects.unlink(obj)
        collection.objects.link(obj)
        if obj.type == "MESH" and obj.name == "Icosphere":
            bpy.data.objects.remove(obj, do_unlink=True)
            continue
        if obj.type == "MESH":
            obj.name = f"{prefix}_{obj.name}"
            obj.data.name = obj.name
            for modifier in obj.modifiers:
                if modifier.type == "ARMATURE":
                    modifier.object = armature
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.object.shade_smooth()
            obj.select_set(False)

    return collection, armature


def import_animation_library() -> None:
    before_objects = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / "UAL1_Standard.glb"))
    for obj in [item for item in bpy.data.objects if item not in before_objects]:
        bpy.data.objects.remove(obj, do_unlink=True)

    for action in bpy.data.actions:
        action.use_fake_user = True
        mark_asset(
            action,
            f"Quaternius Universal Animation Library action: {action.name}.",
            ("CC0", "animation", "humanoid", "Quaternius"),
        )


def add_nla_tracks(armature: bpy.types.Object) -> None:
    animation_data = armature.animation_data_create()
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)

    for index, action_name in enumerate(CORE_TRACKS):
        action = bpy.data.actions.get(action_name)
        if not action:
            continue
        track = animation_data.nla_tracks.new()
        track.name = action_name
        strip = track.strips.new(action_name, 1, action)
        strip.action_frame_start = action.frame_range[0]
        strip.action_frame_end = action.frame_range[1]
        strip.frame_start = 1
        strip.frame_end = 1 + (action.frame_range[1] - action.frame_range[0])
        track.mute = index != 1

    idle = bpy.data.actions.get("Idle_Loop")
    if idle:
        animation_data.action = idle
        if idle.slots:
            animation_data.action_slot = idle.slots[0]


def mark_character_assets(collection: bpy.types.Collection, armature: bpy.types.Object, label: str) -> None:
    mark_asset(
        collection,
        f"CC0 Quaternius {label} humanoid base with correctly attached rig and reusable animation tracks.",
        ("CC0", "rigged", "humanoid", label.lower(), "Quaternius"),
    )
    mark_asset(
        armature,
        f"CC0 Quaternius {label} humanoid rig compatible with the Universal Animation Library.",
        ("CC0", "rig", "humanoid", label.lower(), "Quaternius"),
    )
    for obj in collection.objects:
        if obj.type == "MESH":
            mark_asset(
                obj,
                f"CC0 Quaternius {label} skinned mesh bound to {armature.name}.",
                ("CC0", "mesh", "skinned", label.lower(), "Quaternius"),
            )


def add_license_note() -> None:
    note = (
        "Quaternius Humanoid Bases with Animations\n\n"
        "Source: Quaternius_IK_Rigged by JamesonBradfield, built on Quaternius CC0 Superhero models and animations.\n"
        "Godot Asset Library: https://godotengine.org/asset-library/asset/5235\n"
        "Repository: https://codeberg.org/jamesonBradfield/Quaternius_IK_Rigged_with_animations\n"
        "License: CC0 1.0 Universal for the asset contents per README/LICENSE.\n"
    )
    LICENSE_NOTE.write_text(note, encoding="utf-8")
    text = bpy.data.texts.new("Quaternius Humanoid Bases Licenses")
    text.write(note)


def main() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    ensure_texture_aliases()
    clear_scene()

    male_collection, male_rig = import_character("Superhero_Male_FullBody.gltf", "QTR_Male", "Quaternius Male Humanoid Base")
    female_collection, female_rig = import_character("Superhero_Female_FullBody.gltf", "QTR_Female", "Quaternius Female Humanoid Base")
    import_animation_library()

    for collection, rig, label in (
        (male_collection, male_rig, "Male"),
        (female_collection, female_rig, "Female"),
    ):
        add_nla_tracks(rig)
        mark_character_assets(collection, rig, label)

    add_license_note()
    bpy.ops.wm.save_as_mainfile(filepath=str(ASSET_BLEND))
    print(f"Saved Quaternius humanoid base assets: {ASSET_BLEND}")
    print(f"Actions: {len(bpy.data.actions)}")


if __name__ == "__main__":
    main()
