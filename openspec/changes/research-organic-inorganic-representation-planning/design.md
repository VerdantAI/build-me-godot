## Context

The current asset pipeline is strongest when generated output is treated as
reference material and Blender/Godot own production asset structure. For
humanoids, the emerging direction is canonical topology plus AI-generated
shape/appearance. For manufactured or inorganic objects, the stronger
direction is often not a canonical deforming body. It is a semantic assembly.

Example target decomposition:

```text
Labmarket droid
├── head shell        -> hard-surface mesh or bevelled primitive
├── torso shell       -> hard-surface mesh or panel assembly
├── glass tubes       -> cylinders + transparent material
├── arms              -> cylinders, bevelled boxes, joints
├── axle              -> cylinder
├── wheels            -> lathed profiles or cylinders
├── cables            -> curves
├── knobs             -> revolved geometry
├── markings          -> decals or texture layers
└── steam/vapor       -> shader or particle/volume reference
```

That is a different problem from reconstructing an organic mesh. The planner
should decide which representation is appropriate before geometry generation:

```text
image / prompt / sketch
        |
        v
semantic object decomposition
        |
        v
representation plan per part
        |
        +-- organic/residual mesh
        +-- hard-surface mesh
        +-- primitive/CAD/BRep
        +-- curve/cable/tube
        +-- cloth/flexible mesh
        +-- shader/volume
        +-- decal/texture
        |
        v
assembly + pivots + materials + collision + validation
```

## Research Signals

### PartCrafter

PartCrafter is an MIT-licensed NeurIPS 2025 project for structured 3D mesh
generation. Its paper describes generating multiple semantically meaningful and
geometrically distinct meshes from one RGB image rather than a monolithic
shape. Its README includes a robot image example with `--num_parts 3` and
documents local inference, CUDA with at least 8 GB VRAM, and automatic
downloads for PartCrafter and RMBG weights. Optional VLM-based part suggestion
and style transfer use Gemini by default and are therefore not local-only.

Build Me Godot posture:

- valuable first local candidate for part-aware proxy outputs;
- research-only until automatic downloads and transitive model licenses are
  modeled;
- local core path may be usable if all weights are manually staged and offline
  mode is enforced;
- hosted VLM/style-transfer features are out of scope for default workflows.

### OmniPart

OmniPart is an MIT-licensed SIGGRAPH Asia 2025 project for part-aware 3D
generation. Its project page and paper describe a two-stage system: structure
planning that predicts a variable-length sequence of 3D part bounding boxes,
guided by flexible 2D masks, followed by part synthesis adapted from TRELLIS.
Its repository states that pretrained models, an interactive demo, training
code, and data processing were released, and that model weights are
automatically downloaded to `ckpt/`.

Build Me Godot posture:

- closest conceptual match for editable part-aware assets;
- especially relevant for robots and mechanical props where part granularity
  should be controllable;
- should inherit TRELLIS and weight-license review requirements;
- must remain user-managed and offline-gated before any provider wrapper.

### MeshArt

MeshArt is a CVPR 2025 project for articulated mesh generation. It first
generates articulation-aware object structure, including part bounding boxes
and articulation modes, then generates compact part meshes conditioned on that
structure. Its public categories focus on storage furniture, tables, and
chairs, making it an architectural precedent more than a drop-in robot
generator.

Build Me Godot posture:

- strong reference for representing pivots, hinges, sliding parts, and
  rotational modes before mesh generation;
- useful for furniture, doors, machines, wheels, turrets, and robots;
- category coverage and exact code/data/model licenses need review before
  provider status.

### CAD-Recode

CAD-Recode is an ICCV 2025 project that translates point clouds into
executable Python CadQuery code using a Qwen2-1.5B-based architecture. The
project describes a procedural dataset of one million CAD programs with
low-level primitives such as lines, circles, and arcs and higher-level
abstractions such as rectangles, boxes, and cylinders.

Build Me Godot posture:

- important because it points to construction-procedure recovery rather than
  triangle recovery;
- promising for manufactured assets, collision, LOD, and editable geometry;
- generated code execution is a security boundary and must require sandboxing
  and explicit approval;
- CadQuery/OpenCascade licensing and model/data artifacts need separate review.

### NURBGen

NURBGen is an AAAI 2026 text-to-CAD method that uses an LLM to generate NURBS
surface parameters and combines analytic primitives with NURBS surfaces to
produce BRep-format CAD models. It is relevant as a representation target even
if no local implementation is selected yet.

Build Me Godot posture:

- reference for analytic primitive plus NURBS/BRep asset generation;
- useful for complex manufactured surfaces that primitives alone cannot
  express;
- code/model availability and licenses must be reviewed before provider work.

### SGS-1

Spectral Labs' SGS-1 appears to target image/mesh to structured CAD B-Reps and
STEP output. It is a useful signal that industry is validating structured CAD
output from AI, but it is not currently a local open-source default candidate
for Build Me Godot.

Build Me Godot posture:

- commercial/research validation only;
- do not add hosted or proprietary dependency assumptions;
- review original source, access model, license, and data posture before
  mentioning it in addon-facing documentation.

### Meshtron

NVIDIA Meshtron is a data-driven mesh generator that aims for artist-like mesh
topology. NVIDIA describes the problem with marching-cubes/tetrahedra outputs
as dense, poorly structured meshes and positions Meshtron as controllable by
point clouds, face count, and quad ratio, generating up to 64K faces.

Build Me Godot posture:

- useful for the "mesh is still the right representation, but topology matters"
  branch;
- less ideal than CAD/procedural representation for simple manufactured
  primitives;
- exact code/model availability and license posture must be reviewed.

## Goals / Non-Goals

**Goals**

- Add a representation-planning layer before geometry generation.
- Distinguish organic, inorganic, hard-surface, mechanical, flexible, curve,
  shader/volume, and decal components.
- Evaluate part-aware, articulated, CAD-code, NURBS/BRep, artist-topology, and
  monolithic reconstruction providers under one comparison contract.
- Preserve semantic part boundaries for materials, pivots, sockets, collisions,
  LODs, and animation.
- Prefer procedural/analytic geometry for wheels, axles, cylinders, panels,
  knobs, tubes, cables, and other simple manufactured parts.
- Keep AI reconstruction meshes as immutable references unless a reviewed
  production conversion path exists.

**Non-goals**

- General CAD system replacement.
- Automatic execution of untrusted generated scripts.
- Hosted CAD or VLM integration.
- A single universal provider for every object category.
- Automatic rewrite of existing humanoid or field-engineer conformance
  workflows.

## Object Taxonomy

Each asset experiment should declare one top-level taxonomy and any number of
component taxonomies:

- `organic_character`: humanoids, animals, creatures, plants, soft bodies;
- `inorganic_mechanical`: robots, machines, vehicles, tools, weapons;
- `inorganic_architectural`: walls, doors, windows, furniture, fixtures;
- `hybrid_character_prop`: armor, prosthetics, helmets, backpacks, wearable
  machinery;
- `flexible_or_cloth`: capes, flags, straps, hoses, fabric, soft accessories;
- `effect_or_volume`: vapor, smoke, fire, glow, glass caustic reference;
- `decal_or_marking`: labels, painted symbols, grime, scratches, UI panels;
- `unknown_mixed`: requires planning before production work.

Taxonomy is not a license classification. It is a representation and pipeline
choice.

## Representation Classes

The representation planner should support:

- `organic_mesh`: sculptural or deforming mesh, often rigged/skinned;
- `hard_surface_mesh`: bevelled panels, shells, custom mechanical forms;
- `primitive`: box, cylinder, sphere, cone, torus, capsule, plane;
- `lathed_or_revolved`: wheels, knobs, bolts, caps, pulleys;
- `curve`: cable, hose, wire, pipe, rope, rail;
- `cad_code`: CadQuery/OpenCascade-style construction procedure;
- `brep_or_step`: imported/exported CAD BRep or STEP-like object;
- `nurbs_surface`: parameterized smooth manufactured surface;
- `cloth_or_flexible_mesh`: simulated or manually weighted soft part;
- `shader_volume`: vapor, glow, glass, fluid, emissive field;
- `decal_texture`: markings, labels, scratches, panel lines;
- `residual_reference_mesh`: monolithic reconstruction kept for measurement.

## Representation Plan Contract

Each experiment should produce a project-local JSON artifact equivalent to:

```json
{
  "schema_version": 1,
  "asset_id": "labmarket_droid",
  "source_version": "v1",
  "object_taxonomy": "inorganic_mechanical",
  "game_mode_profile_id": "first_person_fps",
  "planner_source": "manual_or_ollama_or_provider",
  "components": [
    {
      "component_id": "wheel_left",
      "label": "left wheel",
      "taxonomy": "inorganic_mechanical",
      "representation": "lathed_or_revolved",
      "candidate_provider": "blender_procedural",
      "inputs": ["front_reference.png", "side_reference.png"],
      "material_slots": ["rubber", "rim_metal"],
      "articulation": {
        "mode": "revolute",
        "axis": "local_x",
        "pivot_hint": "wheel_center"
      },
      "sockets": [],
      "collision": "cylinder_proxy",
      "lod_strategy": "generated_lod",
      "production_candidate": true,
      "review_notes": []
    }
  ],
  "assembly": {
    "origin_policy": "root_at_ground_center",
    "scale_policy": "project_units",
    "export_format_candidates": ["glb"],
    "validation": ["part_count", "pivot_alignment", "material_assignment"]
  }
}
```

The planner output is not itself final geometry. It is the contract that
selects downstream generation and validation paths.

## Provider Classes

### Part-Aware Mesh Provider

Examples: PartCrafter, OmniPart.

Use when the source asset should remain separable into semantic components but
the part geometry is still best represented as meshes. Required evaluation:

- part count control;
- semantic decoupling;
- boundary cleanliness;
- per-part material assignment;
- collision proxy derivability;
- LOD derivability;
- automatic-download behavior;
- weight/data license posture.

### Articulation-Structure Provider

Example: MeshArt.

Use when movable parts matter: hinges, wheels, doors, drawers, turrets, arms,
folding components, or mechanical linkages. Required evaluation:

- generated pivot/axis quality;
- articulation mode vocabulary;
- relationship to Godot nodes, sockets, and animation tracks;
- part mesh compactness;
- category coverage.

### Procedural CAD Provider

Examples: CAD-Recode, NURBGen, future CadQuery/OpenCascade wrappers.

Use when a component can be represented by construction code or CAD surfaces.
Required evaluation:

- code execution safety;
- deterministic regeneration;
- editability;
- primitive vocabulary;
- BRep/STEP/glTF export path;
- license posture for generated code, model, and CAD kernel.

### Artist-Topology Mesh Provider

Example: Meshtron.

Use when a mesh is still the right output but marching-cubes-style topology is
too dense or unstructured. Required evaluation:

- face-count control;
- quad ratio control;
- editability;
- UV/material friendliness;
- rigging or deformation suitability;
- local availability and license posture.

### Monolithic Reconstruction Provider

Examples: TripoSR, TRELLIS, InstantMesh, Hunyuan-style candidates.

Use only as residual or reference geometry when representation planning cannot
find a cleaner structure. Required evaluation:

- whether it preserves or destroys semantic parts;
- whether it is useful for measurement;
- whether it should be split, fitted to primitives, or rejected;
- whether topology is production-ready for the selected game-mode profile.

## Experiment Plan

### Stage 0: Research And License Triage

Record for each provider:

- source URL and reviewed date;
- exact commit/tag/model revision when tested;
- code license;
- model/data/license posture;
- automatic-download behavior;
- hosted-service requirements;
- expected inputs and outputs;
- output representation classes;
- hardware requirements;
- whether generated output can be project-owned production data.

Initial triage:

| Provider | Posture | Reason |
| --- | --- | --- |
| PartCrafter | Candidate research | MIT code and local core path, but auto-downloads weights and RMBG; optional VLM path is hosted |
| OmniPart | Candidate research | MIT code and strong part-aware structure, but auto-downloads model weights and builds on TRELLIS lineage |
| MeshArt | Reference/candidate | strong articulation architecture, limited published categories, license/data review needed |
| CAD-Recode | Candidate research | interpretable CadQuery output, but generated-code execution and model/data licenses need review |
| NURBGen | Concept/reference | strong text-to-CAD/NURBS signal, implementation/license review needed |
| SGS-1 | Reference only | structured CAD validation signal, not local open-source default |
| Meshtron | Reference/candidate | artist-like topology branch, local availability/license review needed |

### Stage 1: Manual Planner Fixtures

Before integrating any provider, write manual representation plans for:

- Labmarket droid;
- furniture item with drawers/doors;
- hand tool or weapon;
- architectural prop;
- organic plant or creature for contrast;
- hybrid wearable such as hardhat, backpack, armor, or prosthetic.

These fixtures should prove the contract can describe primitives, curves,
hard-surface meshes, organic meshes, decals, materials, collisions, and
articulation.

### Stage 2: Blender Procedural Prototype

Implement no provider integration yet. Instead, test whether the plan can drive
simple Blender generation:

- cylinders for axles/tubes;
- lathed wheels/knobs;
- bevelled boxes for panels;
- curves for cables;
- material placeholders;
- pivot empties and sockets;
- collision proxies;
- LOD placeholders.

The generated result should be intentionally simple but structured and
editable.

### Stage 3: Part-Aware Provider Benchmarks

Benchmark PartCrafter and OmniPart only against manually staged local
environments and weights. Compare:

- input image requirements;
- part count control;
- segmentation/mask control;
- output format;
- part boundary quality;
- material assignment readiness;
- downstream primitive/CAD fitting usefulness;
- game-mode budget fit.

### Stage 4: CAD And Articulation Benchmarks

Benchmark CAD-Recode/NURBGen-style outputs and MeshArt-style articulation
outputs separately. Do not execute generated CAD code except in an approved
sandbox. Compare:

- whether generated code can recreate simple shapes;
- whether primitive fitting is more reliable than mesh generation;
- whether pivot/axis outputs can map to Godot nodes and animations;
- whether output is useful for collision and LOD.

### Stage 5: Planner-Assisted Provider Selection

Only after contracts and fixtures are stable, evaluate an automatic or
Ollama-assisted planner that proposes component representation classes. The
planner must produce reviewable JSON. It cannot invoke geometry providers until
the user approves the plan.

## Data Boundaries

All experiments write under:

```text
res://build_me_godot/assets/<asset_id>/representation_plans/<version>/
```

or, for character-associated props:

```text
res://build_me_godot/characters/<character_id>/assets/<asset_id>/representation_plans/<version>/
```

External provider roots, CAD model folders, Python environments, and downloaded
weights are referenced only through local configuration. They are not copied
into `addons/build_me_godot/`.

## Safety And Execution Policy

- Generated CAD/Python code is untrusted and must not be executed inside the
  Godot editor process.
- Provider READMEs that auto-download weights must be wrapped with offline mode
  or blocked until manual artifact paths are configured.
- Hosted VLM features, API keys, and remote style transfer are out of scope for
  default local workflows.
- Part-aware mesh outputs are references until validated for material slots,
  pivots, collisions, scale, LODs, and export.
- Procedural geometry should keep construction parameters whenever possible.
- Monolithic meshes should be residual references, not the first production
  choice for simple manufactured parts.

## Relationship To Existing Specs

- Extends game-mode profile work by adding object taxonomy and representation
  planning.
- Complements canonical-human topology research: organic humanoids need
  canonical deformation contracts, while inorganic assets need part and
  representation contracts.
- Extends field-engineer conformance for secondary assets such as hardhats,
  tools, radios, clipboards, belts, and machinery.
- Consumes installation-environment utilities for read-only provider readiness
  and manual setup plans.

## Open Questions

- Should representation plans be a general asset manifest or nested under
  character manifests for props?
- Should Godot show the plan as a part tree with editable representation
  dropdowns?
- Which procedural backend is the safest first target: Blender Python,
  Geometry Nodes, CadQuery, or a limited internal primitive schema?
- Can local Ollama reliably classify parts into representation classes, or
  should the first planner be manual-only?
- What minimal sandbox is acceptable before executing generated CAD code?
