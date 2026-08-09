# SPDX-License-Identifier: MIT

import math

import bpy

mesh = next(obj for obj in bpy.data.objects if "RetopoProxy" in obj.name)
rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
for vertex in mesh.data.vertices:
    if len(vertex.groups) > 4:
        raise RuntimeError(f"Vertex {vertex.index} has {len(vertex.groups)} influences")
    total = sum(group.weight for group in vertex.groups)
    if vertex.groups and not 0.999 <= total <= 1.001:
        raise RuntimeError(f"Vertex {vertex.index} weight sum is {total}")
depsgraph = bpy.context.evaluated_depsgraph_get()
rest_mesh = mesh.evaluated_get(depsgraph).to_mesh()
rest = [tuple(vertex.co) for vertex in rest_mesh.vertices]
mesh.evaluated_get(depsgraph).to_mesh_clear()
for name, angle in (("DEF-forearm.L", 0.7), ("DEF-forearm.R", -0.7), ("DEF-shin.L", -0.6), ("DEF-shin.R", -0.6)):
    bone = rig.pose.bones[name]
    bone.rotation_mode = "XYZ"
    bone.rotation_euler.y = angle
bpy.context.view_layer.update()
posed_mesh = mesh.evaluated_get(depsgraph).to_mesh()
posed = [tuple(vertex.co) for vertex in posed_mesh.vertices]
mesh.evaluated_get(depsgraph).to_mesh_clear()
if not all(math.isfinite(value) for point in posed for value in point):
    raise RuntimeError("Non-finite deformed vertex")
changed = sum(any(abs(a - b) > 1e-5 for a, b in zip(before, after)) for before, after in zip(rest, posed))
if changed < 100:
    raise RuntimeError(f"Only {changed} vertices responded to validation pose")
print(f"deformation validation: changed_vertices={changed} max_influences=4 normalized=true")
