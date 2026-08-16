extends SceneTree

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")
const TurnaroundWorkflow = preload("res://addons/build_me_godot/services/turnaround_workflow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not parsed.ok:
		printerr(parsed.error)
		quit(2)
		return
	var store := CharacterStore.new()
	var result := {}
	match parsed.command:
		"draft":
			result = store.save_draft(parsed.values)
		"import-workflow":
			var workflow := _load_workflow(str(parsed.values.get("workflow_path", "")))
			if workflow.is_empty():
				result = {"ok": false, "error": "Workflow JSON could not be loaded or parsed."}
			else:
				var fields := TurnaroundWorkflow.extract_prompt_fields(workflow)
				if fields.is_empty():
					result = {"ok": false, "error": "Workflow JSON did not contain importable prompt fields."}
				else:
					var values: Dictionary = parsed.values.duplicate(true)
					values.erase("workflow_path")
					values.merge(fields, false)
					result = store.save_draft(values)
		"inspect":
			result = store.load_character(str(parsed.values.get("character_id", "")))
		"queue":
			var queue_values := {
				"workflow_id": str(parsed.values.get("workflow_id", "qwen_blender_reference_set_ui")),
				"workflow_version": str(parsed.values.get("workflow_version", "1")),
				"status": "pending"
			}
			if parsed.values.has("prompt"):
				queue_values["positive_prompt"] = str(parsed.values.prompt)
			if parsed.values.has("negative_prompt"):
				queue_values["negative_prompt"] = str(parsed.values.negative_prompt)
			if parsed.values.has("seed"):
				queue_values["seed"] = int(parsed.values.seed)
			if parsed.values.has("workflow_path"):
				var workflow := _load_workflow(str(parsed.values.workflow_path))
				if workflow.is_empty():
					result = {"ok": false, "error": "Workflow JSON could not be loaded or parsed."}
				else:
					var loaded := store.load_character(str(parsed.values.get("character_id", "")))
					if not loaded.ok:
						result = loaded
					else:
						var graph = workflow.get("prompt", workflow)
						var configured := TurnaroundWorkflow.configure_canonical(graph, loaded.manifest)
						if configured.is_empty():
							result = {"ok": false, "error": "Workflow JSON could not be configured for queueing."}
						else:
							queue_values["workflow_snapshot"] = configured
							queue_values["workflow_source_path"] = str(parsed.values.workflow_path)
							queue_values["workflow_format"] = "api"
							result = store.create_generation_run(str(parsed.values.get("character_id", "")), queue_values)
			else:
				result = store.create_generation_run(str(parsed.values.get("character_id", "")), queue_values)
		"approve":
			result = store.approve_generation_version(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"continue":
			result = store.continue_pipeline(str(parsed.values.get("character_id", "")), parsed.values)
		"inspect-conformance":
			result = store.inspect_conformance(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"create-recipe":
			result = store.create_character_recipe(str(parsed.values.get("character_id", "")), parsed.values)
		"inspect-recipe":
			result = store.inspect_character_recipe(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"validate-recipe":
			result = store.validate_character_recipe(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"approve-recipe":
			result = store.approve_character_recipe(str(parsed.values.get("character_id", "")), parsed.values)
		"register-assembly":
			result = store.register_assembly_result(str(parsed.values.get("character_id", "")), parsed.values)
		"checkpoint-status":
			result = store.checkpoint_status(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"write-checkpoints":
			result = store.write_character_checkpoints(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"invalidate-stage":
			result = store.invalidate_checkpoint_stage(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")), str(parsed.values.get("stage", "")), str(parsed.values.get("reason", "")))
		"mark-reviewed":
			result = store.mark_checkpoint_reviewed(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")), str(parsed.values.get("stage", "")))
		"explain-stale":
			result = store.explain_stale_checkpoints(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")))
		"resume-from-stage":
			result = store.resume_from_checkpoint(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")), str(parsed.values.get("stage", "")))
		"reuse-base-checkpoint":
			result = store.reuse_base_checkpoint(str(parsed.values.get("character_id", "")), str(parsed.values.get("version", "")), str(parsed.values.get("source_character_id", "")), str(parsed.values.get("source_version", "")))
		"prepare-conformance":
			result = store.prepare_conformance(str(parsed.values.get("character_id", "")), parsed.values)
		"generate-proxy":
			result = store.generate_proxy(str(parsed.values.get("character_id", "")), parsed.values)
		"approve-conformance":
			result = store.approve_conformance(str(parsed.values.get("character_id", "")), parsed.values)
		_:
			result = {"ok": false, "error": "Unknown command: %s" % parsed.command}
	if not result.ok:
		printerr(result.error)
		quit(2)
		return
	var output := {
		"schema_version": 1,
		"command": parsed.command,
		"path": result.get("path", ""),
		"manifest": result.manifest,
		"available_actions": store.available_actions(result.manifest),
		"changed_paths": result.get("changed_paths", []),
		"conformance_plan_path": result.get("conformance_plan_path", ""),
		"conformance_plan": result.get("conformance_plan", {}),
		"mesh_guidance": result.get("mesh_guidance", {}),
		"recipe_path": result.get("recipe_path", ""),
		"recipe": result.get("recipe", {}),
		"recipe_validation": result.get("recipe_validation", {}),
		"assembly_report": result.get("assembly_report", {}),
		"registration_report": result.get("registration_report", {}),
		"checkpoint_path": result.get("checkpoint_path", ""),
		"checkpoint_index": result.get("checkpoint_index", {}),
		"stale_explanations": result.get("stale_explanations", [])
	}
	if bool(parsed.get("support_report", false)):
		output = _redact_support_output(output)
	print(JSON.stringify(output))
	quit(0)


func _parse_args(arguments: PackedStringArray) -> Dictionary:
	var commands := ["draft", "import-workflow", "inspect", "queue", "approve", "continue", "inspect-conformance", "create-recipe", "inspect-recipe", "validate-recipe", "approve-recipe", "register-assembly", "checkpoint-status", "write-checkpoints", "invalidate-stage", "mark-reviewed", "explain-stale", "resume-from-stage", "reuse-base-checkpoint", "prepare-conformance", "generate-proxy", "approve-conformance"]
	if arguments.is_empty() or arguments[0] not in commands:
		return {"ok": false, "error": "Usage: %s --character-id ID [options]" % "|".join(PackedStringArray(commands))}
	var result := {
		"ok": true,
		"command": arguments[0],
		"values": {},
		"support_report": false
	}
	var index := 1
	while index < arguments.size():
		if arguments[index] == "--support-report":
			result.support_report = true
			index += 1
			continue
		if index + 1 >= arguments.size():
			return {"ok": false, "error": "Missing value for %s" % arguments[index]}
		var option := arguments[index]
		var value := arguments[index + 1]
		match option:
			"--character-id": result.values["character_id"] = value
			"--display-name": result.values["display_name"] = value
			"--prompt": result.values["prompt"] = value
			"--negative-prompt": result.values["negative_prompt"] = value
			"--seed": result.values["seed"] = int(value)
			"--primary-rigged-mesh":
				_ensure_rigged_meshes(result.values)
				result.values.rigged_meshes["primary"] = value
			"--secondary-rigged-mesh":
				_ensure_rigged_meshes(result.values)
				result.values.rigged_meshes["secondary"] = value
			"--role":
				_ensure_metadata(result.values)
				result.values.metadata["role"] = value
			"--style":
				_ensure_metadata(result.values)
				result.values.metadata["style"] = value
			"--animation-asset": result.values["animation_asset"] = value
			"--version": result.values["version"] = value
			"--workflow-path": result.values["workflow_path"] = value
			"--workflow-id": result.values["workflow_id"] = value
			"--workflow-version": result.values["workflow_version"] = value
			"--recipe-version": result.values["recipe_version"] = value
			"--game-mode-profile-id": result.values["game_mode_profile_id"] = value
			"--body-provider": result.values["body_provider"] = value
			"--texture-budget": result.values["texture_budget"] = value
			"--atlas-group": result.values["atlas_group"] = value
			"--assembly-report": result.values["assembly_report"] = value
			"--character-scene": result.values["character_scene"] = value
			"--stage": result.values["stage"] = value
			"--reason": result.values["reason"] = value
			"--source-character-id": result.values["source_character_id"] = value
			"--source-version": result.values["source_version"] = value
			"--warnings-acknowledged": result.values["warnings_acknowledged"] = value.to_lower() in ["1", "true", "yes", "y"]
			"--reconstruction-command": result.values["reconstruction_command"] = value
			"--provider-id": result.values["provider_id"] = value
			"--provider": result.values["provider_id"] = value
			"--input-view": result.values["input_view"] = value
			"--proxy-mesh":
				_ensure_proxy_meshes(result.values)
				result.values.proxy_meshes[value.get_basename()] = value
			"--proxy-license-record": result.values["proxy_license_record"] = value
			"--proxy-commercial-use": result.values["proxy_commercial_use"] = value
			"--proxy-provenance":
				var provenance = JSON.parse_string(value)
				if not provenance is Dictionary:
					return {"ok": false, "error": "--proxy-provenance must be a JSON object"}
				result.values["proxy_provenance"] = provenance
			_: return {"ok": false, "error": "Unknown option: %s" % option}
		index += 2
	if not result.values.has("character_id"):
		return {"ok": false, "error": "--character-id is required"}
	if result.command == "import-workflow" and not result.values.has("workflow_path"):
		return {"ok": false, "error": "--workflow-path is required for import-workflow"}
	if result.command in ["approve", "continue", "prepare-conformance", "generate-proxy", "approve-conformance"] and not result.values.has("version"):
		return {"ok": false, "error": "--version is required for %s" % result.command}
	if result.command in ["invalidate-stage", "mark-reviewed", "resume-from-stage"] and not result.values.has("stage"):
		return {"ok": false, "error": "--stage is required for %s" % result.command}
	if result.command == "reuse-base-checkpoint" and (not result.values.has("source_character_id") or not result.values.has("source_version") or not result.values.has("version")):
		return {"ok": false, "error": "--source-character-id, --source-version, and --version are required for reuse-base-checkpoint"}
	return result


func _ensure_rigged_meshes(values: Dictionary) -> void:
	if not values.has("rigged_meshes"):
		values["rigged_meshes"] = {}


func _ensure_metadata(values: Dictionary) -> void:
	if not values.has("metadata"):
		values["metadata"] = {}


func _ensure_proxy_meshes(values: Dictionary) -> void:
	if not values.has("proxy_meshes"):
		values["proxy_meshes"] = {}


func _load_workflow(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _redact_support_output(value: Dictionary) -> Dictionary:
	var copy := value.duplicate(true)
	return _redact_value(copy, OS.get_environment("HOME").trim_suffix("/"), ProjectSettings.globalize_path("res://").trim_suffix("/"), "")


func _redact_value(value, home: String, project: String, key: String):
	if value is Dictionary:
		for child_key in value.keys():
			value[child_key] = _redact_value(value[child_key], home, project, str(child_key))
		return value
	if value is Array:
		for index in value.size():
			value[index] = _redact_value(value[index], home, project, key)
		return value
	if value is String:
		if key in ["prompt", "positive_prompt", "negative_prompt"]:
			return "<redacted>"
		var text: String = value
		if not project.is_empty():
			text = text.replace(project, "res://")
		if not home.is_empty():
			text = text.replace(home, "<home>")
		return text
	return value
