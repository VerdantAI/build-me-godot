# Agent instructions

Read `README.md`, `addons/build_me_godot/ATTRIBUTIONS.md`, and `addons/build_me_godot/LICENSES.md` before changing integrations or dependencies.

- The project goal is infrastructure for building Godot characters and assets that are play-test ready, not training new models or recreating existing DCC, CAD, rigging, reconstruction, or generation tools.
- Prefer reusing open-source, permissively licensed, local-capable tools before writing custom implementation code. Search for existing tools, adapters, and standards first; do not rush into bespoke code unless the gap is real, scoped, and license-compatible.
- Leverage common game-development tools such as Blender, ComfyUI, asset stores, and other established DCC/generation ecosystems. Godot is the framework and source of workflow truth, but the pipeline should wire capable external tools together rather than force all work into Godot.
- Prefer a proven orchestrator such as ComfyUI, Hugging Face tooling, or another reviewed local-capable workflow system when it can coordinate a stage cleanly; add Build Me Godot orchestration only where existing orchestrators leave a clear integration gap.
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
