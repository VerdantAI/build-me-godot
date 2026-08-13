from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"


HELPER_BONE_MARKERS = (
    "Ctrl",
    "IK",
    "Roll",
    "KneeCtrl",
)


def should_hide_bone(name: str) -> bool:
    return name.endswith("_end") or any(marker in name for marker in HELPER_BONE_MARKERS)


def main() -> None:
    armature = bpy.data.objects.get("Rigaround_Male_Root")
    mesh = bpy.data.objects.get("Rigaround_Male_characterMedium")

    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Could not find Rigaround_Male_Root armature")

    armature.data.display_type = "STICK"
    armature.show_in_front = False
    armature.hide_select = False

    for bone in armature.data.bones:
        bone.hide = should_hide_bone(bone.name)

    if mesh is not None:
        bpy.ops.object.select_all(action="DESELECT")
        mesh.select_set(True)
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature

    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    visible_bones = [bone.name for bone in armature.data.bones if not bone.hide]
    hidden_bones = [bone.name for bone in armature.data.bones if bone.hide]
    print(f"Saved cleaned rig display: {RIGAROUND}")
    print(f"Visible bones: {len(visible_bones)}")
    print(f"Hidden helper/control bones: {len(hidden_bones)}")


if __name__ == "__main__":
    main()
