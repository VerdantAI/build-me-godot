# Attributions

Build Me Godot orchestrates external creative tools but does not redistribute them unless explicitly stated. Install optional tools from their official publishers and review the version-specific license before use.

## Gator Model Studio

- Publisher: [Blackwater Gator Studios](https://blackwatergatorstudios.ca/)
- Project: [Gator Model Studio on the Godot Asset Store](https://store.godotengine.org/asset/blackwater-gator-studios/gator-model-studio/)
- Version reviewed: 1.0.1
- License listed for that version: [MIT](https://choosealicense.com/licenses/mit/)
- Included with Build Me Godot: No
- Required by Build Me Godot: No

Gator Model Studio is acknowledged as a potential last-mile, in-Godot refinement solution for generated 3D assets. Its published feature set includes mesh and UV editing, materials, rigging, weight painting, animation, remeshing, collision generation, and GLB/glTF import and export. Build Me Godot may detect or interoperate with a separately installed copy, but users obtain it directly from its publisher.

Gator Model Studio and Blackwater Gator Studios are names belonging to their respective owner. This acknowledgement does not imply endorsement, sponsorship, or affiliation.

## Character Turnaround ComfyUI Helper

- Origin: Build Me Godot project-local integration
- License: MIT
- Included with Build Me Godot: Yes, as source code
- Model weights included: No

`integrations/comfyui/character_turnaround_output.py` supplies local-only ComfyUI nodes for loading, normalizing, composing, and deterministically saving turnaround views. It does not download models or contact external services.

## Quaternius Universal Animation Library Standard

- Publisher: Quaternius
- License reviewed: CC0-1.0
- Included with Build Me Godot: Yes, as a scoped onboarding asset subset
- Required by Build Me Godot: No

The packaged onboarding scene at `examples/base_characters.tscn` instances two rigged Quaternius mannequins and their shared animation library from `examples/quaternius_ik_rigged/`. These assets are included so new users can inspect the expected two-character rig setup immediately after enabling the addon. Production characters, reconstruction meshes, and project animation libraries remain user-owned project assets.

## TripoSR

- Publisher: VAST-AI-Research / Stability AI research release
- Project: [TripoSR](https://github.com/VAST-AI-Research/TripoSR)
- Version reviewed: `107cefdc244c39106fa830359024f6a2f1c78871`; model revision `5b521936b01fbe1890f6f9baed0254ab6351c04a`
- License reviewed for that version: MIT code and MIT weights
- Included with Build Me Godot: No
- Required by Build Me Godot: No

TripoSR is acknowledged as an optional, user-managed proxy reconstruction provider for field-engineer mesh conformance. Build Me Godot only records readiness, provenance, and install-plan guidance; it does not clone the repository, install Python packages, download weights, or treat generated proxy meshes as production topology.

## ComfyUI-Flowty-TripoSR

- Publisher: flowtyone / flowt.ai community project
- Project: [ComfyUI-Flowty-TripoSR](https://github.com/flowtyone/ComfyUI-Flowty-TripoSR)
- Version reviewed: master branch on 2026-08-13
- License reviewed for that version: GPL-3.0
- Included with Build Me Godot: No
- Required by Build Me Godot: No

ComfyUI-Flowty-TripoSR is acknowledged as an optional external ComfyUI custom
node for local TripoSR proxy reconstruction. Because it is GPL-3.0, Build Me
Godot does not bundle or copy its code into the MIT addon package. The setup
app detects an already installed native node but does not download, stage, or
install the node or its Python requirements.

## TRELLIS

- Publisher: Microsoft Research
- Project: [TRELLIS](https://github.com/microsoft/TRELLIS)
- Model: [TRELLIS-image-large](https://huggingface.co/microsoft/TRELLIS-image-large)
- Version reviewed: main branch and model card reviewed 2026-08-13
- License reviewed for that version: MIT code and MIT model posture
- Included with Build Me Godot: No
- Required by Build Me Godot: No

TRELLIS is acknowledged as an experimental, user-managed local proxy
reconstruction provider for field-engineer mesh conformance when TripoSR output
is insufficient. Build Me Godot ships only provider metadata and a wrapper
contract. It does not clone TRELLIS, install Python packages, download model
weights, or redistribute TRELLIS submodules.

## Hunyuan3D 2.1

- Publisher: Tencent Hunyuan
- Project: [Hunyuan3D 2.1](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1)
- Version reviewed: `82920d643c0dc2f7bfd7255f45f62d386edfe60c`
- License reviewed for that version: Tencent Hunyuan 3D 2.1 Community License
- Included with Build Me Godot: No
- Required by Build Me Godot: No

Hunyuan3D 2.1 was evaluated locally as an alternate shape-only image-to-3D
backend for field-engineer proxy reconstruction. It produced stronger raw
geometry than TripoSR and useful comparison output against TRELLIS, but its
custom model license is not accepted by Build Me Godot's permissive-default
dependency policy. Build Me Godot does not install, wrap, redistribute, or
recommend it as a default provider.

## Burb Sweeper Humanoid Pipeline

- Copyright: 2026 Inhuman Entertainment
- Source project: Burb Sweeper
- License: MIT
- Included with Build Me Godot: Generalized Blender build and deformation-validation scripts

The Build Me Godot Blender integration derives from the reusable humanoid pipeline developed for Burb Sweeper. Project-specific paths and asset assumptions were removed; the original MIT copyright and permission terms are retained by this attribution and the project license.
