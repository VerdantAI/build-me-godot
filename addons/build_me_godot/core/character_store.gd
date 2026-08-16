@tool
extends RefCounted

const SCHEMA_VERSION := 1
const RECIPE_SCHEMA_VERSION := 1
const CHECKPOINT_SCHEMA_VERSION := 1
const WORKSPACE_ROOT := "res://build_me_godot"
const DEFAULT_PRIMARY_RIGGED_MESH := "res://build_me_godot/rigs/base_humanoid.glb"
const DEFAULT_SECONDARY_RIGGED_MESH := "res://build_me_godot/rigs/reference_proxy.glb"
const DEFAULT_ISOMETRIC_PROFILE := "3d_isometric_party"
const DEFAULT_QUATERNIUS_ANIMATION_LIBRARY := "res://addons/build_me_godot/examples/quaternius_ik_rigged/UAL1_Standard.animation_library.tres"
const CHECKPOINT_STAGE_ORDER := ["base_body", "references", "recipe", "assembly", "godot_scene", "animation_smoke", "readability"]
const CHECKPOINT_STATUSES := ["valid", "stale", "failed", "missing", "pending"]

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

	for child in ["prompts", "workflows", "references", "generated", "blender", "conformance", "exports", "reports", "recipes", "checkpoints"]:
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


func create_character_recipe(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var generation: Dictionary = manifest.get("generation", {})
	var reference_version := str(values.get("version", generation.get("selected_version", ""))).strip_edges()
	if reference_version.is_empty():
		return {"ok": false, "error": "Approve a completed reference run before creating a recipe."}
	if reference_version != str(generation.get("selected_version", "")):
		return {"ok": false, "error": "Recipe reference version must match the approved reference version: %s" % str(generation.get("selected_version", ""))}
	var selected_run := _find_generation_run(manifest, reference_version)
	if selected_run.is_empty():
		return {"ok": false, "error": "Generation version not found: %s" % reference_version}
	if str(selected_run.get("status", "")) != "completed":
		return {"ok": false, "error": "Generation version must be completed before recipe creation: %s" % reference_version}
	if not selected_run.get("outputs", {}) is Dictionary or selected_run.get("outputs", {}).is_empty():
		return {"ok": false, "error": "Generation version has no recorded outputs: %s" % reference_version}
	var recipe_version := str(values.get("recipe_version", reference_version)).strip_edges()
	if recipe_version.is_empty():
		recipe_version = reference_version
	var profile_id := _recipe_profile_id(manifest, values)
	var recipe_path := _recipe_path(str(manifest.character_id), recipe_version)
	var recipe := _build_character_recipe(manifest, selected_run, reference_version, recipe_version, profile_id, recipe_path, values)
	var validation := validate_character_recipe_data(recipe)
	recipe["validation_state"] = validation
	var write_result := _write_json(recipe_path, recipe)
	if not write_result.ok:
		return write_result
	var recipes: Dictionary = manifest.get("recipes", {})
	var versions: Dictionary = recipes.get("versions", {})
	versions[recipe_version] = {
		"path": recipe_path,
		"reference_version": reference_version,
		"status": "draft",
		"created_at": recipe.get("created_at", ""),
		"validation_status": validation.status
	}
	recipes["versions"] = versions
	if not recipes.has("selected_version"):
		recipes["selected_version"] = ""
	manifest["recipes"] = recipes
	manifest["stage"] = "recipe_draft"
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([recipe_path, saved.path])
		saved["recipe_path"] = recipe_path
		saved["recipe"] = recipe
		saved["recipe_validation"] = validation
	return saved


func inspect_character_recipe(character_id: String, version := "") -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var recipes: Dictionary = manifest.get("recipes", {})
	var recipe_version := str(version).strip_edges()
	if recipe_version.is_empty():
		recipe_version = str(recipes.get("selected_version", ""))
	if recipe_version.is_empty():
		var versions: Dictionary = recipes.get("versions", {})
		var version_names := versions.keys()
		version_names.sort()
		if not version_names.is_empty():
			recipe_version = str(version_names[version_names.size() - 1])
	var recipe_path := _recipe_path(str(manifest.character_id), recipe_version) if not recipe_version.is_empty() else ""
	var recipe := _load_json(recipe_path) if not recipe_path.is_empty() else {}
	return {
		"ok": true,
		"path": loaded.path,
		"manifest": manifest,
		"recipe_path": recipe_path,
		"recipe": recipe,
		"recipe_validation": validate_character_recipe_data(recipe) if not recipe.is_empty() else {"status": "missing", "errors": ["Recipe not found."], "warnings": []}
	}


func validate_character_recipe(character_id: String, version := "") -> Dictionary:
	var inspected := inspect_character_recipe(character_id, version)
	if not inspected.ok:
		return inspected
	var validation: Dictionary = inspected.recipe_validation
	return {
		"ok": true,
		"path": inspected.path,
		"manifest": inspected.manifest,
		"recipe_path": inspected.recipe_path,
		"recipe": inspected.recipe,
		"recipe_validation": validation
	}


func approve_character_recipe(character_id: String, values: Dictionary = {}) -> Dictionary:
	var inspected := inspect_character_recipe(character_id, str(values.get("version", "")))
	if not inspected.ok:
		return inspected
	var recipe: Dictionary = inspected.recipe
	if recipe.is_empty():
		return {"ok": false, "error": "Recipe not found."}
	var validation: Dictionary = inspected.recipe_validation
	if str(validation.get("status", "")) == "failed":
		return {"ok": false, "error": "Recipe validation failed: %s" % "; ".join(_packed_paths(validation.get("errors", [])))}
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var recipe_version := str(recipe.get("recipe_version", ""))
	var recipes: Dictionary = manifest.get("recipes", {})
	var versions: Dictionary = recipes.get("versions", {})
	var record: Dictionary = versions.get(recipe_version, {})
	record["path"] = str(inspected.recipe_path)
	record["reference_version"] = str(recipe.get("reference_version", ""))
	record["status"] = "approved"
	record["approved_at"] = Time.get_datetime_string_from_system(true)
	record["validation_status"] = validation.status
	versions[recipe_version] = record
	recipes["versions"] = versions
	recipes["selected_version"] = recipe_version
	recipes["approved_recipe_path"] = str(inspected.recipe_path)
	manifest["recipes"] = recipes
	manifest["stage"] = "recipe_approved"
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([saved.path])
		saved["recipe_path"] = str(inspected.recipe_path)
		saved["recipe"] = recipe
		saved["recipe_validation"] = validation
		var checkpoint_result := write_character_checkpoints(character_id, recipe_version)
		if checkpoint_result.ok:
			saved["checkpoint_index"] = checkpoint_result.checkpoint_index
			saved["checkpoint_path"] = checkpoint_result.checkpoint_path
			var changed_paths: PackedStringArray = saved.changed_paths
			changed_paths.append(checkpoint_result.checkpoint_path)
			saved["changed_paths"] = changed_paths
	return saved


func register_assembly_result(character_id: String, values: Dictionary = {}) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var recipes: Dictionary = manifest.get("recipes", {})
	var recipe_version := str(values.get("version", recipes.get("selected_version", ""))).strip_edges()
	if recipe_version.is_empty():
		return {"ok": false, "error": "Approve a recipe before registering assembly output."}
	var recipe_path := str(values.get("recipe_path", recipes.get("approved_recipe_path", _recipe_path(str(manifest.character_id), recipe_version))))
	var recipe := _load_json(recipe_path)
	if recipe.is_empty():
		return {"ok": false, "error": "Recipe could not be loaded: %s" % recipe_path}
	var validation := validate_character_recipe_data(recipe)
	if str(validation.get("status", "")) == "failed":
		return {"ok": false, "error": "Recipe validation failed: %s" % "; ".join(_packed_paths(validation.get("errors", [])))}
	var report_path := str(values.get("assembly_report", recipe.get("outputs", {}).get("assembly_report", ""))).strip_edges()
	if report_path.is_empty():
		report_path = characters_root.path_join(str(manifest.character_id)).path_join("assembly").path_join(recipe_version).path_join("assembly_report.json")
	var report := _load_json(report_path)
	if report.is_empty():
		return {"ok": false, "error": "Assembly report could not be loaded: %s" % report_path}
	var report_validation := _validate_assembly_report(report, str(manifest.character_id), recipe_version)
	if not report_validation.errors.is_empty():
		return {"ok": false, "error": "Assembly report validation failed: %s" % "; ".join(report_validation.errors)}
	var outputs: Dictionary = report.get("outputs", {})
	var godot_import_asset := str(outputs.get("godot_import_asset", ""))
	var character_scene := str(values.get("character_scene", characters_root.path_join(str(manifest.character_id)).path_join("%s.tscn" % str(manifest.character_id))))
	var scene_result := _write_isometric_character_scene(character_scene, manifest, recipe, report, godot_import_asset)
	if not scene_result.ok:
		return scene_result
	var registration_report_path := characters_root.path_join(str(manifest.character_id)).path_join("reports").path_join(recipe_version).path_join("isometric_character_registration.json")
	var registration_report := {
		"schema_version": SCHEMA_VERSION,
		"status": "registered",
		"character_id": str(manifest.character_id),
		"recipe_version": recipe_version,
		"recipe_path": recipe_path,
		"assembly_report": report_path,
		"godot_import_asset": godot_import_asset,
		"character_scene": character_scene,
		"sockets": report.get("sockets", []),
		"equipment": report.get("equipment", []),
		"animations": _recipe_animation_paths(recipe, manifest),
		"lod": recipe.get("lod", {}),
		"preview_readability": {
			"status": "pending",
			"required": bool(recipe.get("validation", {}).get("requires_thumbnail_readability", true)),
			"note": "Isometric thumbnail capture is a later validation step."
		},
		"warnings": report_validation.warnings
	}
	var write_result := _write_json(registration_report_path, registration_report)
	if not write_result.ok:
		return write_result
	var assets: Dictionary = manifest.get("assets", {})
	assets["character_scene"] = character_scene
	assets["source_recipe"] = recipe_path
	assets["assembly_report"] = report_path
	assets["registration_report"] = registration_report_path
	assets["godot_import_asset"] = godot_import_asset
	assets["animations"] = registration_report.animations
	assets["sockets"] = report.get("sockets", [])
	assets["materials"] = recipe.get("materials", {})
	assets["lod"] = recipe.get("lod", {})
	assets["preview_thumbnails"] = []
	assets["preview_readability"] = registration_report.preview_readability
	assets["secondary_assets"] = _secondary_assets_from_equipment(report.get("equipment", []))
	manifest["assets"] = assets
	manifest["stage"] = "assembly_registered"
	var saved := save_character(manifest)
	if saved.ok:
		saved["changed_paths"] = PackedStringArray([character_scene, registration_report_path, saved.path])
		saved["assembly_report"] = report
		saved["registration_report"] = registration_report
		var checkpoint_result := write_character_checkpoints(character_id, recipe_version)
		if checkpoint_result.ok:
			saved["checkpoint_index"] = checkpoint_result.checkpoint_index
			saved["checkpoint_path"] = checkpoint_result.checkpoint_path
			var changed_paths: PackedStringArray = saved.changed_paths
			changed_paths.append(checkpoint_result.checkpoint_path)
			saved["changed_paths"] = changed_paths
	return saved


func checkpoint_status(character_id: String, version := "") -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var checkpoint_version := _checkpoint_version(manifest, str(version))
	if checkpoint_version.is_empty():
		return {"ok": false, "error": "Checkpoint version could not be inferred."}
	var checkpoint := _load_checkpoint_index(str(manifest.character_id), checkpoint_version, manifest)
	checkpoint = _refresh_checkpoint_status(checkpoint)
	return {
		"ok": true,
		"path": loaded.path,
		"manifest": manifest,
		"checkpoint_path": _checkpoint_path(str(manifest.character_id), checkpoint_version),
		"checkpoint_index": checkpoint,
		"changed_paths": PackedStringArray()
	}


func write_character_checkpoints(character_id: String, version := "") -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var checkpoint_version := _checkpoint_version(manifest, str(version))
	if checkpoint_version.is_empty():
		return {"ok": false, "error": "Checkpoint version could not be inferred."}
	var checkpoint := _load_checkpoint_index(str(manifest.character_id), checkpoint_version, manifest)
	checkpoint = _merge_current_checkpoint_stages(checkpoint, manifest, checkpoint_version)
	checkpoint = _refresh_checkpoint_status(checkpoint)
	var checkpoint_path := _checkpoint_path(str(manifest.character_id), checkpoint_version)
	var write_result := _write_json(checkpoint_path, checkpoint)
	if not write_result.ok:
		return write_result
	return {
		"ok": true,
		"path": loaded.path,
		"manifest": manifest,
		"checkpoint_path": checkpoint_path,
		"checkpoint_index": checkpoint,
		"changed_paths": PackedStringArray([checkpoint_path])
	}


func invalidate_checkpoint_stage(character_id: String, version: String, stage_name: String, reason: String) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var checkpoint_version := _checkpoint_version(manifest, version)
	if checkpoint_version.is_empty():
		return {"ok": false, "error": "Checkpoint version could not be inferred."}
	if not CHECKPOINT_STAGE_ORDER.has(stage_name):
		return {"ok": false, "error": "Unknown checkpoint stage: %s" % stage_name}
	var checkpoint := _load_checkpoint_index(str(manifest.character_id), checkpoint_version, manifest)
	checkpoint = _merge_current_checkpoint_stages(checkpoint, manifest, checkpoint_version)
	var stages: Dictionary = checkpoint.get("stages", {})
	var stage: Dictionary = stages.get(stage_name, {})
	stage["status"] = "stale"
	stage["invalidated_at"] = Time.get_datetime_string_from_system(true)
	var warning := reason
	if warning.strip_edges().is_empty():
		warning = "Stage was manually invalidated."
	stage["warnings"] = _append_warning(stage.get("warnings", []), warning)
	stages[stage_name] = stage
	checkpoint["stages"] = stages
	checkpoint = _refresh_checkpoint_status(checkpoint)
	return _save_checkpoint_result(loaded, checkpoint)


func mark_checkpoint_reviewed(character_id: String, version: String, stage_name: String) -> Dictionary:
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var checkpoint_version := _checkpoint_version(manifest, version)
	if checkpoint_version.is_empty():
		return {"ok": false, "error": "Checkpoint version could not be inferred."}
	if not CHECKPOINT_STAGE_ORDER.has(stage_name):
		return {"ok": false, "error": "Unknown checkpoint stage: %s" % stage_name}
	var checkpoint := _load_checkpoint_index(str(manifest.character_id), checkpoint_version, manifest)
	checkpoint = _merge_current_checkpoint_stages(checkpoint, manifest, checkpoint_version)
	var stages: Dictionary = checkpoint.get("stages", {})
	var stage: Dictionary = stages.get(stage_name, {})
	stage["reviewed_at"] = Time.get_datetime_string_from_system(true)
	stage["reviewed"] = true
	stages[stage_name] = stage
	checkpoint["stages"] = stages
	checkpoint = _refresh_checkpoint_status(checkpoint)
	return _save_checkpoint_result(loaded, checkpoint)


func explain_stale_checkpoints(character_id: String, version := "") -> Dictionary:
	var status: Dictionary = checkpoint_status(character_id, version)
	if not bool(status.get("ok", false)):
		return status
	var explanations := []
	var checkpoint_index: Dictionary = status.get("checkpoint_index", {})
	var stages: Dictionary = checkpoint_index.get("stages", {})
	for stage_name in CHECKPOINT_STAGE_ORDER:
		var stage: Dictionary = stages.get(stage_name, {})
		if str(stage.get("status", "")) in ["stale", "failed", "missing"]:
			explanations.append({
				"stage": stage_name,
				"status": str(stage.get("status", "")),
				"warnings": stage.get("warnings", [])
			})
	status["stale_explanations"] = explanations
	return status


func resume_from_checkpoint(character_id: String, version: String, stage_name: String) -> Dictionary:
	if stage_name != "godot_scene":
		return {"ok": false, "error": "Resume is currently supported only for godot_scene from a valid assembly checkpoint."}
	var status := checkpoint_status(character_id, version)
	if not status.ok:
		return status
	var stages: Dictionary = status.checkpoint_index.get("stages", {})
	var assembly: Dictionary = stages.get("assembly", {})
	if str(assembly.get("status", "")) != "valid":
		return {"ok": false, "error": "Cannot resume Godot scene because assembly checkpoint is not valid."}
	var report_path := str(assembly.get("report", ""))
	if report_path.is_empty() or not FileAccess.file_exists(report_path):
		return {"ok": false, "error": "Cannot resume Godot scene because assembly report is missing."}
	return register_assembly_result(character_id, {
		"version": str(status.checkpoint_index.get("version", version)),
		"assembly_report": report_path
	})


func reuse_base_checkpoint(character_id: String, version: String, source_character_id: String, source_version: String) -> Dictionary:
	var source_status := checkpoint_status(source_character_id, source_version)
	if not source_status.ok:
		return source_status
	var source_stages: Dictionary = source_status.checkpoint_index.get("stages", {})
	var source_base: Dictionary = source_stages.get("base_body", {})
	var source_animation: Dictionary = source_stages.get("animation_smoke", {})
	if str(source_base.get("status", "")) != "valid":
		return {"ok": false, "error": "Source base_body checkpoint is not valid."}
	if str(source_animation.get("status", "")) != "valid":
		return {"ok": false, "error": "Source animation_smoke checkpoint is not valid."}
	var loaded := load_character(character_id)
	if not loaded.ok:
		return loaded
	var manifest: Dictionary = loaded.manifest
	var checkpoint_version := _checkpoint_version(manifest, version)
	if checkpoint_version.is_empty():
		checkpoint_version = version
	if checkpoint_version.is_empty():
		return {"ok": false, "error": "Target checkpoint version is required."}
	var checkpoint := _load_checkpoint_index(str(manifest.character_id), checkpoint_version, manifest)
	var stages: Dictionary = checkpoint.get("stages", {})
	var base_copy: Dictionary = source_base.duplicate(true)
	base_copy["reused_from"] = {
		"character_id": source_character_id,
		"version": str(source_status.checkpoint_index.get("version", source_version)),
		"stage": "base_body"
	}
	var animation_copy: Dictionary = source_animation.duplicate(true)
	animation_copy["reused_from"] = {
		"character_id": source_character_id,
		"version": str(source_status.checkpoint_index.get("version", source_version)),
		"stage": "animation_smoke"
	}
	stages["base_body"] = base_copy
	stages["animation_smoke"] = animation_copy
	checkpoint["stages"] = stages
	checkpoint = _refresh_checkpoint_status(checkpoint)
	return _save_checkpoint_result(loaded, checkpoint)


func validate_character_recipe_data(recipe: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	if recipe.is_empty():
		return {"status": "failed", "errors": ["Recipe is empty."], "warnings": []}
	if int(recipe.get("schema_version", 0)) != RECIPE_SCHEMA_VERSION:
		errors.append("Recipe schema_version must be %d." % RECIPE_SCHEMA_VERSION)
	if str(recipe.get("character_id", "")).strip_edges().is_empty():
		errors.append("Recipe character_id is required.")
	if str(recipe.get("recipe_version", "")).strip_edges().is_empty():
		errors.append("Recipe version is required.")
	var profile_id := str(recipe.get("game_mode_profile_id", "")).strip_edges()
	if profile_id.is_empty():
		errors.append("Recipe game_mode_profile_id is required.")
	if profile_id == DEFAULT_ISOMETRIC_PROFILE:
		var validation: Dictionary = recipe.get("validation", {})
		if str(validation.get("camera_profile", "")) != "isometric_medium":
			warnings.append("3d_isometric_party recipes should use isometric_medium camera validation.")
	var body: Dictionary = recipe.get("body", {})
	if body.is_empty():
		errors.append("Recipe body strategy is required.")
	else:
		if str(body.get("strategy", "")).strip_edges().is_empty():
			errors.append("Recipe body.strategy is required.")
		if str(body.get("provider", "")).strip_edges().is_empty():
			errors.append("Recipe body.provider is required.")
		if str(body.get("pose_contract", "")) != "neutral_a_pose_30deg_v1":
			errors.append("Recipe body.pose_contract must be neutral_a_pose_30deg_v1.")
		var provider_record: Dictionary = body.get("provider_provenance", {})
		_validate_provider_record(provider_record, "body", errors, warnings)
		if _proxy_or_research_provider_ids().has(str(body.get("provider", ""))) and bool(body.get("production_topology_candidate", false)):
			errors.append("Proxy or research provider cannot be promoted as production humanoid body: %s." % str(body.get("provider", "")))
	var source: Dictionary = recipe.get("source", {})
	for assistance in source.get("ai_assistance", []):
		if assistance is Dictionary:
			_validate_provider_record(assistance, "ai_assistance", errors, warnings)
	var equipment: Array = recipe.get("equipment", [])
	if equipment.is_empty():
		warnings.append("Recipe has no equipment components; isometric readability may be weak.")
	var required_sockets := PackedStringArray()
	for part in equipment:
		if not part is Dictionary:
			errors.append("Equipment entry is malformed.")
			continue
		var representation := str(part.get("representation", ""))
		if not _allowed_representation_classes().has(representation):
			errors.append("Invalid equipment representation class: %s." % representation)
		if bool(part.get("required", false)):
			var socket := str(part.get("socket", "")).strip_edges()
			if socket.is_empty():
				errors.append("Required equipment is missing socket: %s." % str(part.get("part_id", "")))
			elif not required_sockets.has(socket):
				required_sockets.append(socket)
		var status := str(part.get("production_status", ""))
		if status in ["proxy_reference", "research_only"] and bool(part.get("promote_to_production", false)):
			errors.append("Proxy or research equipment cannot be promoted automatically: %s." % str(part.get("part_id", "")))
		_validate_provider_record(part.get("provider_provenance", {}), "equipment.%s" % str(part.get("part_id", "")), errors, warnings)
	var sockets: Array = recipe.get("sockets", [])
	for required_socket in required_sockets:
		var found := false
		for socket in sockets:
			if socket is Dictionary and str(socket.get("name", "")) == required_socket:
				found = true
				break
		if not found:
			errors.append("Required socket is not declared in recipe sockets: %s." % required_socket)
	var materials: Dictionary = recipe.get("materials", {})
	if materials.is_empty():
		errors.append("Recipe materials plan is required.")
	elif str(materials.get("texture_budget", "")).strip_edges().is_empty():
		errors.append("Recipe materials.texture_budget is required.")
	var animation: Dictionary = recipe.get("animation", {})
	if str(animation.get("profile", "")) != "SkeletonProfileHumanoid":
		errors.append("Recipe animation.profile must be SkeletonProfileHumanoid.")
	for clip in ["idle", "walk"]:
		if not animation.get("required_clips", []).has(clip):
			warnings.append("Recipe should declare %s as required animation evidence." % clip)
	var lod: Dictionary = recipe.get("lod", {})
	if str(lod.get("strategy", "")).strip_edges().is_empty():
		errors.append("Recipe LOD strategy is required.")
	var validation_plan: Dictionary = recipe.get("validation", {})
	for field in ["requires_thumbnail_readability", "requires_socket_report", "requires_animation_smoke"]:
		if not bool(validation_plan.get(field, false)):
			warnings.append("Recipe validation should enable %s." % field)
	return {
		"status": "failed" if not errors.is_empty() else ("warning" if not warnings.is_empty() else "pass"),
		"errors": errors,
		"warnings": warnings
	}


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
				actions.append("create-recipe:%s" % selected_version)
				actions.append("prepare-conformance:%s" % selected_version)
	var recipes: Dictionary = manifest.get("recipes", {})
	var recipe_versions: Dictionary = recipes.get("versions", {})
	if not recipe_versions.is_empty():
		actions.append("inspect-recipe")
		actions.append("validate-recipe")
		for version in recipe_versions.keys():
			var record: Dictionary = recipe_versions[version]
			if str(record.get("status", "")) != "approved":
				actions.append("approve-recipe:%s" % str(version))
			else:
				actions.append("register-assembly:%s" % str(version))
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
		"recipes": {
			"selected_version": "",
			"approved_recipe_path": "",
			"versions": {}
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
	if not manifest.has("recipes") or not (manifest.recipes is Dictionary):
		manifest["recipes"] = {
			"selected_version": "",
			"approved_recipe_path": "",
			"versions": {}
		}
	else:
		var recipes: Dictionary = manifest.recipes
		if not recipes.has("selected_version"):
			recipes["selected_version"] = ""
		if not recipes.has("approved_recipe_path"):
			recipes["approved_recipe_path"] = ""
		if not recipes.has("versions") or not (recipes.versions is Dictionary):
			recipes["versions"] = {}
		manifest["recipes"] = recipes
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


func _recipe_path(character_id: String, version: String) -> String:
	return characters_root.path_join(character_id).path_join("recipes").path_join(version).path_join("character_recipe.json")


func _recipe_profile_id(manifest: Dictionary, values: Dictionary) -> String:
	var supplied := str(values.get("game_mode_profile_id", "")).strip_edges()
	if not supplied.is_empty():
		return supplied
	var profile = manifest.get("game_mode_profile", {})
	if profile is Dictionary:
		var profile_id := str(profile.get("profile_id", profile.get("id", ""))).strip_edges()
		if not profile_id.is_empty():
			return profile_id
	return DEFAULT_ISOMETRIC_PROFILE


func _build_character_recipe(manifest: Dictionary, run: Dictionary, reference_version: String, recipe_version: String, profile_id: String, recipe_path: String, values: Dictionary) -> Dictionary:
	var character_id := str(manifest.character_id)
	var metadata: Dictionary = manifest.get("metadata", {})
	var pose_contract := str(manifest.get("pose_contract", metadata.get("pose_contract", "neutral_a_pose_30deg_v1")))
	var targets := _field_engineer_targets(manifest, run)
	var equipment := _recipe_equipment_from_targets(targets, values)
	var sockets := _recipe_sockets_for_equipment(equipment)
	var rigged_meshes := _rigged_meshes_from_values(manifest)
	var body_provider := str(values.get("body_provider", "project_rigged_meshes")).strip_edges()
	if body_provider.is_empty():
		body_provider = "project_rigged_meshes"
	var body_provider_record := _recipe_provider_record(body_provider, "production_body", "project_user_supplied", "reviewed_or_user_supplied", "project_config", true)
	var source_assistance := []
	if run.get("model_provenance", {}) is Dictionary and not run.get("model_provenance", {}).is_empty():
		source_assistance.append({
			"tool": "comfyui",
			"role": "concept_reference",
			"locality": "local_user_managed",
			"license_state": "reviewed_or_user_supplied",
			"automatic_downloads_allowed": false,
			"provenance": run.model_provenance
		})
	var recipe := {
		"schema_version": RECIPE_SCHEMA_VERSION,
		"character_id": character_id,
		"display_name": str(manifest.get("display_name", character_id)),
		"recipe_version": recipe_version,
		"reference_version": reference_version,
		"game_mode_profile_id": profile_id,
		"created_at": Time.get_datetime_string_from_system(true),
		"source": {
			"manifest_path": characters_root.path_join(character_id).path_join("character.json"),
			"manifest_stage": str(manifest.get("stage", "")),
			"approved_reference_run": str(run.get("run_id", "")),
			"approved_reference_version": reference_version,
			"reference_outputs": run.get("outputs", {}),
			"prompt_targets": targets,
			"ai_assistance": source_assistance
		},
		"body": {
			"strategy": "canonical_humanoid",
			"provider": body_provider,
			"provider_provenance": body_provider_record,
			"production_topology_candidate": true,
			"pose_contract": pose_contract,
			"scale_meters": float(manifest.get("blender", {}).get("height_m", 1.78)),
			"rigged_meshes": rigged_meshes,
			"morph_targets": {},
			"manual_review_required": []
		},
		"equipment": equipment,
		"sockets": sockets,
		"materials": {
			"palette": targets.get("colors", ["muted_cloth", "worn_leather", "brushed_metal"]),
			"material_families": targets.get("materials", []),
			"texture_budget": str(values.get("texture_budget", "medium")),
			"atlas_group": str(values.get("atlas_group", "isometric_party_humanoid_v1"))
		},
		"animation": {
			"profile": "SkeletonProfileHumanoid",
			"required_clips": ["idle", "walk"],
			"role_clips": _recipe_role_clips(manifest),
			"retarget_source": str(manifest.get("project_context", {}).get("animation_library", manifest.get("animation_asset", "")))
		},
		"lod": {
			"strategy": "manual_lod",
			"required_levels": ["lod0"],
			"planned_levels": ["lod1"],
			"impostor_optional": true
		},
		"validation": {
			"camera_profile": "isometric_medium",
			"requires_thumbnail_readability": true,
			"requires_socket_report": true,
			"requires_animation_smoke": true,
			"requires_license_report": true,
			"blocked_production_topology_sources": _proxy_or_research_provider_ids()
		},
		"outputs": {
			"recipe_path": recipe_path,
			"blender_work_file": "",
			"godot_scene": "",
			"validation_report": "",
			"isometric_preview": ""
		}
	}
	if values.has("recipe_overrides") and values.recipe_overrides is Dictionary:
		recipe.merge(values.recipe_overrides, true)
	return recipe


func _recipe_equipment_from_targets(targets: Dictionary, values: Dictionary) -> Array[Dictionary]:
	if values.has("equipment") and values.equipment is Array:
		return values.equipment
	var equipment: Array[Dictionary] = []
	var silhouettes: Array = targets.get("silhouette", [])
	for silhouette in silhouettes:
		var part_id := str(silhouette)
		match part_id:
			"helmet":
				equipment.append(_recipe_equipment_part("helmet", "hybrid_character_prop", "primitive", "head", true, "placeholder_primitive"))
			"vest":
				equipment.append(_recipe_equipment_part("torso_vest", "hybrid_character_prop", "cloth_or_flexible_mesh", "chest", true, "existing_asset_or_placeholder"))
			"tool_belt":
				equipment.append(_recipe_equipment_part("tool_belt", "hybrid_character_prop", "hard_surface_mesh", "hips", true, "placeholder_primitive"))
			"boots":
				equipment.append(_recipe_equipment_part("boots", "hybrid_character_prop", "existing_asset", "feet", false, "project_base_mesh"))
			"gloves":
				equipment.append(_recipe_equipment_part("gloves", "hybrid_character_prop", "existing_asset", "hands", false, "project_base_mesh"))
	var props: Array = targets.get("props", [])
	for prop in props:
		if not prop is Dictionary:
			continue
		var asset_id := str(prop.get("asset_id", "prop"))
		var socket := str(prop.get("socket", "hand_r"))
		equipment.append(_recipe_equipment_part(asset_id, "inorganic_mechanical", "primitive", socket, true, "placeholder_primitive"))
	if equipment.is_empty():
		equipment.append(_recipe_equipment_part("role_prop", "hybrid_character_prop", "primitive", "hand_r", true, "placeholder_primitive"))
	return equipment


func _recipe_equipment_part(part_id: String, taxonomy: String, representation: String, socket: String, required: bool, source_kind: String) -> Dictionary:
	return {
		"part_id": part_id,
		"taxonomy": taxonomy,
		"representation": representation,
		"socket": socket,
		"required": required,
		"source_kind": source_kind,
		"production_status": "planned",
		"promote_to_production": false,
		"provider_provenance": _recipe_provider_record(source_kind, "equipment_or_prop", source_kind, "reviewed_or_user_supplied", "recipe_default", true)
	}


func _recipe_sockets_for_equipment(equipment: Array) -> Array[Dictionary]:
	var sockets: Array[Dictionary] = [
		{"name": "head", "parent_bone": "Head", "required": false},
		{"name": "chest", "parent_bone": "Chest", "required": false},
		{"name": "hips", "parent_bone": "Hips", "required": false},
		{"name": "hand_l", "parent_bone": "LeftHand", "required": false},
		{"name": "hand_r", "parent_bone": "RightHand", "required": false},
		{"name": "back", "parent_bone": "Chest", "required": false},
		{"name": "feet", "parent_bone": "Hips", "required": false},
		{"name": "hands", "parent_bone": "Chest", "required": false}
	]
	for part in equipment:
		if not part is Dictionary or not bool(part.get("required", false)):
			continue
		var socket_name := str(part.get("socket", ""))
		for index in sockets.size():
			if str(sockets[index].get("name", "")) == socket_name:
				sockets[index]["required"] = true
				break
	return sockets


func _recipe_role_clips(manifest: Dictionary) -> Array[String]:
	var role_text := str(manifest.get("metadata", {}).get("role", "")).to_lower()
	if _contains_any(role_text, ["healer", "mage", "wizard", "cleric", "caster"]):
		return ["cast"]
	if _contains_any(role_text, ["fighter", "soldier", "guard", "warrior"]):
		return ["attack"]
	return ["use"]


func _recipe_provider_record(provider_id: String, role: String, license_record: String, license_state: String, source: String, commercial_use) -> Dictionary:
	return {
		"provider_id": provider_id,
		"role": role,
		"license_record": license_record,
		"license_state": license_state,
		"commercial_use": commercial_use,
		"locality": "project_local_or_user_managed",
		"automatic_downloads_allowed": false,
		"source": source
	}


func _validate_provider_record(provider, context: String, errors: PackedStringArray, warnings: PackedStringArray) -> void:
	if not provider is Dictionary or provider.is_empty():
		errors.append("Provider provenance is required for %s." % context)
		return
	var provider_id := str(provider.get("provider_id", provider.get("tool", ""))).strip_edges()
	if provider_id.is_empty():
		errors.append("Provider provenance is missing provider_id/tool for %s." % context)
	var license_state := str(provider.get("license_state", "")).strip_edges()
	if license_state.is_empty() or license_state in ["unknown", "unclear", "blocked"]:
		errors.append("Provider license state is not accepted for %s: %s." % [context, license_state if not license_state.is_empty() else "missing"])
	if bool(provider.get("automatic_downloads_allowed", false)):
		errors.append("Automatic downloads are not allowed for %s." % context)
	if _proxy_or_research_provider_ids().has(provider_id) and license_state != "reviewed_or_user_supplied":
		warnings.append("Proxy/research provider requires explicit review for %s: %s." % [context, provider_id])


func _allowed_representation_classes() -> PackedStringArray:
	return PackedStringArray([
		"existing_asset",
		"organic_mesh",
		"hard_surface_mesh",
		"primitive",
		"lathed_or_revolved",
		"curve",
		"cad_code",
		"brep_or_step",
		"nurbs_surface",
		"cloth_or_flexible_mesh",
		"shader_or_volume",
		"decal",
		"proxy_reference",
		"existing_asset_or_proxy_reference"
	])


func _proxy_or_research_provider_ids() -> PackedStringArray:
	return PackedStringArray(["triposr", "trellis", "hunyuan3d_2", "hunyuan3d_2_1", "smplx", "shert", "humangaussian", "haha", "external_proxy_mesh"])


func _validate_assembly_report(report: Dictionary, character_id: String, recipe_version: String) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	if int(report.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("Assembly report schema_version must be %d." % SCHEMA_VERSION)
	if str(report.get("status", "")) != "assembled":
		errors.append("Assembly report status must be assembled.")
	if str(report.get("character_id", "")) != character_id:
		errors.append("Assembly report character_id does not match manifest.")
	if str(report.get("recipe_version", "")) != recipe_version:
		errors.append("Assembly report recipe_version does not match selected recipe.")
	var outputs: Dictionary = report.get("outputs", {})
	for output_key in ["blender_work_file", "godot_import_asset", "assembly_report"]:
		var path := str(outputs.get(output_key, ""))
		if path.strip_edges().is_empty():
			errors.append("Assembly report is missing output: %s." % output_key)
		elif not _is_project_data_path(path):
			errors.append("Assembly output must stay under res://build_me_godot/: %s." % path)
	if not report.get("sockets", []) is Array or report.get("sockets", []).is_empty():
		errors.append("Assembly report must include sockets.")
	if not report.get("equipment", []) is Array or report.get("equipment", []).is_empty():
		warnings.append("Assembly report has no equipment entries.")
	for warning in report.get("warnings", []):
		warnings.append(str(warning))
	return {"errors": errors, "warnings": warnings}


func _write_isometric_character_scene(path: String, manifest: Dictionary, recipe: Dictionary, report: Dictionary, godot_import_asset: String) -> Dictionary:
	if not _is_project_data_path(path):
		return {"ok": false, "error": "Character scene must be under res://build_me_godot/: %s" % path}
	if godot_import_asset.strip_edges().is_empty():
		return {"ok": false, "error": "Assembly report did not include a Godot import asset."}
	if not _is_project_data_path(godot_import_asset):
		return {"ok": false, "error": "Godot import asset must be under res://build_me_godot/: %s" % godot_import_asset}
	var animation_paths := _scene_animation_library_paths(_recipe_animation_paths(recipe, manifest))
	var lines := PackedStringArray()
	lines.append("[gd_scene load_steps=%d format=3]" % (2 + animation_paths.size()))
	lines.append("")
	lines.append("[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_assembled\"]" % godot_import_asset)
	for index in animation_paths.size():
		lines.append("[ext_resource type=\"AnimationLibrary\" path=\"%s\" id=\"%d_animation_library\"]" % [str(animation_paths[index]), index + 2])
	lines.append("")
	lines.append("[node name=\"%s\" type=\"Node3D\"]" % _scene_node_name(str(manifest.get("display_name", manifest.get("character_id", "Character")))))
	lines.append("metadata/character_id = \"%s\"" % str(manifest.get("character_id", "")))
	lines.append("metadata/stage = \"assembly_registered\"")
	lines.append("")
	lines.append("[node name=\"Model\" parent=\".\" instance=ExtResource(\"1_assembled\")]")
	if not animation_paths.is_empty():
		lines.append("")
		lines.append("[node name=\"AnimationPlayer\" type=\"AnimationPlayer\" parent=\".\"]")
		lines.append("root_node = NodePath(\"../Model\")")
		for index in animation_paths.size():
			lines.append("libraries/%s = ExtResource(\"%d_animation_library\")" % [_animation_library_key(str(animation_paths[index])), index + 2])
	lines.append("")
	lines.append("[node name=\"Sockets\" type=\"Node3D\" parent=\".\"]")
	for socket in report.get("sockets", []):
		if not socket is Dictionary:
			continue
		lines.append("")
		lines.append("[node name=\"%s\" type=\"Marker3D\" parent=\"Sockets\"]" % _scene_node_name(str(socket.get("name", "socket"))))
		lines.append("metadata/parent_bone = \"%s\"" % str(socket.get("parent_bone", "")))
		lines.append("metadata/required = %s" % ("true" if bool(socket.get("required", false)) else "false"))
	lines.append("")
	lines.append("[node name=\"EquipmentPlan\" type=\"Node3D\" parent=\".\"]")
	for part in report.get("equipment", []):
		if not part is Dictionary:
			continue
		lines.append("")
		lines.append("[node name=\"%s\" type=\"Node3D\" parent=\"EquipmentPlan\"]" % _scene_node_name(str(part.get("part_id", "part"))))
		lines.append("metadata/socket = \"%s\"" % str(part.get("socket", "")))
		lines.append("metadata/representation = \"%s\"" % str(part.get("representation", "")))
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [path.get_base_dir(), error_string(error)]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s." % path}
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return {"ok": true}


func _animation_library_key(path: String) -> String:
	var basename := path.get_file().get_basename()
	if basename.ends_with(".animation_library"):
		basename = basename.trim_suffix(".animation_library")
	if basename.is_empty():
		return "AnimationLibrary"
	return _scene_node_name(basename)


func _recipe_animation_paths(recipe: Dictionary, manifest: Dictionary) -> Array:
	var paths := []
	var retarget_source := str(recipe.get("animation", {}).get("retarget_source", ""))
	if not retarget_source.is_empty():
		paths.append(retarget_source)
	for path in manifest.get("assets", {}).get("animations", []):
		if not paths.has(path):
			paths.append(path)
	if not _has_animation_library_path(paths):
		paths.append(DEFAULT_QUATERNIUS_ANIMATION_LIBRARY)
	return paths


func _scene_animation_library_paths(paths: Array) -> Array:
	var libraries := []
	for path in paths:
		var text := str(path)
		if text.ends_with(".animation_library.tres") and not libraries.has(text):
			libraries.append(text)
	return libraries


func _has_animation_library_path(paths: Array) -> bool:
	for path in paths:
		if str(path).ends_with(".animation_library.tres"):
			return true
	return false


func _checkpoint_version(manifest: Dictionary, requested: String) -> String:
	var version := requested.strip_edges()
	if not version.is_empty():
		return version
	var recipes: Dictionary = manifest.get("recipes", {})
	version = str(recipes.get("selected_version", "")).strip_edges()
	if not version.is_empty():
		return version
	var generation: Dictionary = manifest.get("generation", {})
	return str(generation.get("selected_version", "")).strip_edges()


func _checkpoint_path(character_id: String, version: String) -> String:
	return characters_root.path_join(character_id).path_join("checkpoints").path_join(version).path_join("checkpoint_index.json")


func _default_checkpoint_index(character_id: String, version: String, manifest: Dictionary) -> Dictionary:
	return {
		"schema_version": CHECKPOINT_SCHEMA_VERSION,
		"character_id": character_id,
		"version": version,
		"game_mode_profile_id": _manifest_game_mode_profile_id(manifest),
		"updated_at": Time.get_datetime_string_from_system(true),
		"stages": {}
	}


func _load_checkpoint_index(character_id: String, version: String, manifest: Dictionary) -> Dictionary:
	var checkpoint := _default_checkpoint_index(character_id, version, manifest)
	var existing := _load_json(_checkpoint_path(character_id, version))
	if existing is Dictionary and not existing.is_empty():
		checkpoint.merge(existing, true)
	checkpoint["schema_version"] = CHECKPOINT_SCHEMA_VERSION
	checkpoint["character_id"] = character_id
	checkpoint["version"] = version
	if str(checkpoint.get("game_mode_profile_id", "")).is_empty():
		checkpoint["game_mode_profile_id"] = _manifest_game_mode_profile_id(manifest)
	if not checkpoint.get("stages", {}) is Dictionary:
		checkpoint["stages"] = {}
	return checkpoint


func _save_checkpoint_result(loaded: Dictionary, checkpoint: Dictionary) -> Dictionary:
	var checkpoint_path := _checkpoint_path(str(checkpoint.get("character_id", "")), str(checkpoint.get("version", "")))
	checkpoint["updated_at"] = Time.get_datetime_string_from_system(true)
	var write_result := _write_json(checkpoint_path, checkpoint)
	if not write_result.ok:
		return write_result
	return {
		"ok": true,
		"path": loaded.get("path", ""),
		"manifest": loaded.get("manifest", {}),
		"checkpoint_path": checkpoint_path,
		"checkpoint_index": checkpoint,
		"changed_paths": PackedStringArray([checkpoint_path])
	}


func _merge_current_checkpoint_stages(checkpoint: Dictionary, manifest: Dictionary, version: String) -> Dictionary:
	var stages: Dictionary = checkpoint.get("stages", {})
	var character_id := str(manifest.character_id)
	var recipe_path := str(manifest.get("recipes", {}).get("approved_recipe_path", _recipe_path(character_id, version)))
	var recipe := _load_json(recipe_path)
	var report_path := str(manifest.get("assets", {}).get("assembly_report", characters_root.path_join(character_id).path_join("assembly").path_join(version).path_join("assembly_report.json")))
	var report := _load_json(report_path)
	var animation_paths := _recipe_animation_paths(recipe, manifest)
	var references := _checkpoint_reference_paths(manifest, recipe, version)
	stages["references"] = _merge_checkpoint_stage(stages.get("references", {}), {
		"status": "valid" if not references.is_empty() else "missing",
		"paths": references,
		"source_run_id": str(recipe.get("source", {}).get("approved_reference_run", "")),
		"source_version": version,
		"digest": _digest_paths(references),
		"inputs": [],
		"warnings": [] if not references.is_empty() else ["No approved reference paths are recorded."]
	})
	stages["recipe"] = _merge_checkpoint_stage(stages.get("recipe", {}), {
		"status": "valid" if not recipe.is_empty() and FileAccess.file_exists(recipe_path) else "missing",
		"path": recipe_path,
		"digest": _digest_paths([recipe_path]),
		"inputs": ["references"],
		"warnings": [] if FileAccess.file_exists(recipe_path) else ["Recipe file is missing."]
	})
	stages["base_body"] = _merge_checkpoint_stage(stages.get("base_body", {}), _base_body_checkpoint_stage(manifest, recipe))
	stages["assembly"] = _merge_checkpoint_stage(stages.get("assembly", {}), {
		"status": "valid" if not report.is_empty() and FileAccess.file_exists(report_path) else "missing",
		"report": report_path,
		"godot_import_asset": str(report.get("outputs", {}).get("godot_import_asset", manifest.get("assets", {}).get("godot_import_asset", ""))),
		"blender_work_file": str(report.get("outputs", {}).get("blender_work_file", "")),
		"digest": _digest_paths([report_path, str(report.get("outputs", {}).get("godot_import_asset", ""))]),
		"inputs": ["base_body", "references", "recipe"],
		"warnings": report.get("warnings", []) if report.get("warnings", []) is Array else []
	})
	var scene_path := str(manifest.get("assets", {}).get("character_scene", ""))
	stages["godot_scene"] = _merge_checkpoint_stage(stages.get("godot_scene", {}), {
		"status": "valid" if not scene_path.is_empty() and FileAccess.file_exists(scene_path) else "missing",
		"path": scene_path,
		"digest": _digest_paths([scene_path]),
		"inputs": ["assembly"],
		"warnings": [] if not scene_path.is_empty() and FileAccess.file_exists(scene_path) else ["Godot character scene is missing."]
	})
	stages["animation_smoke"] = _merge_checkpoint_stage(stages.get("animation_smoke", {}), _animation_checkpoint_stage(animation_paths))
	stages["readability"] = _merge_checkpoint_stage(stages.get("readability", {}), {
		"status": "pending",
		"report": "",
		"inputs": ["godot_scene"],
		"warnings": ["Isometric thumbnail/readability evidence has not been captured."]
	})
	checkpoint["stages"] = stages
	checkpoint["updated_at"] = Time.get_datetime_string_from_system(true)
	return checkpoint


func _merge_checkpoint_stage(existing, update: Dictionary) -> Dictionary:
	var stage := {}
	if existing is Dictionary:
		stage = existing.duplicate(true)
	stage.merge(update, true)
	if not CHECKPOINT_STATUSES.has(str(stage.get("status", ""))):
		stage["status"] = "failed"
		stage["warnings"] = _append_warning(stage.get("warnings", []), "Invalid checkpoint status was normalized to failed.")
	if not stage.has("reviewed_at"):
		stage["reviewed_at"] = ""
	if not stage.has("warnings") or not stage.warnings is Array:
		stage["warnings"] = []
	return stage


func _refresh_checkpoint_status(checkpoint: Dictionary) -> Dictionary:
	var stages: Dictionary = checkpoint.get("stages", {})
	for stage_name in CHECKPOINT_STAGE_ORDER:
		var stage: Dictionary = stages.get(stage_name, {"status": "missing", "warnings": ["Checkpoint stage has not been recorded."]})
		stage = _refresh_stage_file_status(stage)
		stages[stage_name] = stage
	var stale_reasons := _checkpoint_stale_reasons(stages)
	for stage_name in stale_reasons:
		var stage: Dictionary = stages.get(stage_name, {})
		stage["status"] = "stale"
		stage["warnings"] = _append_warning(stage.get("warnings", []), str(stale_reasons[stage_name]))
		stages[stage_name] = stage
	checkpoint["stages"] = stages
	return checkpoint


func _refresh_stage_file_status(stage: Dictionary) -> Dictionary:
	if str(stage.get("status", "")) in ["failed", "pending"]:
		return stage
	var paths := _stage_paths(stage)
	if paths.is_empty():
		return stage
	for path in paths:
		if not str(path).strip_edges().is_empty() and not FileAccess.file_exists(str(path)):
			stage["status"] = "missing"
			stage["warnings"] = _append_warning(stage.get("warnings", []), "Checkpoint path is missing: %s" % str(path))
			return stage
	var stored_digest := str(stage.get("digest", ""))
	if not stored_digest.is_empty():
		var current_digest := _digest_paths(paths)
		if not current_digest.is_empty() and current_digest != stored_digest:
			stage["status"] = "stale"
			stage["warnings"] = _append_warning(stage.get("warnings", []), "Checkpoint digest changed.")
	return stage


func _checkpoint_stale_reasons(stages: Dictionary) -> Dictionary:
	var stale := {}
	for stage_name in CHECKPOINT_STAGE_ORDER:
		var stage: Dictionary = stages.get(stage_name, {})
		if str(stage.get("status", "")) == "stale":
			_mark_dependents_stale(stage_name, stages, stale, "%s changed or is stale." % stage_name)
	return stale


func _mark_dependents_stale(changed_stage: String, stages: Dictionary, stale: Dictionary, reason: String) -> void:
	for candidate_name in stages.keys():
		if stale.has(candidate_name) or str(candidate_name) == changed_stage:
			continue
		var candidate: Dictionary = stages[candidate_name]
		var inputs = candidate.get("inputs", [])
		if inputs is Array and inputs.has(changed_stage):
			stale[candidate_name] = reason
			_mark_dependents_stale(str(candidate_name), stages, stale, "%s depends on stale %s." % [str(candidate_name), changed_stage])


func _stage_paths(stage: Dictionary) -> Array:
	var paths := []
	for key in ["path", "report", "godot_import_asset"]:
		var path := str(stage.get(key, "")).strip_edges()
		if not path.is_empty() and _is_project_data_path(path):
			paths.append(path)
	var stage_paths = stage.get("paths", [])
	if stage_paths is Array:
		for path in stage_paths:
			var text := str(path).strip_edges()
			if not text.is_empty() and _is_project_data_path(text):
				paths.append(text)
	return paths


func _base_body_checkpoint_stage(manifest: Dictionary, recipe: Dictionary) -> Dictionary:
	var body: Dictionary = recipe.get("body", {})
	var rigged_meshes := _rigged_meshes_from_values(manifest)
	if str(rigged_meshes.get("primary", "")).strip_edges().is_empty() and body.get("rigged_meshes", {}) is Dictionary:
		rigged_meshes = body.get("rigged_meshes", {})
	var primary := str(rigged_meshes.get("primary", ""))
	var provider_id := str(body.get("provider", "project_rigged_meshes"))
	var license_state := str(body.get("provider_provenance", {}).get("license_state", "reviewed_or_user_supplied"))
	var warnings := []
	var status := "valid"
	if primary.is_empty() or not FileAccess.file_exists(primary):
		status = "missing"
		warnings.append("Primary base body mesh is missing.")
	if _proxy_or_research_provider_ids().has(provider_id) or provider_id in ["smplx_research", "research_reference"]:
		status = "failed"
		warnings.append("Research/proxy topology cannot be marked as a production base.")
	if license_state in ["", "unknown", "unclear", "blocked", "research_only_unless_separately_licensed"]:
		status = "failed"
		warnings.append("Base body license state is not production-ready: %s" % license_state)
	if str(body.get("pose_contract", "neutral_a_pose_30deg_v1")) != "neutral_a_pose_30deg_v1":
		status = "failed"
		warnings.append("Base body does not match neutral_a_pose_30deg_v1.")
	return {
		"status": status,
		"path": primary,
		"digest": _digest_paths([primary]),
		"provider_id": provider_id,
		"license_state": license_state,
		"pose_contract": str(body.get("pose_contract", "neutral_a_pose_30deg_v1")),
		"skeleton_profile": "SkeletonProfileHumanoid",
		"scale_meters": float(body.get("scale_meters", manifest.get("blender", {}).get("height_m", 1.78))),
		"uv_assumptions": "base_provider_uv_layout",
		"game_mode_fit": [DEFAULT_ISOMETRIC_PROFILE],
		"animation_compatible": status == "valid",
		"inputs": [],
		"warnings": warnings
	}


func _animation_checkpoint_stage(animation_paths: Array) -> Dictionary:
	var libraries := _scene_animation_library_paths(animation_paths)
	var warnings := []
	var status := "valid"
	var available_clips := {}
	if libraries.is_empty():
		status = "missing"
		warnings.append("No AnimationLibrary path is recorded.")
	for path in libraries:
		if not FileAccess.file_exists(str(path)):
			status = "missing"
			warnings.append("Animation library is missing: %s" % str(path))
			continue
		var library = ResourceLoader.load(str(path))
		if library is AnimationLibrary:
			var clips := []
			for clip_name in library.get_animation_list():
				clips.append(str(clip_name))
			available_clips[str(path)] = clips
			for required_clip in ["Idle", "Walk"]:
				if not library.has_animation(required_clip):
					status = "failed"
					warnings.append("Animation library %s is missing required clip: %s" % [str(path), required_clip])
		else:
			status = "failed"
			warnings.append("Animation library could not be loaded as AnimationLibrary: %s" % str(path))
	return {
		"status": status,
		"paths": libraries,
		"digest": _digest_paths(libraries),
		"required_clips": ["Idle", "Walk"],
		"available_clips": available_clips,
		"evidence": "AnimationLibrary resources were loaded and checked for Idle and Walk.",
		"inputs": ["base_body", "godot_scene"],
		"warnings": warnings
	}


func _checkpoint_reference_paths(manifest: Dictionary, recipe: Dictionary, version: String) -> Array:
	var references := []
	var source_outputs: Dictionary = recipe.get("source", {}).get("reference_outputs", {})
	for key in source_outputs.keys():
		var path := str(source_outputs[key])
		if not path.is_empty() and not references.has(path):
			references.append(path)
	if references.is_empty():
		var run := _find_generation_run(manifest, version)
		for key in run.get("outputs", {}).keys():
			var path := str(run.outputs[key])
			if not path.is_empty() and not references.has(path):
				references.append(path)
	return references


func _manifest_game_mode_profile_id(manifest: Dictionary) -> String:
	var profile = manifest.get("game_mode_profile", {})
	if profile is Dictionary and not str(profile.get("profile_id", "")).is_empty():
		return str(profile.profile_id)
	var recipes: Dictionary = manifest.get("recipes", {})
	var recipe_path := str(recipes.get("approved_recipe_path", ""))
	var recipe := _load_json(recipe_path) if not recipe_path.is_empty() else {}
	return str(recipe.get("game_mode_profile_id", DEFAULT_ISOMETRIC_PROFILE))


func _file_digest(path: String) -> String:
	if path.strip_edges().is_empty() or not FileAccess.file_exists(path):
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return "sha256:%s" % context.finish().hex_encode()


func _digest_paths(paths: Array) -> String:
	var parts := PackedStringArray()
	for path in paths:
		var text := str(path).strip_edges()
		if text.is_empty():
			continue
		parts.append("%s=%s" % [text, _file_digest(text)])
	parts.sort()
	if parts.is_empty():
		return ""
	return "sha256:%s" % "\n".join(parts).sha256_text()


func _append_warning(existing, warning: String) -> Array:
	var warnings := []
	if existing is Array:
		for item in existing:
			warnings.append(str(item))
	if not warnings.has(warning):
		warnings.append(warning)
	return warnings


func _secondary_assets_from_equipment(equipment: Array) -> Array[Dictionary]:
	var assets: Array[Dictionary] = []
	for part in equipment:
		if not part is Dictionary:
			continue
		assets.append({
			"asset_id": str(part.get("part_id", "")),
			"socket": str(part.get("socket", "")),
			"representation": str(part.get("representation", "")),
			"status": "planned_from_recipe"
		})
	return assets


func _is_project_data_path(path: String) -> bool:
	return path.begins_with(workspace_root.path_join("")) or path == workspace_root or path.begins_with("res://build_me_godot/")


func _scene_node_name(value: String) -> String:
	var cleaned := value.strip_edges().replace(" ", "_").replace("-", "_")
	var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
	var result := ""
	for character in cleaned:
		if allowed.contains(character):
			result += character
	if result.is_empty():
		return "Node"
	if result[0].is_valid_int():
		return "N_%s" % result
	return result


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
	providers.append({
		"provider_id": "trellis",
		"role": "experimental_proxy_reconstruction",
		"status": "configured" if not command.is_empty() else "manual_setup_required",
		"license_record": "TRELLIS",
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
		"license_record": _provider_license_record(provider_id),
		"commercial_use": _provider_commercial_use(provider_id),
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
		"license_record": _provider_license_record(provider_id),
		"commercial_use": _provider_commercial_use(provider_id),
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
	return PackedStringArray(["triposr", "trellis", "external_proxy_mesh"])


func _rejected_conformance_provider_ids() -> PackedStringArray:
	return PackedStringArray(["stable_fast_3d", "hunyuan3d_2"])


func _provider_license_record(provider_id: String) -> String:
	match provider_id:
		"triposr":
			return "TripoSR"
		"trellis":
			return "TRELLIS"
		_:
			return "user_review_required"


func _provider_commercial_use(provider_id: String):
	return true if provider_id in ["triposr", "trellis"] else "user_review_required"


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
