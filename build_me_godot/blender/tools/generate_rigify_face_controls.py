"""Generate Rigify controls for prepared duplicate mannequin experiments."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


SEXES = ("Female", "Male")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output")
    destination.add_argument("--in-place", action="store_true")
    parser.add_argument(
        "--replace-generated",
        action="store_true",
        help="Remove only previously generated Build Me Godot Rigify controls and widgets.",
    )
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def remove_generated(sex: str) -> None:
    rig = bpy.data.objects.get(f"RigifyFaceControls_{sex}")
    if rig is not None:
        if rig.get("build_me_godot_experiment") != "rigify_face_controls_v1":
            raise SystemExit(f"Refusing to remove untagged object: {rig.name}")
        bpy.data.objects.remove(rig, do_unlink=True)
    widgets = bpy.data.collections.get(f"WGTS_RigifyFaceMetarig_{sex}")
    if widgets is not None:
        for obj in list(widgets.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(widgets)


def generate(sex: str, replace_generated: bool) -> bpy.types.Object:
    metarig = bpy.data.objects.get(f"RigifyFaceMetarig_{sex}")
    if metarig is None:
        raise SystemExit(f"Missing prepared metarig: RigifyFaceMetarig_{sex}")
    existing = bpy.data.objects.get(f"RigifyFaceControls_{sex}")
    if existing is not None:
        if not replace_generated:
            raise SystemExit(f"Refusing to replace generated controls: {existing.name}")
        remove_generated(sex)

    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    metarig.hide_set(False)
    metarig.hide_viewport = False
    metarig.select_set(True)
    bpy.context.view_layer.objects.active = metarig
    before = set(bpy.data.objects)
    result = bpy.ops.pose.rigify_generate()
    if "FINISHED" not in result:
        raise SystemExit(f"Rigify generation failed for {sex}: {result}")
    created = [obj for obj in bpy.data.objects if obj not in before and obj.type == "ARMATURE"]
    rig = bpy.context.object if bpy.context.object and bpy.context.object.type == "ARMATURE" else None
    if rig is None or rig == metarig:
        rig = next(iter(created), None)
    if rig is None:
        raise SystemExit(f"Rigify did not create a control armature for {sex}")
    rig.name = f"RigifyFaceControls_{sex}"
    # Rigify 5.x generates at identity even when the metarig object is placed
    # and uniformly scaled. Carry the prepared baseline transform explicitly.
    rig.matrix_world = metarig.matrix_world.copy()
    rig.location = metarig.location.copy()
    rig.rotation_euler = metarig.rotation_euler.copy()
    rig.scale = metarig.scale.copy()
    rig["build_me_godot_experiment"] = "rigify_face_controls_v1"
    rig["source_metarig"] = metarig.name
    rig["face_landmark_fit_required"] = True
    rig["weights_required"] = True
    return rig


def main() -> None:
    options = arguments()
    output = Path(options.output).expanduser().resolve() if options.output else Path(bpy.data.filepath).resolve()
    if options.output and output.exists():
        raise SystemExit(f"Refusing to overwrite output: {output}")
    result = bpy.ops.preferences.addon_enable(module="rigify")
    if "FINISHED" not in result:
        raise SystemExit("Blender Rigify could not be enabled for control-rig generation.")
    rigs = [generate(sex, options.replace_generated) for sex in SEXES]
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    print(f"Generated Rigify controls: {', '.join(rig.name for rig in rigs)}")
    print(f"Saved: {output}")


if __name__ == "__main__":
    main()
