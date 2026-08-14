@tool
extends RefCounted

const SCHEMA_VERSION := 1


static func build(report: Dictionary, options := {}) -> Dictionary:
	var actions: Array[Dictionary] = []
	for remediation in report.get("remediations", []):
		actions.append(_action(remediation.id, options))
	return {
		"schema_version": SCHEMA_VERSION,
		"generated_at": Time.get_datetime_string_from_system(true),
		"requested_capability": report.get("requested_capability", "all"),
		"actions": actions
	}


static func _action(id: String, options: Dictionary) -> Dictionary:
	match id:
		"create.project.workspace":
			return {
				"id": id, "mode": "safe_local", "summary": "Create the project character workspace.",
				"rationale": "Character manifests and generated artifacts need a project-owned location that survives addon updates.",
				"paths": ["res://build_me_godot", "res://build_me_godot/characters"],
				"prerequisites": ["Writable Godot project directory"],
				"reversible": true, "license": null,
				"verification_checks": ["project.workspace"], "applied": false
			}
		"install.comfyui.turnaround_helper":
			var root := str(options.get("comfyui_root", "")).trim_suffix("/")
			return {
				"id": id, "mode": "safe_local" if not root.is_empty() else "manual",
				"summary": "Copy the bundled MIT turnaround helper into an existing ComfyUI installation.",
				"rationale": "The packaged workflows use CharacterTurnaroundOutput to save predictable view filenames.",
				"source": "res://addons/build_me_godot/integrations/comfyui/character_turnaround_output.py",
				"target": root.path_join("custom_nodes/character_turnaround_output.py") if not root.is_empty() else null,
				"paths": [root.path_join("custom_nodes/character_turnaround_output.py")] if not root.is_empty() else [],
				"prerequisites": ["Existing user-selected ComfyUI root", "Existing custom_nodes directory", "Target path must not exist"],
				"overwrite": false, "reversible": true, "license": "MIT", "restart_required": true,
				"verification_checks": ["comfyui.nodes.canonical_only", "comfyui.nodes.multiview_only"],
				"applied": false
			}
		"install.manual.triposr.provider":
			return {
				"id": id, "mode": "manual",
				"summary": "Configure a user-managed TripoSR proxy generation command.",
				"rationale": "Field-engineer conformance can run a configured local TripoSR wrapper to produce immutable reference meshes, but Build Me Godot does not clone repositories, install Python packages, download weights, or install ComfyUI custom nodes automatically.",
				"source": "https://github.com/VAST-AI-Research/TripoSR",
				"target": "BUILD_ME_GODOT_RECONSTRUCTION_COMMAND or res://build_me_godot.local.cfg reconstruction_command",
				"command_contract": {
					"version_probe": "--version",
					"arguments": ["--input", "<image>", "--output", "<mesh.glb>", "--metadata-output", "<metadata.json>"],
					"automatic_downloads_allowed": false
				},
				"paths": [
					"res://addons/build_me_godot/integrations/reconstruction/triposr/triposr.requirements.json",
					"res://addons/build_me_godot/integrations/reconstruction/conformance_providers.json"
				],
				"prerequisites": [
					"User-installed TripoSR checkout and Python environment",
					"User-provided wrapper command that accepts --input, --output, and --metadata-output",
					"User-reviewed MIT code and weight licenses",
					"Existing user-owned model weights mounted into the wrapper or container"
				],
				"reversible": true,
				"license": {
					"code": "MIT",
					"weights": "MIT",
					"commercial_use": true
				},
				"verification_checks": ["conformance.provider.triposr"],
				"applied": false
			}
		"install.manual.trellis.provider":
			return {
				"id": id, "mode": "manual",
				"summary": "Configure a user-managed TRELLIS proxy generation command.",
				"rationale": "TRELLIS is an experimental local proxy provider for cases where TripoSR quality is insufficient. Build Me Godot requires a user-owned checkout, user-owned local model folder, and separate Python environment; it does not clone repositories, install packages, or download weights.",
				"source": "https://github.com/microsoft/TRELLIS",
				"target": "BUILD_ME_GODOT_TRELLIS_ROOT, BUILD_ME_GODOT_TRELLIS_MODEL_PATH, and BUILD_ME_GODOT_RECONSTRUCTION_COMMAND",
				"command_contract": {
					"version_probe": "--version",
					"arguments": ["--input", "<image>", "--output", "<mesh.glb>", "--metadata-output", "<metadata.json>"],
					"automatic_downloads_allowed": false
				},
				"paths": [
					"res://addons/build_me_godot/integrations/reconstruction/trellis/trellis.requirements.json",
					"res://addons/build_me_godot/integrations/reconstruction/conformance_providers.json"
				],
				"prerequisites": [
					"User-installed microsoft/TRELLIS checkout",
					"User-installed TRELLIS Python environment with CUDA-compatible dependencies",
					"Local microsoft/TRELLIS-image-large model folder",
					"Linux NVIDIA GPU with at least 16 GB VRAM"
				],
				"reversible": true,
				"license": {
					"code": "MIT",
					"weights": "MIT",
					"commercial_use": true,
					"notice": "Submodule and dependency licenses must be reviewed separately before redistribution."
				},
				"verification_checks": ["conformance.provider.trellis"],
				"applied": false
			}
		"write.container.config":
			return {
				"id": id, "mode": "manual",
				"summary": "Write local container toolchain configuration that reuses existing model folders.",
				"rationale": "The container path should provide the runtime and mount user-owned model/cache folders instead of mutating the user's ComfyUI environment or downloading duplicate weights.",
				"source": "utils/check-local-requirements.sh",
				"target": "utils/check-local-container.local.env",
				"setup_command": "utils/check-local-requirements.sh apply write.container.config --yes --json",
				"license": {
					"code": null,
					"weights": null,
					"commercial_use": true,
					"notice": "No model weights are baked into the container image; existing user-owned folders are mounted."
				},
				"prerequisites": ["Existing Podman, Docker, or Apptainer runtime", "Existing user-owned model/cache folders"],
				"verification_checks": ["container.runtime", "container.model_mounts"],
				"applied": false
			}
		_:
			return {
				"id": id, "mode": "manual", "summary": "Manual configuration is required.",
				"rationale": "This dependency has no reviewed safe local action.",
				"paths": [], "prerequisites": [], "reversible": null, "license": null,
				"verification_checks": [], "applied": false
			}
