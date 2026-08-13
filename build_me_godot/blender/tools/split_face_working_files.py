"""Create one-character facial-authoring files from field_engineers.blend."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import bpy


SEX_CONFIG = {
    "female": {
        "title": "Female",
        "experiment": "Rigify Face Experiment - Female",
        "source_collections": ("Quaternius Female Humanoid Base", "Quaternius Male Humanoid Base"),
        "other_experiment": "Rigify Face Experiment - Male",
    },
    "male": {
        "title": "Male",
        "experiment": "Rigify Face Experiment - Male",
        "source_collections": ("Quaternius Female Humanoid Base", "Quaternius Male Humanoid Base"),
        "other_experiment": "Rigify Face Experiment - Female",
    },
}


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sex", required=True, choices=sorted(SEX_CONFIG))
    parser.add_argument("--output", required=True)
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def remove_collection(name: str) -> None:
    collection = bpy.data.collections.get(name)
    if collection is None:
        return
    for child in list(collection.children):
        remove_collection(child.name)
    for obj in list(collection.objects):
        if len(obj.users_collection) == 1:
            bpy.data.objects.remove(obj, do_unlink=True)
        else:
            collection.objects.unlink(obj)
    bpy.data.collections.remove(collection)


def remove_object(name: str) -> None:
    obj = bpy.data.objects.get(name)
    if obj is not None:
        bpy.data.objects.remove(obj, do_unlink=True)


def main() -> None:
    options = arguments()
    config = SEX_CONFIG[options.sex]
    title = config["title"]
    output = Path(options.output).expanduser().resolve()
    if output.exists():
        raise SystemExit(f"Refusing to overwrite working file: {output}")

    experiment = bpy.data.collections.get(config["experiment"])
    if experiment is None:
        raise SystemExit(f"Missing experiment collection: {config['experiment']}")

    for name in config["source_collections"]:
        remove_collection(name)
    remove_collection(config["other_experiment"])
    other = "Male" if title == "Female" else "Female"
    remove_object(f"RigifyFaceControls_{other}")
    remove_collection(f"WGTS_RigifyFaceMetarig_{other}")

    controls = bpy.data.objects.get(f"RigifyFaceControls_{title}")
    metarig = bpy.data.objects.get(f"RigifyFaceMetarig_{title}")
    if controls is None or metarig is None:
        raise SystemExit(f"Missing {title} Rigify authoring objects")
    if controls.name not in experiment.objects:
        experiment.objects.link(controls)
    for collection in list(controls.users_collection):
        if collection != experiment:
            collection.objects.unlink(controls)

    qtr_rigs = [
        obj for obj in experiment.objects
        if obj.type == "ARMATURE" and obj.name.startswith(f"QTR_{title}_Rig")
    ]
    if len(qtr_rigs) != 1:
        raise SystemExit(f"Expected one {title} QTR rig, found {len(qtr_rigs)}")
    qtr_rig = qtr_rigs[0]
    qtr_rig.name = f"QTR_{title}_Rig"
    qtr_rig["build_me_godot_role"] = "production_body_baseline"

    for obj in experiment.objects:
        if obj.type != "MESH":
            continue
        for modifier in obj.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = qtr_rig

    experiment.name = f"Field Engineer {title} Face Working"
    bpy.context.scene.frame_set(0)
    bpy.context.scene["build_me_godot_face_working_file"] = options.sex
    bpy.context.scene["source_file"] = "field_engineers.blend"
    bpy.context.scene["landmark_fit_required"] = True
    bpy.context.scene["facial_weights_required"] = True
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    print(f"Created {title} face working file: {output}")
    print(f"Body rig: {qtr_rig.name}; controls: {controls.name}; metarig: {metarig.name}")


if __name__ == "__main__":
    main()
