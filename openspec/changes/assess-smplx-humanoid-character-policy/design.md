## Context

Build Me Godot is a Godot Asset Store-oriented addon. Its integration policy is
local-first and conservative:

- the addon package must stay self-contained under `addons/build_me_godot/`;
- generated manifests and outputs live under `res://build_me_godot/`;
- external tools, model weights, Python packages, and Blender extensions are
  not installed automatically;
- code and model-weight licenses are reviewed separately;
- AI reconstruction meshes are immutable references, not production topology;
- Godot `SkeletonProfileHumanoid` remains the retargeting boundary.

SMPL-X is relevant because it provides a canonical expressive human model and
many avatar research systems use it. It is risky because "uses SMPL-X" can mean
several materially different things with different legal and engineering
consequences.

## Current Repository Posture

### Is Build Me Godot using SMPL-X now?

Current evidence says no for shipped/runtime behavior.

Local search after excluding packed Quaternius mesh data found no SMPL-X
references in:

- `addons/`;
- `build_me_godot/`;
- `tests/`;
- `utils/`;
- `containers/`;
- top-level `README.md`.

SMPL-X appears in OpenSpec research material only, primarily as a dependency of
candidate research systems. The current addon-facing license table also does
not list SMPL-X as an included, required, wrapper, or candidate component.

This means Build Me Godot is not currently SMPL-X-derived by default based on
repo evidence. A formal audit should still be added before release changes
that mention SMPL-X providers.

### What would count as SMPL-X use?

The policy needs to distinguish:

- bundling SMPL-X model/software files;
- downloading SMPL-X files through setup utilities;
- requiring a local SMPL-X path for a provider;
- invoking SMPL-X fitting or body-model code;
- storing SMPL-X shape, expression, pose, or hand parameter vectors;
- exporting or redistributing meshes derived from SMPL-X model/software;
- using SMPL-X UV maps, blendshapes, skeletons, skin weights, or topology as a
  production template;
- importing third-party provider output that was created with SMPL-X;
- using published SMPL-X papers as conceptual references without touching
  model/software/data.

Only the last category is clearly "reference only." Everything else needs
license, provenance, user-acknowledgement, and export-policy handling.

## License Summary

This is an engineering policy summary, not legal advice.

The SMPL-X Model/Software license page states that the software/data license is
for academic research purposes, commercial licensing is available separately,
and the default grant is for non-commercial scientific research, education, or
artistic projects. It also restricts redistribution and prohibits several uses.

The SMPL-X Body license page describes SMPL-X Body as a subset that excludes
the shape blendshapes and tools needed to create 3D bodies using the full
SMPL-X model. It states that SMPL-X Body is CC-BY 4.0 and can be shared in
formats such as OBJ or FBX with attribution. It also references SMPL-related
patent ownership.

Engineering implication:

- The full SMPL-X model/software cannot become a default dependency under the
  current permissive-default policy.
- A body output may have a different sharing posture from the model/software
  used to create it.
- Any production or commercial workflow needs an explicit decision record and
  probably separate commercial permission before Build Me Godot can claim it
  is supported.

## Decision Paths

### Path A: No SMPL-X Runtime Use

This is the current safest default.

Build Me Godot may cite SMPL-X as research context, but it does not detect,
wrap, install, or invoke SMPL-X. Production humanoid work continues through
project-owned meshes, Quaternius onboarding examples, Rigify authoring aids,
MPFB/MakeHuman evaluation, and Godot `SkeletonProfileHumanoid`.

Benefits:

- keeps the addon commercially usable by default;
- avoids SMPL-X redistribution and commercial-use ambiguity;
- avoids fitting/transcoding complexity;
- aligns with current implementation.

Costs:

- loses a mature canonical body/hand/face research substrate;
- makes comparison against avatar research systems less direct;
- may require a separate permissive canonical body strategy.

### Path B: Optional User-Managed Research-Only SMPL-X

Build Me Godot may detect a user-configured SMPL-X environment and allow
research-only provider experiments. The addon records provenance and blocks
commercial-default production promotion.

Requirements:

- no bundled files;
- no automatic downloads;
- no setup action that pulls SMPL-X;
- explicit local path configuration;
- license acknowledgement before execution;
- output labeled `research_only` unless a commercial permission record exists;
- no generated body or parameter export promoted to production by default.

Benefits:

- enables SHERT/HumanGaussian/HAHA/TECA-style benchmark work;
- allows rigorous comparison against canonical-body research;
- keeps the user responsible for acquiring and licensing SMPL-X.

Costs:

- complicated UX around research-only outputs;
- risk that users misunderstand generated-output rights;
- extra validation needed to prevent accidental production promotion.

### Path C: Commercial-License-Enabled SMPL-X

Build Me Godot could support SMPL-X as an optional production provider only
when the user records evidence that they have appropriate commercial
permission and the exact permitted use is compatible with their project.

Requirements:

- formal license decision record schema;
- user-managed local install;
- explicit scope: fitting only, parameter storage, generated mesh export,
  retargeting aid, or template generation;
- attribution handling for any CC-BY body outputs;
- export provenance in character manifests and support reports;
- release review before any addon-facing feature claims support.

Benefits:

- strongest canonical human technology path;
- body, face, and hands are covered by one mature representation;
- aligns with much of current research.

Costs:

- commercial-license complexity;
- unclear fit with Asset Store expectations unless carefully scoped;
- possible patent/licensing obligations around exported assets and services.

## Recommended Starting Position

The first implementation should codify Path A as the default and Path B as a
disabled research-only possibility. Path C should remain blocked until a user
or organization provides commercial-license terms to review.

Practical recommendation:

- keep MPFB/MakeHuman or another permissive canonical mesh as the preferred
  production prototype;
- use SMPL-X only to evaluate research systems and architecture ideas;
- do not store SMPL-X parameters or derived topology in production manifests
  until the policy is resolved;
- add audit tooling so future changes cannot accidentally introduce SMPL-X
  files, path requirements, or provider metadata without a license state.

## Audit Plan

The SMPL-X audit should scan:

- source code and addon package files for SMPL-X imports, paths, filenames,
  URLs, and schema fields;
- packaged examples and local workflow assets for SMPL-X-derived topology,
  UVs, blendshapes, skeletons, or metadata;
- provider manifests for transitive SMPL-X requirements;
- docs and setup actions for instructions that imply SMPL-X installation;
- generated sample manifests for SMPL-X parameter vectors or output labels.

The audit report should classify findings as:

- `none`;
- `research_reference`;
- `requires_local_smplx`;
- `derived_output`;
- `bundled_or_redistributed`;
- `unknown_needs_review`.

## Data And Manifest Policy

If SMPL-X is ever enabled as research-only:

- local paths must be machine-local config, not project portable defaults;
- generated outputs stay under `res://build_me_godot/` but carry license state;
- support reports redact local SMPL-X paths;
- output manifests distinguish research artifacts from production assets;
- approval gates prevent research-only artifacts from registering as final
  game characters.

## Relationship To Game Modes

Game-mode profiles still matter. SMPL-X may be attractive for first-person VR
or hero FPS characters because hands and face are modeled, but it may be
overkill or incompatible for low-poly/high-volume and settlement-sim tracks.
Any SMPL-X experiment must declare its game-mode profile and score against
that mode's budget, not against abstract research quality alone.

## Risks / Trade-offs

- The boundary between SMPL-X Body outputs and full SMPL-X model/software use
  is subtle. Build Me Godot should not simplify it into "SMPL-X is CC-BY."
- Research providers may hide SMPL-X use behind their own scripts. Provider
  manifests need transitive dependency fields.
- Users may expect commercial production from a research demo. UI copy and
  manifest states need to be explicit.
- Avoiding SMPL-X by default may slow progress on high-quality hands/faces,
  but keeps the addon policy coherent.

## Open Questions

- Should the audit block any occurrence of SMPL-X outside OpenSpec/docs unless
  a license record exists?
- What evidence should a commercial-license record require without storing
  private contract text in the project?
- Can SMPL-X Body CC-BY outputs be used as references for validation without
  storing the full model/software provenance?
- Should research-only SMPL-X provider support live in this repository, a
  separate plugin, or only external user scripts?
- Is there a permissive body/hand/face template that gives enough SMPL-X-like
  benefit for Build Me Godot's production path?
