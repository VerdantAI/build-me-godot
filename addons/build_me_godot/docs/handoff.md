# Developer handoff

## Repository boundary

Build Me Godot owns reusable Godot editor UI, character manifests, packaged
ComfyUI workflows and helper nodes, reconstruction adapters, Blender automation,
environment discovery, and agent-facing setup contracts. A consuming game owns
its prompts, accepted reference images, generated assets, character-specific
landmarks, production topology, and runtime scenes.

Do not copy reusable pipeline code into a game repository. Install this addon in
that Godot project and keep artist data under `res://build_me_godot/`.

## Current capabilities

- Save and load versioned character prompts and seeds.
- Refine packaged canonical and multiview ComfyUI workflow JSON.
- Queue canonical generation against a configured local ComfyUI server.
- Check workflow nodes and declared model artifacts without downloading them.
- Run deterministic headless `check`, `plan`, `apply`, and `verify` commands.
- Probe Blender and the packaged humanoid builder, including an explicit deep check.
- Use the optional, user-managed TripoSR adapter on the validated ROCm path.
- Preserve the `neutral_a_pose_30deg_v1` rig and socket contract.

AI reconstruction remains an immutable reference mesh. Automatic rigging and
deformation checks do not establish production-ready topology.

## Machine configuration

Resolution order is command-line override, `BUILD_ME_GODOT_*` environment
variable, gitignored `res://build_me_godot.local.cfg`, global Editor Settings,
then packaged default. Copy `build_me_godot.local.cfg.example` to the project
root or use **Save for this project** in the dock. **Save for me** writes global
editor defaults. Headless runs never require `EditorInterface`.

## Start here

1. Read `AGENTS.md`, `ATTRIBUTIONS.md`, and `LICENSES.md`.
2. Enable the addon per project under **Project Settings > Plugins**.
3. Run the discovery command in `agent-setup.md` before changing dependencies.
4. Use an exact action ID from `plan` for any supported mutation; model and
   package installation remain explicit manual work.
5. Run every automated and manual gate in `release-checklist.md` before a Store release.

## Next independent milestones

1. Complete the manual dock accessibility, narrow-width, and high-DPI gate.
2. Add the full multiview queue action and persisted artifact/status tracking.
3. Add a reconstruction job contract around the existing provider adapter.
4. Execute Blender builds from character manifests and retain validation reports.
5. Add Godot GLB import validation and animation playback checks.
6. Exercise a second character through the pose contract to prove generality.
7. Capture license-safe Store screenshots and complete the publishing checklist.

Gator Model Studio remains an optional independently installed last-mile tool;
Blender remains the authoritative automated build path.
