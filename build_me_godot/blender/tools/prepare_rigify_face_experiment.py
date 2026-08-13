"""Create a duplicate-only Rigify facial-authoring experiment."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy
import addon_utils


COLLECTIONS = {
    "female": "Quaternius Female Humanoid Base",
    "male": "Quaternius Male Humanoid Base",
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sex", required=True, choices=[*sorted(COLLECTIONS), "both"])
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output")
    destination.add_argument("--in-place", action="store_true")
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def duplicate_collection(source: bpy.types.Collection, name: str) -> bpy.types.Collection:
    target = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(target)
    copies = {}
    for source_object in source.objects:
        copy = source_object.copy()
        if source_object.data is not None:
            copy.data = source_object.data.copy()
        target.objects.link(copy)
        copies[source_object] = copy
    for source_object, copy in copies.items():
        if source_object.parent in copies:
            copy.parent = copies[source_object.parent]
        for modifier in copy.modifiers:
            modifier_target = getattr(modifier, "object", None)
            if modifier_target in copies:
                modifier.object = copies[modifier_target]
    return target


def main() -> None:
    options = arguments()
    output = Path(options.output).expanduser().resolve() if options.output else Path(bpy.data.filepath).resolve()
    if options.output and output.exists():
        raise SystemExit(f"Refusing to overwrite existing experiment: {output}")
    sexes = sorted(COLLECTIONS) if options.sex == "both" else [options.sex]
    _default, loaded = addon_utils.check("rigify")
    if not loaded and not hasattr(bpy.ops.object, "armature_human_metarig_add"):
        try:
            addon_utils.enable("rigify", default_set=False, persistent=False)
        except Exception as error:
            if not hasattr(bpy.ops.object, "armature_human_metarig_add"):
                raise SystemExit(f"Could not enable Blender Rigify: {error}") from error
    if not hasattr(bpy.ops.object, "armature_human_metarig_add"):
        raise SystemExit("Blender Rigify is not available in this Blender installation.")
    for sex in sexes:
        experiment_name = f"Rigify Face Experiment - {sex.title()}"
        if bpy.data.collections.get(experiment_name) is not None:
            raise SystemExit(f"Refusing to replace existing experiment collection: {experiment_name}")
        source = bpy.data.collections.get(COLLECTIONS[sex])
        if source is None:
            raise SystemExit(f"Missing source collection: {COLLECTIONS[sex]}")

        experiment = duplicate_collection(source, experiment_name)
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.object.armature_human_metarig_add()
        metarig = bpy.context.object
        metarig.name = f"RigifyFaceMetarig_{sex.title()}"
        for collection in list(metarig.users_collection):
            collection.objects.unlink(metarig)
        experiment.objects.link(metarig)
        metarig["build_me_godot_experiment"] = "rigify_face_v1"
        metarig["source_collection"] = source.name
        metarig["manual_fit_required"] = True

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    print(f"Prepared duplicate-only Rigify experiment for {', '.join(sexes)}: {output}")
    print("Manual face-landmark fitting is required before rig generation or weighting.")


if __name__ == "__main__":
    main()
