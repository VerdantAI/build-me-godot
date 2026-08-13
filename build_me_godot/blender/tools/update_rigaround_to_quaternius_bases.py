from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"
ASSET_BLEND = ROOT / "assets" / "library" / "quaternius_humanoid_bases_with_animations.blend"

COLLECTIONS = (
    "Quaternius Male Humanoid Base",
    "Quaternius Female Humanoid Base",
)


def clear_old_character_content() -> None:
    keep = {"Camera", "Light"}
    for obj in list(bpy.data.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)

    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)

    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)


def append_quaternius_assets() -> None:
    with bpy.data.libraries.load(str(ASSET_BLEND), link=False) as (source, target):
        target.collections = [name for name in COLLECTIONS if name in source.collections]
        target.actions = list(source.actions)

    linked_names = {collection.name for collection in bpy.context.scene.collection.children}
    for collection in target_collections():
        if collection.name not in linked_names:
            try:
                bpy.context.scene.collection.children.link(collection)
            except RuntimeError:
                pass


def target_collections() -> list[bpy.types.Collection]:
    return [bpy.data.collections[name] for name in COLLECTIONS if name in bpy.data.collections]


def place_characters() -> None:
    placements = {
        "QTR_Male": -1.4,
        "QTR_Female": 1.4,
    }
    for prefix, x in placements.items():
        rig = bpy.data.objects.get(f"{prefix}_Rig")
        if rig:
            rig.location.x = x
            rig.location.y = 0.0
            rig.location.z = 0.0
            rig.data.display_type = "STICK"
            rig.show_in_front = False
            rig.animation_data_create()
            idle = bpy.data.actions.get("Idle_Loop")
            if idle:
                rig.animation_data.action = idle
                if idle.slots:
                    rig.animation_data.action_slot = idle.slots[0]

    for obj in list(bpy.data.objects):
        if obj.name in {"QTR_Male_Icosphere", "QTR_Female_Icosphere"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def configure_scene() -> None:
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 60
    scene.frame_set(1)

    camera = bpy.data.objects.get("Camera")
    if camera:
        camera.location = (0.0, -7.5, 2.3)
        camera.rotation_euler = (1.28, 0.0, 0.0)
        camera.data.lens = 35

    light = bpy.data.objects.get("Light")
    if light:
        light.location = (0.0, -4.0, 5.0)
        light.data.energy = 900


def mark_scene_assets() -> None:
    for action in bpy.data.actions:
        action.use_fake_user = True


def main() -> None:
    clear_old_character_content()
    append_quaternius_assets()
    place_characters()
    configure_scene()
    mark_scene_assets()
    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print(f"Updated {RIGAROUND} with Quaternius humanoid bases")
    print("Objects:", [obj.name for obj in bpy.context.scene.objects])
    print("Actions:", len(bpy.data.actions))


if __name__ == "__main__":
    main()
