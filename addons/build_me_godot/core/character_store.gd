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

	for child in ["prompts", "workflows", "references", "generated", "blender", "conformance", "exports", "reports"]:
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
	var existing := load_character(str(draft.character_id))
	if existing.ok:
		if not draft.has("project_context") and existing.manifest.get("project_context", {}) is Dictionary:
			draft["project_context"] = existing.manifest.project_context
		if not draft.has("rigged_meshes") and existing.manifest.get("rigged_meshes", {}) is Dictionary:
			draft["rigged_meshes"] = existing.manifest.rigged_meshes
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
		"outputs": values.get("outputs", {}),
		"model_provenance": values.get("model_provenance", {})
	}
	var folder_error := _ensure_run_folders(str(manifest.character_id), version)
	if folder_error != OK:
		return {"ok": false, "error": "Could not create reference folders for %s: %s" % [version, error_string(folder_error)]}
	var snapshot_result := _write_workflow_snapshot(str(manifest.character_id), version, values)
	if not snapshot_result.ok:
		return snapshot_result
	if not str(snapshot_result.get("path", "")).is_empty():
		run["workflow_snapshot"] = {
			"path": snapshot_result.path,
			"sha256": snapshot_result.sha256,
			"source_path": str(values.get("workflow_source_path", "")),
			"format": str(values.get("workflow_format", "api"))
		}
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


func complete_generation_run(character_id: String, version: String, prompt_history: Dictionary, comfyui_output_root: String, requirements_path := "") -> Dictionary:
	if comfyui_output_root.strip_edges().is_empty():
		return {"ok": false, "error": "ComfyUI output root is required to copy completed outputs."}
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var images := _collect_comfy_images(prompt_history)
	if images.is_empty():
		return {"ok": false, "error": "ComfyUI history did not include image outputs for %s." % version}
	var references_dir := characters_root.path_join(str(manifest.character_id)).path_join("references").path_join(version)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(references_dir))
	if error != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [references_dir, error_string(error)]}
	var copied_outputs := {}
	var changed_paths := PackedStringArray()
	for image in images:
		var filename := str(image.get("filename", "")).get_file()
		if filename.is_empty():
			continue
		var source := _join_filesystem_path(comfyui_output_root, str(image.get("subfolder", "")), filename)
		var view_name := filename.get_basename()
		var destination := references_dir.path_join(filename)
		var copy_error := _copy_file(source, ProjectSettings.globalize_path(destination))
		if copy_error != OK:
			return {"ok": false, "error": "Could not copy %s to %s: %s" % [source, destination, error_string(copy_error)]}
		copied_outputs[view_name] = destination
		changed_paths.append(destination)
	var updates := {
		"status": "completed",
		"history": prompt_history,
		"outputs": copied_outputs,
		"completed_at": Time.get_datetime_string_from_system(true)
	}
	var provenance := _workflow_provenance(requirements_path)
	if not provenance.is_empty():
		updates["model_provenance"] = provenance
	var saved := update_generation_run(character_id, version, updates)
	if saved.ok:
		changed_paths.append(saved.path)
		saved["changed_paths"] = changed_paths
	return saved


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
	var readiness_warnings := _pipeline_readiness_warnings(manifest)
	if not readiness_warnings.is_empty() and not bool(values.get("warnings_acknowledged", false)):
		return {"ok": false, "error": "Acknowledge next-stage warnings before continuing: %s" % "; ".join(readiness_warnings)}
	var blender_directory := characters_root.path_join(str(manifest.character_id)).path_join("blender").path_join(selected_version)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blender_directory))
	if error != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [blender_directory, error_string(error)]}
	var reference_input_path := blender_directory.path_join("reference_inputs.json")
	var mesh_guidance_path := blender_directory.path_join("mesh_guidance.json")
	var pose_contract := str(manifest.get("pose_contract", manifest.get("metadata", {}).get("pose_contract", "neutral_a_pose_30deg_v1")))
	var reference_input := {
		"schema_version": SCHEMA_VERSION,
		"character_id": str(manifest.character_id),
		"display_name": str(manifest.get("display_name", "")),
		"version": selected_version,
		"pose_contract": pose_contract,
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
	file.close()
	var targets := _field_engineer_targets(manifest, selected_run)
	var mesh_guidance := {
		"schema_version": SCHEMA_VERSION,
		"character_id": str(manifest.character_id),
		"reference_version": selected_version,
		"status": "pipeline_guidance_prepared",
		"pose_contract": pose_contract,
		"source_references": selected_run.outputs,
		"rigged_meshes": rigged_meshes,
		"view_placement": {
			"front": {"plane": "XZ", "normal_axis": "-Z", "pose_contract": pose_contract},
			"right": {"plane": "YZ", "normal_axis": "-X", "pose_contract": pose_contract},
			"back": {"plane": "XZ", "normal_axis": "Z", "pose_contract": pose_contract},
			"left": {"plane": "YZ", "normal_axis": "X", "pose_contract": pose_contract}
		},
		"scale_alignment": {
			"unit": "meters",
			"origin": "feet_center_ground",
			"height_m": float(manifest.get("blender", {}).get("height_m", 1.78)),
			"pose_contract": pose_contract
		},
		"prompt_targets": targets,
		"secondary_asset_candidates": targets.get("props", []),
		"validation_constraints": _source_reference_validation_constraints(pose_contract),
		"changed_paths": PackedStringArray([mesh_guidance_path])
	}
	var write_result := _write_json(mesh_guidance_path, mesh_guidance)
	if not write_result.ok:
		return write_result
	manifest["stage"] = "pipeline_enabled"
	manifest["pipeline"] = {
		"enabled_at": Time.get_datetime_string_from_system(true),
		"approved_version": selected_version,
		"warnings_acknowledged": bool(values.get("warnings_acknowledged", false)),
		"readiness_warnings": readiness_warnings,
		"blender_reference_input": reference_input_path,
		"mesh_guidance_path": mesh_guidance_path
	}
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([loaded.path, reference_input_path, mesh_guidance_path])
		saved["mesh_guidance"] = mesh_guidance
	return saved


func prepare_conformance(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var selected_version := str(generation.get("selected_version", ""))
	if values.has("version") and not str(values.version).strip_edges().is_empty():
		selected_version = str(values.version).strip_edges()
	if selected_version.is_empty():
		return {"ok": false, "error": "Approve a completed reference run before preparing conformance."}
	if selected_version != str(generation.get("selected_version", "")):
		return {"ok": false, "error": "Conformance version must match the approved reference version: %s" % str(generation.get("selected_version", ""))}
	var selected_run := _find_generation_run(manifest, selected_version)
	if selected_run.is_empty():
		return {"ok": false, "error": "Generation version not found: %s" % selected_version}
	if str(selected_run.get("status", "")) != "completed":
		return {"ok": false, "error": "Generation version must be completed before conformance: %s" % selected_version}
	if not selected_run.has("outputs") or not (selected_run.outputs is Dictionary) or selected_run.outputs.is_empty():
		return {"ok": false, "error": "Generation version has no recorded outputs: %s" % selected_version}
	var rigged_meshes := _rigged_meshes_from_values(manifest)
	if str(rigged_meshes.primary).strip_edges().is_empty() or str(rigged_meshes.secondary).strip_edges().is_empty():
		return {"ok": false, "error": "Both rigged mesh slots are required before conformance."}
	var pose_contract := str(manifest.get("pose_contract", manifest.get("metadata", {}).get("pose_contract", "neutral_a_pose_30deg_v1")))
	if pose_contract != "neutral_a_pose_30deg_v1":
		return {"ok": false, "error": "Conformance requires neutral_a_pose_30deg_v1; found %s." % pose_contract}
	var provider_validation := _validate_conformance_provider_values(values)
	if not provider_validation.ok:
		return provider_validation

	var conformance_directory := characters_root.path_join(str(manifest.character_id)).path_join("conformance").path_join(selected_version)
	var error := _ensure_conformance_folders(str(manifest.character_id), selected_version)
	if error != OK:
		return {"ok": false, "error": "Could not create conformance folders for %s: %s" % [selected_version, error_string(error)]}

	var providers := _conformance_providers(values, manifest, selected_version)
	var targets := _field_engineer_targets(manifest, selected_run)
	var validation_constraints := _source_reference_validation_constraints(pose_contract)
	var plan_path := conformance_directory.path_join("conformance_plan.json")
	var provider_inputs_path := conformance_directory.path_join("provider_inputs.json")
	var validation_report_path := conformance_directory.path_join("reports").path_join("validation.json")
	var changed_paths := PackedStringArray()
	var provider_inputs := {
		"schema_version": SCHEMA_VERSION,
		"character_id": str(manifest.character_id),
		"reference_version": selected_version,
		"source_references": selected_run.outputs,
		"normalized_inputs": selected_run.outputs,
		"providers": providers,
		"automatic_downloads_allowed": false
	}
	var write_result := _write_json(provider_inputs_path, provider_inputs)
	if not write_result.ok:
		return write_result
	changed_paths.append(provider_inputs_path)
	var validation_report := {
		"schema_version": SCHEMA_VERSION,
		"status": "pass",
			"checks": [
				{"id": "conformance.source_meshes_immutable", "status": "pass"},
				{"id": "conformance.proxy_mesh_reference_only", "status": "pass"},
				{"id": "conformance.pose_contract", "status": "pass", "expected": "neutral_a_pose_30deg_v1", "detected": pose_contract}
			],
		"review_notes": targets.get("review_notes", [])
	}
	write_result = _write_json(validation_report_path, validation_report)
	if not write_result.ok:
		return write_result
	changed_paths.append(validation_report_path)
	changed_paths.append(plan_path)
	var plan := {
		"schema_version": SCHEMA_VERSION,
		"character_id": str(manifest.character_id),
		"reference_version": selected_version,
		"status": "conformance_prepared",
		"pose_contract": pose_contract,
		"source_references": selected_run.outputs,
		"rigged_meshes": rigged_meshes,
		"providers": providers,
		"field_engineer_targets": targets,
		"provider_inputs": provider_inputs_path,
		"validation_report": validation_report_path,
		"validation_constraints": validation_constraints,
		"paths": {
			"root": conformance_directory,
			"proxy_meshes": conformance_directory.path_join("proxy_meshes"),
			"overlays": conformance_directory.path_join("overlays"),
			"reports": conformance_directory.path_join("reports")
		},
		"changed_paths": changed_paths
	}
	write_result = _write_json(plan_path, plan)
	if not write_result.ok:
		return write_result
	manifest["stage"] = "conformance_prepared"
	manifest["conformance"] = {
		"status": "conformance_prepared",
		"selected_version": selected_version,
		"approved": false,
		"plan_path": plan_path,
		"provider_inputs_path": provider_inputs_path,
		"validation_report_path": validation_report_path,
		"providers": providers,
		"changed_paths": changed_paths
	}
	var saved := save_character(manifest)
	if saved.ok:
		changed_paths.append(saved.path)
		saved["changed_paths"] = changed_paths
		saved["conformance_plan"] = plan
	return saved


func inspect_conformance(character_id: String, version := "") -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var conformance: Dictionary = manifest.get("conformance", {})
	var selected_version := str(version).strip_edges()
	if selected_version.is_empty():
		selected_version = str(conformance.get("selected_version", manifest.get("generation", {}).get("selected_version", "")))
	var plan_path := str(conformance.get("plan_path", ""))
	if plan_path.is_empty() and not selected_version.is_empty():
		plan_path = characters_root.path_join(str(manifest.character_id)).path_join("conformance").path_join(selected_version).path_join("conformance_plan.json")
	var plan := _load_json(plan_path) if not plan_path.is_empty() else {}
	return {
		"ok": true,
		"path": loaded.path,
		"manifest": manifest,
		"conformance_plan_path": plan_path,
		"conformance_plan": plan
	}


func generate_proxy(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var conformance: Dictionary = manifest.get("conformance", {})
	var selected_version := str(values.get("version", conformance.get("selected_version", ""))).strip_edges()
	if selected_version.is_empty():
		return {"ok": false, "error": "Prepare conformance before proxy generation."}
	if selected_version != str(conformance.get("selected_version", "")):
		return {"ok": false, "error": "Conformance version not prepared: %s" % selected_version}
	var provider_id := str(values.get("provider_id", "triposr")).strip_edges()
	if provider_id.is_empty():
		provider_id = "triposr"
	if _rejected_conformance_provider_ids().has(provider_id):
		return {"ok": false, "error": "Rejected conformance provider cannot be used: %s" % provider_id}
	if not _allowed_conformance_provider_ids().has(provider_id) or provider_id == "external_proxy_mesh":
		return {"ok": false, "error": "Automated proxy generation is not supported for provider: %s" % provider_id}
	var plan_path := str(conformance.get("plan_path", ""))
	if plan_path.is_empty() or not FileAccess.file_exists(plan_path):
		return {"ok": false, "error": "Conformance plan is missing: %s" % plan_path}
	var plan := _load_json(plan_path)
	if plan.is_empty():
		return {"ok": false, "error": "Conformance plan could not be loaded: %s" % plan_path}
	var provider_inputs_path := str(plan.get("provider_inputs", conformance.get("provider_inputs_path", "")))
	if provider_inputs_path.is_empty() or not FileAccess.file_exists(provider_inputs_path):
		return {"ok": false, "error": "Provider inputs are missing: %s" % provider_inputs_path}
	var provider_inputs := _load_json(provider_inputs_path)
	if provider_inputs.is_empty():
		return {"ok": false, "error": "Provider inputs could not be loaded: %s" % provider_inputs_path}
	var command := _reconstruction_command_for_provider(provider_id, values, plan, manifest)
	var input_selection := _select_proxy_input(provider_inputs, str(values.get("input_view", "")).strip_edges())
	var conformance_directory := characters_root.path_join(str(manifest.character_id)).path_join("conformance").path_join(selected_version)
	var output_path := conformance_directory.path_join("proxy_meshes").path_join("%s_%s.glb" % [provider_id, str(input_selection.get("view", "input"))])
	var metadata_path := conformance_directory.path_join("reports").path_join("%s_%s_metadata.json" % [provider_id, str(input_selection.get("view", "input"))])
	var attempt_report_path := conformance_directory.path_join("reports").path_join("%s_%s_proxy_generation.json" % [provider_id, str(input_selection.get("view", "input"))])
	if command.is_empty():
		var missing_command_report := _proxy_attempt_report(provider_id, "failed", selected_version, input_selection, output_path, metadata_path, command, -1, "No reconstruction command is configured.")
		_write_json(attempt_report_path, missing_command_report)
		return {"ok": false, "error": "No reconstruction command is configured for %s." % provider_id, "changed_paths": PackedStringArray([attempt_report_path])}
	if str(input_selection.get("path", "")).is_empty():
		var missing_input_report := _proxy_attempt_report(provider_id, "failed", selected_version, input_selection, output_path, metadata_path, command, -1, "No provider input image is available.")
		_write_json(attempt_report_path, missing_input_report)
		return {"ok": false, "error": "No provider input image is available for proxy generation.", "changed_paths": PackedStringArray([attempt_report_path])}
	var input_absolute := ProjectSettings.globalize_path(str(input_selection.path))
	if not FileAccess.file_exists(str(input_selection.path)):
		var missing_file_report := _proxy_attempt_report(provider_id, "failed", selected_version, input_selection, output_path, metadata_path, command, -1, "Provider input image does not exist: %s" % str(input_selection.path))
		_write_json(attempt_report_path, missing_file_report)
		return {"ok": false, "error": "Provider input image does not exist: %s" % str(input_selection.path), "changed_paths": PackedStringArray([attempt_report_path])}
	var output_absolute := ProjectSettings.globalize_path(output_path)
	var metadata_absolute := ProjectSettings.globalize_path(metadata_path)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	DirAccess.make_dir_recursive_absolute(metadata_absolute.get_base_dir())
	var output := []
	var args := ["--input", input_absolute, "--output", output_absolute, "--metadata-output", metadata_absolute]
	var exit_code := OS.execute(command, args, output, true)
	var output_text := "\n".join(PackedStringArray(output))
	var generated := exit_code == 0 and FileAccess.file_exists(output_path)
	var report := _proxy_attempt_report(provider_id, "generated" if generated else "failed", selected_version, input_selection, output_path, metadata_path, command, exit_code, output_text)
	var write_result := _write_json(attempt_report_path, report)
	if not write_result.ok:
		return write_result
	if not generated:
		conformance["status"] = "conformance_proxy_failed"
		conformance["last_proxy_attempt_report"] = attempt_report_path
		manifest["conformance"] = conformance
		manifest["stage"] = "conformance_proxy_failed"
		var failed_saved := save_character(manifest)
		var failed_paths := PackedStringArray([attempt_report_path])
		if failed_saved.ok:
			failed_paths.append(failed_saved.path)
		return {"ok": false, "error": "Proxy provider failed or did not write expected mesh: %s" % output_path, "changed_paths": failed_paths}
	var providers: Array = plan.get("providers", [])
	_update_generated_proxy_provider(providers, provider_id, command, input_selection, output_path, metadata_path, attempt_report_path)
	plan["providers"] = providers
	plan["status"] = "conformance_proxy_generated"
	plan["proxy_generation_report"] = attempt_report_path
	var plan_changed_paths := _packed_paths(plan.get("changed_paths", []))
	for path in [output_path, metadata_path, attempt_report_path, plan_path]:
		if not plan_changed_paths.has(path):
			plan_changed_paths.append(path)
	plan["changed_paths"] = plan_changed_paths
	write_result = _write_json(plan_path, plan)
	if not write_result.ok:
		return write_result
	conformance["status"] = "conformance_proxy_generated"
	conformance["approved"] = false
	conformance["proxy_generation_report"] = attempt_report_path
	conformance["providers"] = providers
	conformance["changed_paths"] = plan_changed_paths
	manifest["conformance"] = conformance
	manifest["stage"] = "conformance_proxy_generated"
	var saved := save_character(manifest)
	if saved.ok:
		var changed_paths := plan_changed_paths.duplicate()
		changed_paths.append(saved.path)
		saved["changed_paths"] = changed_paths
		saved["conformance_plan"] = plan
	return saved


func approve_conformance(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var conformance: Dictionary = manifest.get("conformance", {})
	var selected_version := str(values.get("version", conformance.get("selected_version", ""))).strip_edges()
	if selected_version.is_empty():
		return {"ok": false, "error": "Prepare conformance before approval."}
	if selected_version != str(conformance.get("selected_version", "")):
		return {"ok": false, "error": "Conformance version not prepared: %s" % selected_version}
	var plan_path := str(conformance.get("plan_path", ""))
	var validation_report_path := str(conformance.get("validation_report_path", ""))
	if plan_path.is_empty() or not FileAccess.file_exists(plan_path):
		return {"ok": false, "error": "Conformance plan is missing: %s" % plan_path}
	if validation_report_path.is_empty() or not FileAccess.file_exists(validation_report_path):
		return {"ok": false, "error": "Conformance validation report is missing: %s" % validation_report_path}
	var plan := _load_json(plan_path)
	if plan.is_empty() or not plan.get("providers", []) is Array or plan.get("providers", []).is_empty():
		return {"ok": false, "error": "Conformance plan has no provider provenance."}
	var provider_error := _validate_conformance_plan_providers(plan.get("providers", []))
	if not provider_error.is_empty():
		return {"ok": false, "error": provider_error}
	var report := _load_json(validation_report_path)
	if report.get("status", "") != "pass":
		return {"ok": false, "error": "Conformance validation report is not passing: %s" % validation_report_path}
	plan["status"] = "conformance_approved"
	var write_result := _write_json(plan_path, plan)
	if not write_result.ok:
		return write_result
	conformance["status"] = "conformance_approved"
	conformance["approved"] = true
	conformance["approved_at"] = Time.get_datetime_string_from_system(true)
	manifest["conformance"] = conformance
	manifest["stage"] = "conformance_approved"
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([plan_path, saved.path])
		saved["conformance_plan"] = plan
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
				actions.append("prepare-conformance:%s" % selected_version)
	var conformance: Dictionary = manifest.get("conformance", {})
	if str(conformance.get("status", "")) == "conformance_prepared":
		actions.append("generate-proxy:%s" % str(conformance.get("selected_version", "")))
		actions.append("approve-conformance:%s" % str(conformance.get("selected_version", "")))
	elif str(conformance.get("status", "")) == "conformance_proxy_generated":
		actions.append("approve-conformance:%s" % str(conformance.get("selected_version", "")))
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
		"conformance": {
			"status": "conformance_draft",
			"selected_version": "",
			"approved": false,
			"plan_path": "",
			"provider_inputs_path": "",
			"validation_report_path": "",
			"providers": [],
			"changed_paths": []
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
	if not manifest.has("conformance") or not (manifest.conformance is Dictionary):
		manifest["conformance"] = {
			"status": "conformance_draft",
			"selected_version": "",
			"approved": false,
			"plan_path": "",
			"provider_inputs_path": "",
			"validation_report_path": "",
			"providers": [],
			"changed_paths": []
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


func _collect_comfy_images(prompt_history: Dictionary) -> Array[Dictionary]:
	var images: Array[Dictionary] = []
	var outputs: Dictionary = prompt_history.get("outputs", {})
	for node_id in outputs:
		var node_output = outputs[node_id]
		if not node_output is Dictionary:
			continue
		for image in node_output.get("images", []):
			if image is Dictionary:
				images.append(image)
	return images


func _workflow_provenance(requirements_path: String) -> Dictionary:
	if requirements_path.strip_edges().is_empty():
		return {}
	var file := FileAccess.open(requirements_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	return {
		"workflow_id": str(parsed.get("workflow_id", "")),
		"workflow_file": str(parsed.get("workflow_file", "")),
		"capability": str(parsed.get("capability", "")),
		"model_artifacts": parsed.get("model_artifacts", []),
		"helper": parsed.get("helper", {}),
		"recommended_memory": parsed.get("recommended_memory", {})
	}


func _pipeline_readiness_warnings(manifest: Dictionary) -> PackedStringArray:
	var warnings := PackedStringArray()
	var reconstruction: Dictionary = manifest.get("reconstruction", {})
	if str(reconstruction.get("command", "")).strip_edges().is_empty():
		warnings.append("Reconstruction command is not configured.")
	var project_context: Dictionary = manifest.get("project_context", {})
	if str(project_context.get("animation_library", "")).strip_edges().is_empty():
		warnings.append("Animation library is not configured.")
	return warnings


func _source_reference_validation_constraints(pose_contract: String) -> Dictionary:
	return {
		"source_meshes_immutable": true,
		"preserve_skeleton_profile_humanoid": true,
		"preserve_stable_socket_names": true,
		"pose_contract": pose_contract,
		"production_topology_from_proxy_allowed": false
	}


func _conformance_providers(values: Dictionary, manifest: Dictionary, version: String) -> Array[Dictionary]:
	var providers: Array[Dictionary] = []
	var reconstruction: Dictionary = manifest.get("reconstruction", {})
	var command := str(values.get("reconstruction_command", reconstruction.get("command", ""))).strip_edges()
	providers.append({
		"provider_id": "triposr",
		"role": "proxy_reconstruction",
		"status": "configured" if not command.is_empty() else "manual_setup_required",
		"license_record": "TripoSR",
		"commercial_use": true,
		"automatic_downloads_allowed": false,
		"command": command,
		"outputs": {}
	})
	var proxy_meshes: Dictionary = values.get("proxy_meshes", {})
	if not proxy_meshes.is_empty():
		providers.append({
			"provider_id": "external_proxy_mesh",
			"role": "manual_proxy_import",
			"status": "provided",
			"license_record": str(values.get("proxy_license_record", "user_supplied")),
			"commercial_use": str(values.get("proxy_commercial_use", "user_review_required")),
			"automatic_downloads_allowed": false,
			"outputs": proxy_meshes,
			"provenance": values.get("proxy_provenance", {})
		})
	return providers


func _validate_conformance_provider_values(values: Dictionary) -> Dictionary:
	if values.has("provider_id") and _rejected_conformance_provider_ids().has(str(values.provider_id)):
		return {"ok": false, "error": "Rejected conformance provider cannot be used: %s" % str(values.provider_id)}
	var proxy_meshes: Dictionary = values.get("proxy_meshes", {})
	if proxy_meshes.is_empty():
		return {"ok": true}
	if str(values.get("proxy_license_record", "")).strip_edges().is_empty():
		return {"ok": false, "error": "Manual proxy meshes require --proxy-license-record."}
	if not values.has("proxy_provenance") or not (values.proxy_provenance is Dictionary) or values.proxy_provenance.is_empty():
		return {"ok": false, "error": "Manual proxy meshes require --proxy-provenance JSON."}
	for key in proxy_meshes:
		var path := str(proxy_meshes[key])
		var extension := path.get_extension().to_lower()
		if extension not in ["glb", "gltf", "obj"]:
			return {"ok": false, "error": "Proxy mesh must be .glb, .gltf, or .obj: %s" % path}
		if path.begins_with("res://addons/") or path.begins_with("addons/"):
			return {"ok": false, "error": "Proxy mesh must not be stored inside the addon package: %s" % path}
	return {"ok": true}


func _validate_conformance_plan_providers(providers: Array) -> String:
	var allowed := _allowed_conformance_provider_ids()
	for provider in providers:
		if not provider is Dictionary:
			return "Conformance provider provenance is malformed."
		var provider_id := str(provider.get("provider_id", ""))
		if provider_id.is_empty():
			return "Conformance provider provenance is missing provider_id."
		if _rejected_conformance_provider_ids().has(provider_id):
			return "Rejected conformance provider cannot be approved: %s" % provider_id
		if not allowed.has(provider_id):
			return "Unknown conformance provider cannot be approved: %s" % provider_id
	return ""


func _reconstruction_command_for_provider(provider_id: String, values: Dictionary, plan: Dictionary, manifest: Dictionary) -> String:
	var command := str(values.get("reconstruction_command", "")).strip_edges()
	if not command.is_empty():
		return command
	for provider in plan.get("providers", []):
		if provider is Dictionary and str(provider.get("provider_id", "")) == provider_id:
			command = str(provider.get("command", "")).strip_edges()
			if not command.is_empty():
				return command
	var reconstruction: Dictionary = manifest.get("reconstruction", {})
	return str(reconstruction.get("command", "")).strip_edges()


func _select_proxy_input(provider_inputs: Dictionary, requested_view: String) -> Dictionary:
	var references: Dictionary = provider_inputs.get("normalized_inputs", provider_inputs.get("source_references", {}))
	if references.is_empty():
		return {"view": requested_view, "path": ""}
	if not requested_view.is_empty() and references.has(requested_view):
		return {"view": requested_view, "path": str(references[requested_view])}
	for view in ["front", "canonical", "front_3q", "contact_sheet", "turnaround_sheet"]:
		if references.has(view):
			return {"view": view, "path": str(references[view])}
	var keys := references.keys()
	keys.sort()
	if keys.is_empty():
		return {"view": requested_view, "path": ""}
	var first_key := str(keys[0])
	return {"view": first_key, "path": str(references[first_key])}


func _proxy_attempt_report(provider_id: String, status: String, version: String, input_selection: Dictionary, output_path: String, metadata_path: String, command: String, exit_code: int, output_text: String) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"status": status,
		"provider_id": provider_id,
		"reference_version": version,
		"role": "proxy_reconstruction",
		"license_record": "TripoSR" if provider_id == "triposr" else "user_review_required",
		"commercial_use": true if provider_id == "triposr" else "user_review_required",
		"automatic_downloads_allowed": false,
		"input": {
			"view": str(input_selection.get("view", "")),
			"path": str(input_selection.get("path", ""))
		},
		"outputs": {
			"proxy_mesh": output_path,
			"metadata": metadata_path
		},
		"command": command,
		"exit_code": exit_code,
		"output_summary": output_text.substr(0, 4000),
		"generated_at": Time.get_datetime_string_from_system(true)
	}


func _update_generated_proxy_provider(providers: Array, provider_id: String, command: String, input_selection: Dictionary, output_path: String, metadata_path: String, report_path: String) -> void:
	var provider_record := {
		"provider_id": provider_id,
		"role": "proxy_reconstruction",
		"status": "generated",
		"license_record": "TripoSR" if provider_id == "triposr" else "user_review_required",
		"commercial_use": true if provider_id == "triposr" else "user_review_required",
		"automatic_downloads_allowed": false,
		"command": command,
		"inputs": {
			"view": str(input_selection.get("view", "")),
			"image": str(input_selection.get("path", ""))
		},
		"outputs": {
			"%s_proxy_glb" % str(input_selection.get("view", "input")): output_path
		},
		"metadata": metadata_path,
		"report": report_path,
		"provenance": {
			"source": "configured_local_command",
			"generated_at": Time.get_datetime_string_from_system(true)
		}
	}
	for index in providers.size():
		if providers[index] is Dictionary and str(providers[index].get("provider_id", "")) == provider_id:
			providers[index] = provider_record
			return
	providers.append(provider_record)


func _packed_paths(value) -> PackedStringArray:
	var paths := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for item in value:
			paths.append(str(item))
	return paths


func _allowed_conformance_provider_ids() -> PackedStringArray:
	return PackedStringArray(["triposr", "external_proxy_mesh"])


func _rejected_conformance_provider_ids() -> PackedStringArray:
	return PackedStringArray(["stable_fast_3d", "hunyuan3d_2"])


func _field_engineer_targets(manifest: Dictionary, run: Dictionary) -> Dictionary:
	var metadata: Dictionary = manifest.get("metadata", {})
	var text := " ".join(PackedStringArray([
		str(manifest.get("display_name", "")),
		str(metadata.get("role", "")),
		str(metadata.get("style", "")),
		str(manifest.get("prompt", "")),
		str(run.get("positive_prompt", ""))
	])).to_lower()
	var silhouette := PackedStringArray()
	var materials := PackedStringArray()
	var colors := PackedStringArray()
	var props: Array[Dictionary] = []
	var review_notes := PackedStringArray()
	_add_if_keyword(text, silhouette, "helmet", ["helmet", "hardhat", "hard hat"])
	_add_if_keyword(text, silhouette, "vest", ["vest", "high visibility", "hi-vis", "safety jacket"])
	_add_if_keyword(text, silhouette, "tool_belt", ["tool belt", "utility belt"])
	_add_if_keyword(text, silhouette, "boots", ["boots", "work boots"])
	_add_if_keyword(text, silhouette, "gloves", ["gloves"])
	_add_if_keyword(text, materials, "high_visibility_fabric", ["high visibility", "hi-vis", "safety yellow", "reflective"])
	_add_if_keyword(text, materials, "rubber_or_leather_boots", ["boots"])
	_add_if_keyword(text, materials, "plastic_helmet", ["helmet", "hardhat", "hard hat"])
	_add_if_keyword(text, colors, "safety_yellow", ["safety yellow", "yellow", "hi-vis"])
	_add_if_keyword(text, colors, "safety_orange", ["safety orange", "orange"])
	_add_if_keyword(text, colors, "white_hardhat", ["white hardhat", "white helmet", "white hard hat"])
	if _contains_any(text, ["clipboard"]):
		props.append({"asset_id": "clipboard", "socket": "hand_l"})
	if _contains_any(text, ["tablet"]):
		props.append({"asset_id": "tablet", "socket": "hand_l"})
	if _contains_any(text, ["radio"]):
		props.append({"asset_id": "radio", "socket": "chest"})
	if _contains_any(text, ["tool", "wrench", "scanner"]):
		props.append({"asset_id": "tool", "socket": "hand_r"})
	if silhouette.is_empty():
		silhouette.append_array(["helmet", "vest", "tool_belt", "boots"])
		review_notes.append("Default field-engineer silhouette targets were used because prompt metadata did not name specific workwear.")
	if materials.is_empty():
		materials.append_array(["high_visibility_fabric", "durable_workwear", "rubber_or_leather_boots"])
	if colors.is_empty():
		colors.append_array(["safety_yellow", "dark_gray", "white_hardhat"])
	if props.is_empty():
		props.append({"asset_id": "clipboard", "socket": "hand_l", "review_required": true})
		props.append({"asset_id": "radio", "socket": "chest", "review_required": true})
	var avoid := PackedStringArray([
		"fused_tools",
		"unreadable_logos",
		"asymmetrical_boots",
		"malformed_hands",
		"vest_geometry_baked_into_skin"
	])
	return {
		"schema": "field_engineer_v1",
		"silhouette": silhouette,
		"materials": materials,
		"colors": colors,
		"props": props,
		"avoid": avoid,
		"review_notes": review_notes
	}


func _add_if_keyword(text: String, target: PackedStringArray, value: String, keywords: Array) -> void:
	if _contains_any(text, keywords) and not target.has(value):
		target.append(value)


func _contains_any(text: String, keywords: Array) -> bool:
	for keyword in keywords:
		if text.contains(str(keyword)):
			return true
	return false


func _join_filesystem_path(root: String, subfolder: String, filename: String) -> String:
	var path := root.trim_suffix("/")
	for part in subfolder.replace("\\", "/").split("/", false):
		path = path.path_join(part)
	return path.path_join(filename)


func _copy_file(source: String, destination: String) -> Error:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return FileAccess.get_open_error()
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_buffer(input.get_buffer(input.get_length()))
	return OK


func _write_json(path: String, value: Dictionary) -> Dictionary:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [path.get_base_dir(), error_string(error)]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s." % path}
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return {"ok": true}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_workflow_snapshot(character_id: String, version: String, values: Dictionary) -> Dictionary:
	var workflow = values.get("workflow_snapshot", {})
	if not (workflow is Dictionary) or workflow.is_empty():
		return {"ok": true, "path": "", "sha256": ""}
	var path := characters_root.path_join(character_id).path_join("workflows").path_join("%s_api.json" % version)
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK:
		return {"ok": false, "error": "Could not create workflow snapshot directory: %s" % error_string(error)}
	var text := JSON.stringify(workflow, "  ") + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write workflow snapshot: %s" % path}
	file.store_string(text)
	file.close()
	return {"ok": true, "path": path, "sha256": text.sha256_text()}


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


func _ensure_conformance_folders(character_id: String, version: String) -> Error:
	var conformance_dir := characters_root.path_join(character_id).path_join("conformance").path_join(version)
	for child in ["", "proxy_meshes", "overlays", "reports"]:
		var path := conformance_dir if child.is_empty() else conformance_dir.path_join(child)
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		if error != OK:
			return error
	return OK
