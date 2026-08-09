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
		_:
			return {
				"id": id, "mode": "manual", "summary": "Manual configuration is required.",
				"rationale": "This dependency has no reviewed safe local action.",
				"paths": [], "prerequisites": [], "reversible": null, "license": null,
				"verification_checks": [], "applied": false
			}
