## Why

SMPL-X is a strong canonical human model for AI avatar research because it
includes body shape, pose, hands, and facial expression. It is also embedded in
many relevant systems such as SHERT, HumanGaussian, HAHA, and TECA. That makes
it tempting to use as the Build Me Godot humanoid substrate.

The current repository does not appear to use SMPL-X implicitly in shipped
addon code or packaged assets. A local scan found SMPL-X references in
OpenSpec research notes, but not in `addons/`, `build_me_godot/`, `tests/`,
`utils/`, or `containers/` after excluding unrelated packed mesh binary data.
The addon currently ships a scoped Quaternius CC0 onboarding rig and uses
Godot `SkeletonProfileHumanoid`, Blender/Rigify authoring experiments, and
optional user-managed reconstruction providers.

Before SMPL-X is used for humanoid characters, Build Me Godot needs a focused
research and policy decision. The standard SMPL-X model/software license is
research/non-commercial and restricts redistribution, while the SMPL-X Body
license covers a narrower body-output category under CC-BY. Those are not the
same thing, and they have different implications for a Godot Asset Store addon
that should remain permissive-default and commercially usable.

## What Changes

- Add an OpenSpec research track to audit whether Build Me Godot uses SMPL-X
  directly, indirectly, or only as a research reference.
- Define what counts as SMPL-X use: model files, fitted parameter vectors,
  code, UV maps, skeletons, blendshapes, generated bodies, provider outputs,
  and transitive provider dependencies.
- Require a license/commercial-use decision record before SMPL-X-backed
  providers can become anything beyond research-only.
- Compare three paths: no SMPL-X, optional user-managed research-only SMPL-X,
  and commercial-license-enabled SMPL-X.
- Preserve current humanoid contracts: project-owned assets under
  `res://build_me_godot/`, no bundled model files, no automatic downloads, no
  replacement retargeter, and continued use of Godot `SkeletonProfileHumanoid`.

## Out Of Scope

- No SMPL-X files, code, Blender extension, Unity/Unreal integration, model
  weights, datasets, or provider repositories are installed or bundled.
- No SMPL-X-backed generation path is promoted to default production workflow.
- No commercial license is assumed.
- No current Quaternius, Rigify, Blender, or Godot humanoid implementation is
  replaced by this change.

## References Reviewed

- SMPL-X homepage and publication summary: https://smpl-x.is.tue.mpg.de/
- SMPL-X Model/Software license: https://smpl-x.is.tue.mpg.de/modellicense.html
- SMPL-X Body license: https://smpl-x.is.tue.mpg.de/bodylicense.html
- Existing canonical-human topology research change:
  `openspec/changes/evaluate-canonical-human-topology-providers/`
