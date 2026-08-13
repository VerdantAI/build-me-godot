from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"


HIGHRES_NAMES = (
    "Rigaround_HighRes_mannequin_body",
    "Rigaround_HighRes_mannequin_joints",
)


def clear_parent_keep_transform(obj: bpy.types.Object) -> None:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = world


def ensure_armature_modifier(obj: bpy.types.Object, armature: bpy.types.Object) -> None:
    modifiers = [modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"]
    if modifiers:
        modifier = modifiers[0]
        modifier.name = "Rigaround_Armature"
        modifier.object = armature
        for extra in modifiers[1:]:
            obj.modifiers.remove(extra)
    else:
        modifier = obj.modifiers.new("Rigaround_Armature", "ARMATURE")
        modifier.object = armature


def cleanup_nonessential_display_objects() -> None:
    for name in ("BurningBarb_mannequin_center",):
        obj = bpy.data.objects.get(name)
        if obj:
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in bpy.data.objects:
        if obj.name.startswith("Rigaround_Realistic_"):
            bpy.data.objects.remove(obj, do_unlink=True)


def configure_armature_display(armature: bpy.types.Object) -> None:
    armature.data.display_type = "STICK"
    armature.data.show_names = False
    armature.show_in_front = False
    armature.show_name = False
    armature.show_axis = False
    armature.hide_select = False

    for bone in armature.data.bones:
        bone.hide = (
            bone.name.endswith("_end")
            or "Ctrl" in bone.name
            or "IK" in bone.name
            or "Roll" in bone.name
        )


def main() -> None:
    armature = bpy.data.objects.get("Rigaround_Male_Root")
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Could not find Rigaround_Male_Root armature")

    cleanup_nonessential_display_objects()
    configure_armature_display(armature)

    for name in HIGHRES_NAMES:
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Could not find high-res mesh: {name}")
        clear_parent_keep_transform(obj)
        ensure_armature_modifier(obj, armature)
        obj.show_name = False
        obj.show_wire = False
        obj.hide_select = False

    donor = bpy.data.objects.get("Rigaround_Kenney_Weight_Donor")
    if donor:
        donor.hide_viewport = True
        donor.hide_render = True
        donor.hide_select = True

    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print("Cleaned high-res mannequin/rig alignment display")
    for name in HIGHRES_NAMES:
        obj = bpy.data.objects[name]
        print(name, "parent", obj.parent.name if obj.parent else None, "modifiers", [(m.name, m.type, m.object.name if getattr(m, "object", None) else None) for m in obj.modifiers])


if __name__ == "__main__":
    main()
