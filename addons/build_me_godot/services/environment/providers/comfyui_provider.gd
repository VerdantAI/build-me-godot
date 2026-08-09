@tool
extends Node

const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const WorkflowRequirements = preload("res://addons/build_me_godot/services/workflow_requirements.gd")


func check(capability: String, base_url: String) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	var safe_url := _safe_url(base_url)
	var stats := await _get_json(base_url.trim_suffix("/") + "/system_stats")
	checks.append(EnvironmentReport.result(
		"comfyui.reachable", capability,
		"pass" if stats.ok else "fail", "required",
		"ComfyUI is reachable." if stats.ok else "ComfyUI is not reachable.",
		safe_url, "Configured local ComfyUI server", {"endpoint": safe_url + "/system_stats"},
		PackedStringArray(["configure.comfyui.url", "start.comfyui"])
	))
	if not stats.ok:
		return checks

	var object_info := await _get_json(base_url.trim_suffix("/") + "/object_info")
	if not object_info.ok:
		checks.append(EnvironmentReport.result(
			"comfyui.object_info", capability, "unknown", "required",
			"ComfyUI node metadata could not be read.", null, "ComfyUI /object_info response",
			{"endpoint": safe_url + "/object_info"}, PackedStringArray(["check.comfyui.logs"])
		))
		return checks

	for requirements_path in _requirements_for(capability):
		var loaded := WorkflowRequirements.load_file(requirements_path)
		if not loaded.ok:
			checks.append(EnvironmentReport.result(
				"workflow.requirements.%s" % requirements_path.get_file(), capability,
				"fail", "required", loaded.error, null, requirements_path
			))
			continue
		var requirements: Dictionary = loaded.requirements
		var missing_nodes := PackedStringArray()
		for class_type in requirements.required_node_classes:
			if not object_info.data.has(class_type):
				missing_nodes.append(class_type)
		checks.append(EnvironmentReport.result(
			"comfyui.nodes.%s" % requirements.workflow_id, requirements.capability,
			"pass" if missing_nodes.is_empty() else "fail", "required",
			"Required ComfyUI nodes are available." if missing_nodes.is_empty() else "Required ComfyUI nodes are missing.",
			missing_nodes, PackedStringArray(requirements.required_node_classes), {},
			PackedStringArray(["install.comfyui.turnaround_helper"])
		))
		var missing_models := _missing_models(object_info.data, requirements.model_artifacts)
		checks.append(EnvironmentReport.result(
			"comfyui.models.%s" % requirements.workflow_id, requirements.capability,
			"pass" if missing_models.is_empty() else "fail", "required",
			"Required model choices are available." if missing_models.is_empty() else "Required model choices are missing.",
			missing_models, requirements.model_artifacts, {},
			PackedStringArray(["install.manual.comfyui.models"])
		))
	return checks


func _get_json(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 5.0
	add_child(request)
	var start_error := request.request(url)
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": error_string(start_error)}
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300:
		return {"ok": false, "error": "HTTP %s" % response[1]}
	var parsed = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return {"ok": parsed is Dictionary, "data": parsed}


func _requirements_for(capability: String) -> PackedStringArray:
	var paths := PackedStringArray()
	if capability in ["all", "canonical_generation"]:
		paths.append("res://addons/build_me_godot/workflows/canonical_only_api.requirements.json")
	if capability in ["all", "multiview_generation"]:
		paths.append("res://addons/build_me_godot/workflows/multiview_only_api.requirements.json")
	return paths


func _missing_models(object_info: Dictionary, artifacts: Array) -> PackedStringArray:
	var missing := PackedStringArray()
	for artifact in artifacts:
		var node: Dictionary = object_info.get(artifact.loader, {})
		var declaration = node.get("input", {}).get("required", {}).get(artifact.input)
		var choices: Array = declaration[0] if declaration is Array and not declaration.is_empty() and declaration[0] is Array else []
		if not choices.has(artifact.value):
			missing.append(artifact.value)
	return missing


func _safe_url(value: String) -> String:
	var url := value.strip_edges()
	var scheme_end := url.find("://")
	if scheme_end < 0:
		return "configured endpoint"
	var path_start := url.find("/", scheme_end + 3)
	var origin := url if path_start < 0 else url.left(path_start)
	var at := origin.find("@", scheme_end + 3)
	if at >= 0:
		origin = origin.left(scheme_end + 3) + origin.substr(at + 1)
	return origin
