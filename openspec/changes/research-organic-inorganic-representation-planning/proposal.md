## Why

Build Me Godot currently treats many generated 3D assets as proxy meshes that
can guide downstream Blender/Godot work. That is reasonable for some organic
or sculptural shapes, but it is often the wrong representation for robots,
machines, vehicles, furniture, architecture, props, cables, glass tubes,
wheels, panels, hinges, and other inorganic or manufactured objects.

For inorganic assets, a single watertight triangle mesh can discard the very
structure artists and game systems need: separable parts, materials, pivots,
sockets, CAD-like primitives, curves, procedural bevels, articulation modes,
and clean collision. A Labmarket-style droid should be understood as an
assembly of shells, cylinders, wheels, cables, tubes, knobs, panels, decals,
and joints rather than a fused organic blob.

Recent research supports this direction through part-aware generation,
articulated mesh generation, CAD-code reconstruction, NURBS/BRep generation,
structured CAD B-Reps, and artist-like topology. Build Me Godot should research
a representation planner that classifies each asset or component as organic,
hard-surface, primitive/CAD, curve, cloth/flexible, shader/volume, decal, or
residual mesh before choosing a generation pipeline.

## What Changes

- Add an OpenSpec research track for organic versus inorganic representation
  planning.
- Define provider and pipeline evaluation for PartCrafter, OmniPart, MeshArt,
  CAD-Recode, NURBGen, SGS-1, Meshtron, and existing monolithic reconstruction
  providers.
- Require every asset experiment to declare an object taxonomy and a
  representation plan before geometry generation is considered successful.
- Add a project-local representation-plan contract for semantic parts,
  primitive/CAD candidates, mesh candidates, curves, shaders, decals,
  articulation pivots, sockets, materials, collision, and validation evidence.
- Keep all referenced tools research-only until exact code, model/data
  licenses, automatic-download behavior, and output contracts are reviewed.

## Out Of Scope

- No PartCrafter, OmniPart, MeshArt, CAD-Recode, NURBGen, SGS-1, Meshtron,
  CadQuery, OpenCascade, Python packages, model weights, datasets, or Blender
  extensions are installed or bundled.
- No hosted API, VLM provider, or commercial CAD service is added.
- No arbitrary generated mesh is promoted to production topology.
- No generated CAD script is executed without sandboxing and explicit user
  approval in a later implementation proposal.
- No existing humanoid workflow is replaced by this research change.

## References Reviewed

- PartCrafter paper: https://proceedings.neurips.cc/paper_files/paper/2025/hash/32cc61322f1e2f56f989d29ccc7cfbb7-Abstract-Conference.html
- PartCrafter repository: https://github.com/wgsxm/PartCrafter
- OmniPart project: https://omnipart.github.io/
- OmniPart repository: https://github.com/HKU-MMLab/OmniPart
- OmniPart DOI page: https://doi.org/10.1145/3757377.3763872
- MeshArt project: https://daoyig.github.io/Mesh_Art/
- CAD-Recode project: https://cad-recode.github.io/
- CAD-Recode repository: https://github.com/filaPro/cad-recode
- NURBGen AAAI paper page: https://ojs.aaai.org/index.php/AAAI/article/view/37922
- Meshtron technical blog: https://developer.nvidia.com/blog/high-fidelity-3d-mesh-generation-at-scale-with-meshtron/
- SGS-1 research page to review before promotion:
  https://www.spectrallabs.ai/research/SGS-1
