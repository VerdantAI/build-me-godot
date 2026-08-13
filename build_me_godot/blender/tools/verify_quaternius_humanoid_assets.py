from __future__ import annotations

import bpy


RIGS = ("QTR_Male_Rig", "QTR_Female_Rig")
MESHES = {
    "QTR_Male_Rig": "QTR_Male_SuperHero_Male",
    "QTR_Female_Rig": "QTR_Female_Superhero_Female",
}
TEST_ACTIONS = ("Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Jump_Start")


def evaluated_vertices(obj: bpy.types.Object) -> list[tuple[float, float, float]]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    depsgraph.update()
    evaluated = obj.evaluated_get(depsgraph)
    return [tuple(evaluated.matrix_world @ vertex.co.copy()) for vertex in evaluated.data.vertices]


def max_delta(first: list[tuple[float, float, float]], second: list[tuple[float, float, float]]) -> float:
    return max(
        sum((b - a) ** 2 for a, b in zip(start, end)) ** 0.5
        for start, end in zip(first, second)
    )


def main() -> None:
    scene = bpy.context.scene
    print("ASSET_COUNT", sum(1 for blocks in (bpy.data.collections, bpy.data.objects, bpy.data.actions) for item in blocks if getattr(item, "asset_data", None)))
    print("ACTIONS", len(bpy.data.actions))

    for rig_name in RIGS:
        rig = bpy.data.objects[rig_name]
        mesh = bpy.data.objects[MESHES[rig_name]]
        print(rig_name, "bones", len(rig.data.bones), "mesh_verts", len(mesh.data.vertices), "groups", len(mesh.vertex_groups))
        animation_data = rig.animation_data_create()
        original_action = animation_data.action
        for track in animation_data.nla_tracks:
            track.mute = True
        for action_name in TEST_ACTIONS:
            action = bpy.data.actions[action_name]
            animation_data.action = action
            if action.slots:
                animation_data.action_slot = action.slots[0]
            start = int(action.frame_range[0])
            midpoint = max(start + 1, int((action.frame_range[0] + action.frame_range[1]) / 2))
            scene.frame_set(start)
            first = evaluated_vertices(mesh)
            scene.frame_set(midpoint)
            second = evaluated_vertices(mesh)
            print(rig_name, action_name, f"{max_delta(first, second):.6f}")
        animation_data.action = original_action


if __name__ == "__main__":
    main()
