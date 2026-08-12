@tool
extends RefCounted

const SCHEMA_VERSION := 1
const WORKSPACE_ROOT := "res://build_me_godot"
const DEFAULT_PRIMARY_RIGGED_MESH := "res://build_me_godot/rigs/base_humanoid.glb"
const DEFAULT_SECONDARY_RIGGED_MESH := "res://build_me_godot/rigs/reference_proxy.glb"

var workspace_root: String
var characters_root: String


func _init(root := WORKSPACE_ROOT) -> void:
	workspace_root = root.trim_suffix("/")
	characters_root = workspace_root.path_join("characters")


func save_character(values: Dictionary) -> Dictionary:
	var character_id := _normalize_id(str(values.get("character_id", "")))
	if character_id.is_empty():
		return {"ok": false, "error": "Character ID is required."}

	var character_dir := characters_root.path_join(character_id)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(character_dir))
	if error != OK:
		return {"ok": false, "error": "Could not create %s." % character_dir}

	for child in ["prompts", "workflows", "references", "generated", "blender", "exports", "reports"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(character_dir.path_join(child)))

	var path := character_dir.path_join("character.json")
	var manifest := _default_manifest(character_id)
	if FileAccess.file_exists(path):
		var existing_file := FileAccess.open(path, FileAccess.READ)
		var existing = JSON.parse_string(existing_file.get_as_text())
		if existing is Dictionary and int(existing.get("schema_version", 0)) == SCHEMA_VERSION:
			manifest = existing
	manifest.merge(values, true)
	manifest = _normalize_manifest(manifest)
	manifest["schema_version"] = SCHEMA_VERSION
	manifest["character_id"] = character_id
	manifest["updated_at"] = Time.get_datetime_string_from_system(true)

	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s." % path}
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()

	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)
	if error != OK:
		return {"ok": false, "error": "Could not finalize %s." % path}
	return {"ok": true, "path": path, "manifest": manifest}


func save_draft(values: Dictionary) -> Dictionary:
	var draft := values.duplicate(true)
	var character_name := str(draft.get("character_name", draft.get("display_name", draft.get("character_id", "")))).strip_edges()
	if str(draft.get("character_id", "")).strip_edges().is_empty():
		draft["character_id"] = character_name
	if str(draft.get("display_name", "")).strip_edges().is_empty():
		draft["display_name"] = character_name
	draft["project_context"] = _project_context(draft)
	draft["rigged_meshes"] = _rigged_meshes_from_values(draft)
	return save_character(draft)


func validate_draft(values: Dictionary, require_prompt := false) -> PackedStringArray:
	var errors := PackedStringArray()
	var character_name := str(values.get("character_id", values.get("character_name", values.get("display_name", "")))).strip_edges()
	if character_name.is_empty():
		errors.append("Character ID or name is required.")
	elif _normalize_id(character_name).is_empty():
		errors.append("Character ID can contain only letters, numbers, and underscores after normalization.")
	var rigged_meshes := _rigged_meshes_from_values(values)
	if str(rigged_meshes.primary).strip_edges().is_empty():
		errors.append("Primary rigged mesh is required.")
	if str(rigged_meshes.secondary).strip_edges().is_empty():
		errors.append("Secondary rigged mesh is required.")
	if require_prompt and str(values.get("prompt", "")).strip_edges().is_empty():
		errors.append("Character prompt is required before generation.")
	return errors


func next_version(manifest: Dictionary) -> String:
	var highest := 0
	var generation: Dictionary = manifest.get("generation", {})
	for run in generation.get("runs", []):
		if not run is Dictionary:
			continue
		var version := str(run.get("version", ""))
		if version.begins_with("v") and version.substr(1).is_valid_int():
			highest = maxi(highest, int(version.substr(1)))
	return "v%d" % (highest + 1)


func create_generation_run(character_id: String, values: Dictionary) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var runs: Array = generation.get("runs", [])
	var version := next_version(manifest)
	var run_id := str(values.get("run_id", "run_%s" % Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")))
	var run := {
		"run_id": run_id,
		"version": version,
		"workflow_id": str(values.get("workflow_id", "qwen_blender_reference_set_ui")),
		"workflow_version": str(values.get("workflow_version", "1")),
		"status": str(values.get("status", "draft")),
		"positive_prompt": str(values.get("positive_prompt", manifest.get("prompt", ""))),
		"negative_prompt": str(values.get("negative_prompt", manifest.get("negative_prompt", ""))),
		"seed": int(values.get("seed", manifest.get("seed", 0))),
		"queued_at": str(values.get("queued_at", "")),
		"completed_at": str(values.get("completed_at", "")),
		"outputs": values.get("outputs", {})
	}
	var folder_error := _ensure_run_folders(str(manifest.character_id), version)
	if folder_error != OK:
		return {"ok": false, "error": "Could not create reference folders for %s: %s" % [version, error_string(folder_error)]}
	runs.append(run)
	generation["runs"] = runs
	manifest["generation"] = generation
	return save_character(manifest)


func update_generation_run(character_id: String, version: String, values: Dictionary) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var runs: Array = generation.get("runs", [])
	var found := false
	for index in runs.size():
		if not runs[index] is Dictionary:
			continue
		if str(runs[index].get("version", "")) != version:
			continue
		var run: Dictionary = runs[index]
		run.merge(values, true)
		runs[index] = run
		found = true
		break
	if not found:
		return {"ok": false, "error": "Generation version not found: %s" % version}
	generation["runs"] = runs
	manifest["generation"] = generation
	return save_character(manifest)


func approve_generation_version(character_id: String, version: String) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var found := false
	for run in generation.get("runs", []):
		if run is Dictionary and str(run.get("version", "")) == version:
			found = true
			break
	if not found:
		return {"ok": false, "error": "Generation version not found: %s" % version}
	generation["selected_version"] = version
	manifest["generation"] = generation
	manifest["stage"] = "reference_approved"
	return save_character(manifest)


func register_final_assets(character_id: String, values: Dictionary) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var assets: Dictionary = manifest.get("assets", {})
	if values.has("character_scene"):
		assets["character_scene"] = str(values.character_scene)
	if values.has("animations"):
		assets["animations"] = values.animations
	if values.has("secondary_assets"):
		assets["secondary_assets"] = values.secondary_assets
	manifest["assets"] = assets
	manifest["stage"] = str(values.get("stage", "complete"))
	return save_character(manifest)


func continue_pipeline(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var selected_version := str(generation.get("selected_version", ""))
	if values.has("version") and not str(values.version).strip_edges().is_empty():
		selected_version = str(values.version).strip_edges()
	if selected_version.is_empty():
		return {"ok": false, "error": "Approve a completed reference run before continuing."}
	var selected_run := _find_generation_run(manifest, selected_version)
	if selected_run.is_empty():
		return {"ok": false, "error": "Generation version not found: %s" % selected_version}
	if str(selected_run.get("status", "")) != "completed":
		return {"ok": false, "error": "Generation version must be completed before continuing: %s" % selected_version}
	if not selected_run.has("outputs") or not (selected_run.outputs is Dictionary) or selected_run.outputs.is_empty():
		return {"ok": false, "error": "Generation version has no recorded outputs: %s" % selected_version}
	var rigged_meshes := _rigged_meshes_from_values(manifest)
	if str(rigged_meshes.primary).strip_edges().is_empty() or str(rigged_meshes.secondary).strip_edges().is_empty():
		return {"ok": false, "error": "Both rigged mesh slots are required before continuing."}
	var blender_directory := characters_root.path_join(str(manifest.character_id)).path_join("blender").path_join(selected_version)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blender_directory))
	if error != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [blender_directory, error_string(error)]}
	var reference_input_path := blender_directory.path_join("reference_inputs.json")
	var reference_input := {
		"schema_version": SCHEMA_VERSION,
		"character_id": str(manifest.character_id),
		"display_name": str(manifest.get("display_name", "")),
		"version": selected_version,
		"pose_contract": str(manifest.get("pose_contract", "neutral_a_pose_30deg_v1")),
		"metadata": manifest.get("metadata", {}),
		"rigged_meshes": rigged_meshes,
		"prompt": selected_run.get("positive_prompt", manifest.get("prompt", "")),
		"negative_prompt": selected_run.get("negative_prompt", manifest.get("negative_prompt", "")),
		"seed": int(selected_run.get("seed", manifest.get("seed", 0))),
		"outputs": selected_run.outputs
	}
	var file := FileAccess.open(reference_input_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s." % reference_input_path}
	file.store_string(JSON.stringify(reference_input, "  ") + "\n")
	manifest["stage"] = "pipeline_enabled"
	manifest["pipeline"] = {
		"enabled_at": Time.get_datetime_string_from_system(true),
		"approved_version": selected_version,
		"warnings_acknowledged": bool(values.get("warnings_acknowledged", false)),
		"blender_reference_input": reference_input_path
	}
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([loaded.path, reference_input_path])
	return saved


func available_actions(manifest: Dictionary) -> PackedStringArray:
	var actions := PackedStringArray(["draft", "inspect"])
	var prompt_ready := not str(manifest.get("prompt", "")).strip_edges().is_empty()
	if prompt_ready:
		actions.append("queue")
	var generation: Dictionary = manifest.get("generation", {})
	var selected_version := str(generation.get("selected_version", ""))
	for run in generation.get("runs", []):
		if not run is Dictionary:
			continue
		if str(run.get("status", "")) == "completed":
			actions.append("approve:%s" % str(run.get("version", "")))
			if str(run.get("version", "")) == selected_version and run.get("outputs", {}) is Dictionary and not run.outputs.is_empty():
				actions.append("continue:%s" % selected_version)
	return actions


func load_character(character_id: String) -> Dictionary:
	var normalized_id := _normalize_id(character_id)
	var path := characters_root.path_join(normalized_id).path_join("character.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Character manifest not found: %s" % path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "Invalid character manifest: %s" % path}
	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"ok": false, "error": "Unsupported character schema version."}
	return {"ok": true, "path": path, "manifest": parsed}


func list_characters() -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(characters_root)
	if directory == null:
		return result
	for child in directory.get_directories():
		if FileAccess.file_exists(characters_root.path_join(child).path_join("character.json")):
			result.append(child)
	result.sort()
	return result


func create_from_template(template_path: String) -> Dictionary:
	var file := FileAccess.open(template_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Template not found: %s" % template_path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "Invalid character template: %s" % template_path}
	return save_character(parsed)


func _default_manifest(character_id: String) -> Dictionary:
	var now := Time.get_datetime_string_from_system(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"character_id": character_id,
		"display_name": character_id.replace("_", " ").capitalize(),
		"stage": "draft",
		"project_context": _project_context(),
		"rigged_meshes": {
			"primary": DEFAULT_PRIMARY_RIGGED_MESH,
			"secondary": DEFAULT_SECONDARY_RIGGED_MESH
		},
		"metadata": {
			"role": "",
			"style": "",
			"pose_contract": "neutral_a_pose_30deg_v1"
		},
		"prompt": "",
		"negative_prompt": "",
		"seed": 0,
		"pose_contract": "neutral_a_pose_30deg_v1",
		"workflow": {
			"editor": "res://addons/build_me_godot/workflows/character_turnaround_open.json",
			"canonical": "res://addons/build_me_godot/workflows/canonical_only_api.json",
			"multiview": "res://addons/build_me_godot/workflows/multiview_only_api.json"
		},
		"image": {"width": 768, "height": 1024},
		"reconstruction": {
			"provider": "external",
			"command": ""
		},
		"blender": {
			"height_m": 1.78,
			"triangle_target": 25000
		},
		"artifacts": {},
		"generation": {
			"selected_version": "",
			"runs": []
		},
		"assets": {
			"character_scene": "",
			"animations": [],
			"secondary_assets": []
		},
		"licenses": [],
		"created_at": now,
		"updated_at": now
	}


func _normalize_id(value: String) -> String:
	var normalized := value.strip_edges().to_snake_case()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_"
	for character in normalized:
		if not allowed.contains(character):
			return ""
	return normalized


func _normalize_manifest(manifest: Dictionary) -> Dictionary:
	if not manifest.has("stage"):
		manifest["stage"] = "draft"
	if not manifest.has("project_context") or not (manifest.project_context is Dictionary):
		manifest["project_context"] = _project_context(manifest)
	if not manifest.has("metadata") or not (manifest.metadata is Dictionary):
		manifest["metadata"] = {}
	if not manifest.metadata.has("pose_contract"):
		manifest.metadata["pose_contract"] = str(manifest.get("pose_contract", "neutral_a_pose_30deg_v1"))
	if not manifest.has("rigged_meshes") or not (manifest.rigged_meshes is Dictionary):
		manifest["rigged_meshes"] = {}
	manifest["rigged_meshes"] = _rigged_meshes_from_values(manifest)
	if not manifest.has("generation") or not (manifest.generation is Dictionary):
		manifest["generation"] = _generation_from_values(manifest)
	else:
		var generation: Dictionary = manifest.generation
		if not generation.has("selected_version"):
			generation["selected_version"] = ""
		if not generation.has("runs") or not (generation.runs is Array):
			generation["runs"] = []
		manifest["generation"] = generation
	if not manifest.has("assets") or not (manifest.assets is Dictionary):
		manifest["assets"] = {
			"character_scene": "",
			"animations": [],
			"secondary_assets": []
		}
	return manifest


func _project_context(values: Dictionary = {}) -> Dictionary:
	var context := {
		"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		"workspace_root": workspace_root
	}
	if values.has("project_context") and values.project_context is Dictionary:
		context.merge(values.project_context, true)
	if values.has("animation_asset"):
		context["animation_library"] = str(values.animation_asset)
	return context


func _rigged_meshes_from_values(values: Dictionary) -> Dictionary:
	var existing: Dictionary = values.get("rigged_meshes", {})
	return {
		"primary": str(existing.get("primary", values.get("primary_rigged_mesh", DEFAULT_PRIMARY_RIGGED_MESH))),
		"secondary": str(existing.get("secondary", values.get("secondary_rigged_mesh", DEFAULT_SECONDARY_RIGGED_MESH)))
	}


func _generation_from_values(values: Dictionary) -> Dictionary:
	return {
		"selected_version": str(values.get("selected_version", "")),
		"runs": values.get("runs", [])
	}


func _find_generation_run(manifest: Dictionary, version: String) -> Dictionary:
	var generation: Dictionary = manifest.get("generation", {})
	for run in generation.get("runs", []):
		if run is Dictionary and str(run.get("version", "")) == version:
			return run
	return {}


func _ensure_run_folders(character_id: String, version: String) -> Error:
	var character_dir := characters_root.path_join(character_id)
	for child in [
		"references".path_join(version),
		"blender".path_join(version),
		"reports".path_join(version)
	]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(character_dir.path_join(child)))
		if error != OK:
			return error
	return OK
