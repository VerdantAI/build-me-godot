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
		"changed_paths": result.get("changed_paths", [])
	}
	print(JSON.stringify(output))
	quit(0)


func _parse_args(arguments: PackedStringArray) -> Dictionary:
	if arguments.is_empty() or arguments[0] not in ["draft", "import-workflow", "inspect", "queue", "approve", "continue"]:
		return {"ok": false, "error": "Usage: draft|import-workflow|inspect|queue|approve|continue --character-id ID [options]"}
	var result := {
		"ok": true,
		"command": arguments[0],
		"values": {}
	}
	var index := 1
	while index < arguments.size():
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
			"--warnings-acknowledged": result.values["warnings_acknowledged"] = value.to_lower() in ["1", "true", "yes", "y"]
			_: return {"ok": false, "error": "Unknown option: %s" % option}
		index += 2
	if not result.values.has("character_id"):
		return {"ok": false, "error": "--character-id is required"}
	if result.command == "import-workflow" and not result.values.has("workflow_path"):
		return {"ok": false, "error": "--workflow-path is required for import-workflow"}
	if result.command in ["approve", "continue"] and not result.values.has("version"):
		return {"ok": false, "error": "--version is required for %s" % result.command}
	return result


func _ensure_rigged_meshes(values: Dictionary) -> void:
	if not values.has("rigged_meshes"):
		values["rigged_meshes"] = {}


func _ensure_metadata(values: Dictionary) -> void:
	if not values.has("metadata"):
		values["metadata"] = {}


func _load_workflow(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
