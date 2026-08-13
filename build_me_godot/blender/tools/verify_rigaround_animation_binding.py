from __future__ import annotations

import bpy


MESH_NAME = "Rigaround_HighRes_mannequin_body"
ARMATURE_NAME = "Rigaround_Male_Root"
TRACK_NAMES = ("Rigaround Idle", "Rigaround Run", "Rigaround Jump")


def evaluated_vertices_world(obj: bpy.types.Object) -> list[tuple[float, float, float]]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    evaluated = obj.evaluated_get(depsgraph)
    return [
        tuple(evaluated.matrix_world @ vertex.co.copy())
        for vertex in evaluated.data.vertices
    ]


def max_delta(first: list[tuple[float, float, float]], second: list[tuple[float, float, float]]) -> float:
    return max(
        sum((b - a) ** 2 for a, b in zip(start, end)) ** 0.5
        for start, end in zip(first, second)
    )


def main() -> None:
    scene = bpy.context.scene
    armature = bpy.data.objects[ARMATURE_NAME]
    mesh = bpy.data.objects[MESH_NAME]
    animation_data = armature.animation_data_create()

    tracks = {track.name: track for track in animation_data.nla_tracks}
    original_action = animation_data.action

    for track_name in TRACK_NAMES:
        track = tracks[track_name]
        strip = track.strips[0]
        action = strip.action
        animation_data.action = None
        for item in animation_data.nla_tracks:
            item.mute = item != track
        start, end = (int(action.frame_range[0]), int(action.frame_range[1]))
        midpoint = max(start, (start + end) // 2)
        scene.frame_set(start)
        first = evaluated_vertices_world(mesh)
        scene.frame_set(midpoint)
        second = evaluated_vertices_world(mesh)
        print(f"{track_name} / {action.name}: max mesh deformation delta {max_delta(first, second):.6f}")

    animation_data.action = original_action or bpy.data.actions["Kenney_Idle"]
    for track in animation_data.nla_tracks:
        track.mute = track.name != "Rigaround Idle"
    scene.frame_set(1)


if __name__ == "__main__":
    main()
