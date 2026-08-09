#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
import json

import bpy


OPERATORS = [
    "import_scene.gltf",
    "object.parent_set",
    "object.modifier_apply",
    "object.vertex_group_limit_total",
    "object.vertex_group_normalize_all",
    "export_scene.gltf",
    "wm.save_as_mainfile",
]


def operator_exists(path):
    owner, name = path.split(".", 1)
    return hasattr(getattr(bpy.ops, owner), name)


print("BUILD_ME_GODOT_PROBE=" + json.dumps({
    "blender_version": list(bpy.app.version),
    "operators": {name: operator_exists(name) for name in OPERATORS},
}, sort_keys=True))
