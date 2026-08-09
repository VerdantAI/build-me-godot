# Agent instructions

Read `README.md`, `addons/build_me_godot/ATTRIBUTIONS.md`, and `addons/build_me_godot/LICENSES.md` before changing integrations or dependencies.

- Keep the Asset Store package self-contained beneath `addons/build_me_godot/`.
- Store artist-created manifests and outputs beneath `res://build_me_godot/`, never inside the addon directory.
- Do not install ComfyUI, model weights, Python packages, Blender extensions, Gator Model Studio, or animation assets automatically.
- Internet or model-download actions must be explicit user actions. Core addon behavior is local-only.
- Verify code and model-weight licenses separately. Do not add non-commercial, research-only, hosted-only, or unclear-weight dependencies.
- Treat AI reconstruction meshes as immutable references. Automatic decimation, remeshing, and weights are validation aids, not production topology.
- Preserve the `neutral_a_pose_30deg_v1` pose contract and stable humanoid/socket names unless a versioned schema migration is included.
- Use Godot `SkeletonProfileHumanoid` for retargeting; do not add a competing retargeter.
- Keep Gator Model Studio optional and independently installed. Do not write into another addon's directory without an explicit user action.
- Run the headless editor load, GDScript tests, Python parser checks, and `git diff --check` before handing off changes.
