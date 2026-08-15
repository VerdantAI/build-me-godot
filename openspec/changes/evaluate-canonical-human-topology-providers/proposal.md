## Why

Build Me Godot currently treats AI reconstruction meshes as immutable proxy
references and keeps production characters anchored to known Godot/Blender
humanoid contracts. Recent avatar systems point to a more constrained and more
production-friendly direction: AI should predict shape parameters, residual
geometry, texture maps, or localized detail around a canonical body rather than
inventing arbitrary game topology.

The most practical local foundation appears to be MPFB2/MakeHuman because it
already supplies a Blender-native human generator, semantic targets, rigs, and
CC0 core graphical assets. SMPL-X-centered research systems such as SHERT,
HumanGaussian, HAHA, and TECA validate the canonical-body architecture, but the
standard SMPL-X model/software license is non-commercial and no SMPL-X model or
weights can become a default Build Me Godot dependency without a separate
commercial-license path or a replacement permissive template.

## What Changes

- Add a detailed OpenSpec evaluation program for canonical-human topology
  experiments.
- Prioritize an MPFB-style morph/template bridge before SMPL-X-backed provider
  integration.
- Define a provider comparison scorecard for MPFB2/MakeHuman, SHERT,
  HumanGaussian, HAHA, UVFaceFusion, and TECA.
- Require reference manifests, output contracts, license records, and
  no-download readiness checks before any provider wrapper is considered.
- Preserve the existing local-only, explicit-action, addon-self-contained
  boundaries.

## Out Of Scope

- No MPFB2, MakeHuman, SMPL-X, SHERT, HumanGaussian, HAHA, UVFaceFusion, TECA,
  Python package, Blender extension, model-weight, dataset, or container
  installation is added by this change.
- No external source code is vendored into `addons/build_me_godot/`.
- No generated AI topology is promoted to production topology.
- No replacement retargeter is introduced; Godot `SkeletonProfileHumanoid`
  remains the retargeting boundary.
- TECA remains reference-only until runnable code and licenses are available.

## References Reviewed

- MPFB2 repository: https://github.com/makehumancommunity/mpfb2
- MPFB release notes: https://static.makehumancommunity.org/mpfb/releases/index.html
- MakeHuman/MPFB license overview: https://static.makehumancommunity.org/about/license.html
- SHERT repository: https://github.com/ZhanxyR/SHERT
- HumanGaussian repository: https://github.com/alvinliu0/HumanGaussian
- HAHA repository: https://github.com/david-svitov/HAHA
- UVFaceFusion repository: https://github.com/grignarder/UVFaceFusion
- UVFaceFusion paper summary: https://www.roboticscenter.ai/research/papers/uvfacefusion-fast-multi-view-topologically-consistent-face-reconstruction-in-the-wild-via-uv-space-neural-fusion
- TECA project page: https://yfeng95.github.io/teca/
- SMPL-X model/software license: https://smpl-x.is.tue.mpg.de/modellicense.html
- SMPL-X Body license: https://smpl-x.is.tue.mpg.de/bodylicense.html
