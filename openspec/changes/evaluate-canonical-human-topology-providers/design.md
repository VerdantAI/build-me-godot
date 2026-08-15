## Context

The current Build Me Godot character pipeline can generate references, prepare
project-local conformance artifacts, invoke user-managed reconstruction
providers, and use Blender automation to validate deformation. That is useful
for field-engineer proxy work, but arbitrary image-to-3D meshes still tend to
produce unstable topology, difficult skinning, uncertain UVs, and costly
last-mile cleanup.

The architectural alternative is to pick a canonical human substrate and make
AI operate inside known parameter spaces:

```text
text/reference image
        |
        v
body/face parameter estimation + texture/detail generation
        |
        v
canonical topology, rig, UVs, sockets, and humanoid contract
        |
        v
Blender validation/export -> Godot import
```

This change does not choose a production provider. It creates the evidence and
contracts needed to try the alternatives without weakening the addon boundary.

## Current Research And Tooling Signals

### MPFB2 / MakeHuman

MPFB2 is a Blender human generator requiring Blender 4.2 or newer according to
its upstream README. The MakeHuman Community license page describes a split
license: MPFB source code is GPL, MakeHuman source code is AGPL, and core
graphical assets are CC0. The release page shows active 2.0.x maintenance; as
of this review, 2.0.17 is listed for 2026-07-22.

Architectural relevance:

- best near-term candidate for a Blender-native canonical human;
- target controls map naturally to an AI parameter-estimation problem;
- generated graphical outputs can be project-owned assets under the upstream
  asset posture, but GPL/AGPL source cannot be copied into the MIT addon;
- integration should begin as optional detection plus scripts that call a
  separately installed Blender addon.

### SHERT

SHERT is an MIT-licensed CVPR 2024 research implementation for semantic human
mesh reconstruction with textures. Its README describes a reconstruction step
and a texture-inpainting step, uses SMPL-X data, and can run a local texture
client against `localhost`. It also expects a Python/conda stack, Open3D,
Pytorch/Pytorch3D, ECON-style inputs, SHERT checkpoints, and SMPL-X v1.1 model
files.

Architectural relevance:

- closest reference for image -> SMPL-X fit -> semantic mesh reconstruction ->
  texture completion;
- useful as a research benchmark for residual geometry and UV/texture
  contracts;
- blocked as a default provider by SMPL-X model/software licensing and
  manually downloaded checkpoints.

### HumanGaussian

HumanGaussian is an MIT-licensed CVPR 2024 Highlight codebase for text-driven
3D human generation with Gaussian splatting. Its README describes text prompt
training, SMPL-X model paths, PLY Gaussian avatars, and zero-shot animation
from SMPL-X pose sequences.

Architectural relevance:

- validates the "text -> animatable human controlled by canonical body pose"
  direction;
- useful for rendering and motion-reference experiments;
- less directly useful for Godot production assets because the primary output
  is Gaussian splatting rather than conventional mesh topology.

### HAHA

HAHA is a BSD-3-Clause research codebase for highly articulated Gaussian human
avatars with a textured mesh prior. Its README describes a monocular-video
avatar pipeline controlled by SMPL-X and a Docker-based environment. The method
uses a textured SMPL-X mesh where efficient, adding Gaussians for hair and
out-of-mesh clothing.

Architectural relevance:

- strong hybrid-design reference: base mesh for body/skin plus localized
  splats for detail that exceeds the body surface;
- valuable for deciding whether Build Me Godot should track secondary
  non-mesh appearance layers as immutable references;
- not a near-term game-asset exporter because it reconstructs from video and
  retains Gaussian rendering requirements.

### UVFaceFusion

UVFaceFusion is GPL-3.0 code for multi-view, fixed-topology face
reconstruction. The public README and paper summary describe UV-space neural
fusion that reconstructs topologically consistent facial meshes from 16
in-the-wild images, with a reported sub-3-second run on an RTX 4090. The README
also states the current code is still being cleaned up, base-resolution
inference is the available path, and pretrained UV/VGGT weights must be
obtained separately under their own license terms.

Architectural relevance:

- strong evidence for canonical parameterization over generated topology;
- likely useful as a future face-detail experiment or benchmark;
- GPL code and separate weight licenses prevent bundling and require a
  user-managed provider boundary.

### TECA

TECA is a project-page/paper reference for text-guided generation and editing
of compositional 3D avatars. The page says code is "coming soon". It describes
a mesh-based face/body with NeRF-based hair, clothing, and accessories, using
Stable Diffusion, SMPL-X fitting, diffusion texture painting, SDS, CLIPSeg, and
BLIP-based refinement.

Architectural relevance:

- useful design target for compositional avatar representation;
- not implementable as a local provider until runnable code, exact artifacts,
  and licenses are available.

## Goals / Non-Goals

**Goals**

- Compare canonical-body approaches against current arbitrary reconstruction
  providers using repeatable local evidence.
- Establish a common output contract for morph parameters, texture maps,
  residual geometry, proxy meshes, and optional non-mesh detail layers.
- Keep MPFB-style output as the preferred production-oriented first prototype.
- Keep SMPL-X-backed systems as research/reference providers unless licensing
  is resolved.
- Record every evaluated provider with source URL, reviewed date, exact
  version/commit when tested, code license, model/data license, commercial-use
  posture, install mode, and output contract.
- Store all manifests, experiments, and outputs under `res://build_me_godot/`.

**Non-goals**

- Installing external tools, weights, Python packages, datasets, or Blender
  extensions.
- Bundling GPL, AGPL, SMPL-X, or research-provider code into the MIT addon.
- Creating a general-purpose avatar generator UI before the provider contracts
  are validated.
- Treating research output as production topology without manual approval.
- Adding a second retargeting system beside Godot `SkeletonProfileHumanoid`.

## Provider Classes

### Canonical Morph Provider

The first implementation target should model an already installed MPFB2 or
MakeHuman-compatible environment as a user-managed provider.

Input:

- character manifest version;
- approved text/reference prompt;
- optional reference images;
- optional known scale/age/body-style metadata;
- requested pose contract, defaulting to `neutral_a_pose_30deg_v1`.

Output:

- canonical provider manifest;
- exported neutral mesh or scene in a game-ingestible format;
- parameter preset or morph vector when available;
- material/texture path manifest;
- rig/skeleton report;
- validation report for humanoid bone names, sockets, A-pose, scale, and
  deformation smoke tests.

The addon may detect the provider, build read-only readiness reports, and run
explicit user-configured commands. It must not copy MPFB source, install the
Blender addon, or write into MPFB directories.

### Semantic Reconstruction Reference Provider

SHERT-like providers should be represented as research-reference providers.

Input:

- image or scan references;
- user-managed SMPL-X model path;
- user-managed checkpoints;
- optional upstream project path;
- explicit non-commercial/research-use acknowledgement when SMPL-X is used.

Output:

- immutable reconstructed mesh references;
- texture-completion examples;
- residual-geometry measurements against a canonical baseline;
- no production export without a separate conversion review.

### Gaussian Appearance Reference Provider

HumanGaussian and HAHA-like systems should be represented as appearance and
motion-reference providers, not game-mesh providers.

Input:

- text prompt, image, or video depending on provider;
- user-managed SMPL-X and Gaussian dependencies;
- optional SMPL-X/AMASS-style pose sequences for animation tests.

Output:

- immutable Gaussian PLY or render outputs;
- frame/video evidence for appearance and motion quality;
- optional silhouette and material-reference reports;
- no default Godot runtime import contract.

### UV Face Topology Reference Provider

UVFaceFusion-like systems should be evaluated as a face-topology benchmark.

Input:

- required multi-view face image set, initially 16 views when using the
  current public demo/code assumptions;
- user-managed UV predictor and VGGT weights;
- license record for code and weights.

Output:

- fixed-topology face mesh reference;
- face correspondence report;
- possible morph/shape-key target suggestions;
- no automatic merge into the production body mesh.

## Experiment Plan

### Stage 0: Paper And License Triage

Create a project-local research register for each candidate. A provider cannot
advance past Stage 0 unless it has:

- source URL and reviewed date;
- exact commit/tag or release identifier;
- code license;
- model-weight/data license;
- commercial-use posture;
- installation mode;
- automatic-download behavior;
- expected inputs and outputs;
- known hardware/runtime requirements;
- rejection or quarantine notes.

The first triage ranking should be:

| Provider | Stage 0 posture | Reason |
| --- | --- | --- |
| MPFB2/MakeHuman | Preferred prototype | Blender-native, canonical mesh, CC0 core assets, active releases |
| SHERT | Research reference | MIT code, strong architecture, SMPL-X/checkpoint/manual-download gates |
| HAHA | Research reference | BSD code, hybrid mesh+Gaussian idea, SMPL-X/video/Gaussian gates |
| HumanGaussian | Research reference | MIT code, text-to-avatar signal, Gaussian output not game mesh |
| UVFaceFusion | Watch/reference | fixed topology face result, GPL code, separate weights |
| TECA | Concept only | code not available from project page |

### Stage 1: Output Contract Prototypes

Define provider-agnostic JSON contracts without invoking external providers:

- `canonical_human_provider.json` for readiness and provenance;
- `canonical_human_inputs.json` for prompt/reference/pose inputs;
- `canonical_human_outputs.json` for generated or imported artifacts;
- `canonical_human_validation.json` for humanoid contract results;
- `canonical_human_scorecard.json` for comparison metrics.

The contracts must support:

- morph or parameter vectors;
- neutral mesh/scene paths;
- texture maps, normal maps, and displacement/residual maps;
- optional face mesh references;
- optional Gaussian/NeRF/render references;
- immutable-source flags;
- license status and user acknowledgement records.

### Stage 2: MPFB-First Local Prototype

Prototype only against a separately installed Blender+MPFB environment. The
prototype should:

- detect Blender 4.2+ and a user-configured MPFB installation;
- verify that no addon files are written outside Build Me Godot's workspace;
- export a neutral canonical character to project-local output;
- record MPFB preset/morph data if exposed by the provider;
- validate skeleton and A-pose constraints against Build Me Godot's humanoid
  requirements;
- import the result into Godot as a project-owned artifact.

AI integration in this stage should be mocked or fixture-based first:

- text/reference metadata -> deterministic morph vector;
- texture paths -> fixture texture maps;
- validation report -> stable JSON for tests.

Only after the contract is stable should real AI parameter estimation or
texture generation be added through separately reviewed proposals.

### Stage 3: SMPL-X Research Benchmarks

Evaluate SHERT, HumanGaussian, and HAHA only on machines where the user has
already obtained and configured the required upstream repositories, model
files, checkpoints, and licenses. The benchmark should compare:

- setup friction and automatic-download behavior;
- output representation;
- pose controllability;
- texture/material usefulness;
- ability to generate conventional mesh assets;
- transferability into the MPFB/Godot humanoid contract;
- license/commercial blockers.

Any SMPL-X-backed path must remain disabled for commercial-default workflows
unless a commercial SMPL-X license or a permissive canonical body substitute is
documented.

### Stage 4: Face And Detail Layers

Evaluate UVFaceFusion and TECA-style ideas as separate detail layers:

- fixed-topology face outputs should become face-reference or blendshape
  suggestion artifacts, not automatic topology replacements;
- Gaussian/NeRF clothing and hair should become render/silhouette references
  or manually approved secondary assets;
- final Godot export remains conventional mesh/material/animation data unless
  a future runtime renderer is explicitly designed.

## Scorecard

Each provider experiment should produce a scorecard with:

- `provider_id`;
- `provider_class`;
- `reviewed_version`;
- `license_status`: `accepted`, `candidate`, `research_only`, `blocked`, or
  `unknown`;
- `locality`: `local_only`, `local_with_manual_downloads`, `remote_optional`,
  or `remote_required`;
- `installs_automatically`: boolean;
- `downloads_weights_automatically`: boolean;
- `canonical_topology`: boolean;
- `fixed_uv_or_correspondence`: boolean;
- `humanoid_rig_ready`: boolean;
- `godot_import_ready`: boolean;
- `supports_text_input`: boolean;
- `supports_image_input`: boolean;
- `supports_video_input`: boolean;
- `output_representation`: `mesh`, `mesh_with_maps`, `gaussian`,
  `mesh_plus_gaussian`, `nerf_hybrid`, or `unknown`;
- `production_topology_candidate`: boolean;
- `manual_review_required`: array of reasons;
- `evidence_paths`: project-local reports and thumbnails.

## Data Boundaries

All experiments write under:

```text
res://build_me_godot/characters/<character_id>/canonical_human/<version>/
```

Suggested structure:

```text
inputs/
providers/
outputs/<provider_id>/
references/<provider_id>/
reports/<provider_id>/
scorecards/<provider_id>.json
```

No generated experiment output belongs under `addons/build_me_godot/`. External
provider roots, model roots, and dataset roots are referenced by redacted local
configuration and are not copied into the project.

## License And Safety Gates

- MPFB source code is GPL and MakeHuman source code is AGPL; do not vendor,
  link, or copy their source into the MIT addon.
- MakeHuman/MPFB core graphical assets are described upstream as CC0, but
  exact generated-output provenance still needs to be recorded per artifact.
- SMPL-X model/software is research/non-commercial by default; any path that
  requires the standard SMPL-X download is research-only unless the user
  records separate commercial permission.
- SMPL-X Body has a separate CC-BY posture for body outputs, but it excludes
  the full model/software needed by many reconstruction systems; do not treat
  it as permission to redistribute SMPL-X model files or use research code
  commercially.
- UVFaceFusion is GPL-3.0 code and depends on separately licensed pretrained
  weights; keep it external.
- Provider READMEs that auto-download checkpoints must be wrapped with offline
  mode or blocked until manual artifact paths are configured.

## Risks / Trade-offs

- MPFB's Blender addon API may not expose every morph/control needed for a
  clean headless provider. The fallback is exported presets and Blender-side
  scripts owned by the user's environment.
- SMPL-X is the dominant research substrate, but its default license conflicts
  with Build Me Godot's permissive-default policy. Treating it as research-only
  may limit benchmark comparability, but keeps the addon commercially usable.
- Gaussian and NeRF detail layers are visually attractive but do not map
  directly to standard Godot mesh import. They should inform silhouette,
  material, and secondary-asset authoring before any runtime commitment.
- AI parameter estimation can hide uncertainty. Every estimated morph or
  residual should carry confidence, source evidence, and manual override data.

## Open Questions

- Should the first MPFB prototype use Blender Python directly, exported MHM
  presets, or a small user-authored command wrapper?
- Which morph parameter subset is stable enough to include in a versioned
  Build Me Godot contract?
- Should face-detail experiments target Rigify face controls, ARKit-style
  blendshape names, or a Build Me Godot-neutral expression manifest first?
- How should scorecards compare a Gaussian-only render result with a
  conventional mesh result without overstating game-readiness?
- Is there a permissively licensed canonical body template that can provide
  the SMPL-X-like research benefits without the SMPL-X commercial blocker?
