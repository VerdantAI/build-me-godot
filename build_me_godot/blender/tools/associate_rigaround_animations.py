from __future__ import annotations

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
RIGAROUND = ROOT / "Rigaround.blend"

ANIMATIONS = (
    ("Idle", "Kenney_Idle"),
    ("Run", "Kenney_Run"),
    ("Jump", "Kenney_Jump"),
)


def clear_existing_tracks(armature: bpy.types.Object) -> None:
    animation_data = armature.animation_data_create()
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)


def add_animation_tracks(armature: bpy.types.Object) -> None:
    animation_data = armature.animation_data_create()

    for index, (label, action_name) in enumerate(ANIMATIONS):
        action = bpy.data.actions.get(action_name)
        if action is None:
            raise RuntimeError(f"Missing action: {action_name}")

        action.use_fake_user = True
        track = animation_data.nla_tracks.new()
        track.name = f"Rigaround {label}"
        strip = track.strips.new(name=label, start=1, action=action)
        strip.name = label
        strip.action_frame_start = action.frame_range[0]
        strip.action_frame_end = action.frame_range[1]
        strip.frame_start = 1
        strip.frame_end = 1 + (action.frame_range[1] - action.frame_range[0])
        track.mute = index != 0
        track.is_solo = False

    animation_data.action = bpy.data.actions["Kenney_Idle"]


def add_pose_markers() -> None:
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 33
    scene.frame_set(1)


def main() -> None:
    armature = bpy.data.objects.get("Rigaround_Male_Root")
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Could not find Rigaround_Male_Root armature")

    clear_existing_tracks(armature)
    add_animation_tracks(armature)
    add_pose_markers()
    bpy.ops.wm.save_as_mainfile(filepath=str(RIGAROUND))
    print(f"Associated animations with {armature.name}")
    for track in armature.animation_data.nla_tracks:
        strips = ", ".join(f"{strip.name}:{strip.action.name}" for strip in track.strips)
        state = "muted" if track.mute else "active"
        print(f"{track.name} ({state}) -> {strips}")


if __name__ == "__main__":
    main()
