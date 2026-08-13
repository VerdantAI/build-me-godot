from __future__ import annotations

import shutil
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "downloads" / "kenney_animated-characters-1"
LIBRARY = ROOT / "assets" / "library"
BLEND_PATH = LIBRARY / "kenney_animated_characters_1.blend"
TEXTURE_DIR = LIBRARY / "kenney_animated_characters_1_textures"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    for datablock_collection in (
        bpy.data.meshes,
        bpy.data.armatures,
        bpy.data.actions,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.collections,
    ):
        for datablock in list(datablock_collection):
            if datablock.users == 0:
                datablock_collection.remove(datablock)


def mark_asset(id_block, description: str, tags: tuple[str, ...]) -> None:
    id_block.asset_mark()
    id_block.asset_data.description = description
    for tag in tags:
        id_block.asset_data.tags.new(tag)


def import_fbx(path: Path) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path))
    return [obj for obj in bpy.data.objects if obj not in before]


def copy_textures() -> list[Path]:
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    copied = []
    for path in sorted((SOURCE / "Skins").glob("*.png")):
        target = TEXTURE_DIR / path.name
        shutil.copy2(path, target)
        copied.append(target)
    return copied


def load_skin_images(paths: list[Path]) -> None:
    for path in paths:
        image = bpy.data.images.load(str(path), check_existing=True)
        mark_asset(
            image,
            f"Kenney Animated Characters 1 skin texture: {path.stem}",
            ("CC0", "Kenney", "character", "skin"),
        )


def import_character() -> bpy.types.Collection:
    imported = import_fbx(SOURCE / "Model" / "characterMedium.fbx")
    collection = bpy.data.collections.new("Kenney Animated Characters 1")
    bpy.context.scene.collection.children.link(collection)

    for obj in imported:
        for source_collection in obj.users_collection:
            source_collection.objects.unlink(obj)
        collection.objects.link(obj)
        obj.name = f"Kenney_{obj.name}"
        mark_asset(
            obj,
            "CC0 rigged low-poly character from Kenney Animated Characters 1.",
            ("CC0", "Kenney", "rigged", "character"),
        )

    mark_asset(
        collection,
        "CC0 rigged low-poly character collection from Kenney Animated Characters 1.",
        ("CC0", "Kenney", "rigged", "character"),
    )

    return collection


def import_actions() -> None:
    animation_files = {
        "Kenney_Idle": SOURCE / "Animations" / "idle.fbx",
        "Kenney_Jump": SOURCE / "Animations" / "jump.fbx",
        "Kenney_Run": SOURCE / "Animations" / "run.fbx",
    }

    for action_name, path in animation_files.items():
        before_actions = set(bpy.data.actions)
        imported = import_fbx(path)
        new_actions = [action for action in bpy.data.actions if action not in before_actions]

        for obj in imported:
            bpy.data.objects.remove(obj, do_unlink=True)

        if not new_actions:
            continue

        action = max(new_actions, key=lambda item: item.frame_range[1] - item.frame_range[0])
        action.name = action_name
        mark_asset(
            action,
            f"CC0 {action_name.removeprefix('Kenney_').lower()} animation from Kenney Animated Characters 1.",
            ("CC0", "Kenney", "animation", "character"),
        )

        for extra_action in new_actions:
            if extra_action != action:
                bpy.data.actions.remove(extra_action)


def add_license_text() -> None:
    license_text = (SOURCE / "License.txt").read_text(encoding="utf-8", errors="replace")
    text = bpy.data.texts.new("Kenney Animated Characters 1 License")
    text.write(license_text)


def register_asset_library() -> None:
    prefs = bpy.context.preferences
    asset_libraries = prefs.filepaths.asset_libraries
    library_name = "Blender Messarounds Assets"
    library_path = str(LIBRARY)

    existing = next((lib for lib in asset_libraries if lib.name == library_name), None)
    if existing is None:
        bpy.ops.preferences.asset_library_add(directory=library_path)
        existing = asset_libraries[-1]
        existing.name = library_name
    else:
        existing.path = library_path

    bpy.ops.wm.save_userpref()


def main() -> None:
    LIBRARY.mkdir(parents=True, exist_ok=True)
    clear_scene()
    texture_paths = copy_textures()
    load_skin_images(texture_paths)
    import_character()
    import_actions()
    add_license_text()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    register_asset_library()
    print(f"Saved asset library blend: {BLEND_PATH}")
    print(f"Registered Blender asset library: {LIBRARY}")


if __name__ == "__main__":
    main()
