@tool
extends RefCounted


static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Requirements file not found: %s" % path}
	var requirements = JSON.parse_string(file.get_as_text())
	if not requirements is Dictionary or int(requirements.get("schema_version", 0)) != 1:
		return {"ok": false, "error": "Unsupported requirements file: %s" % path}
	return {"ok": true, "requirements": requirements}


static func validate_workflow(workflow_path: String, requirements_path: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var workflow_file := FileAccess.open(workflow_path, FileAccess.READ)
	if workflow_file == null:
		errors.append("Workflow not found: %s" % workflow_path)
		return errors
	var workflow = JSON.parse_string(workflow_file.get_as_text())
	if not workflow is Dictionary:
		errors.append("Workflow is invalid JSON: %s" % workflow_path)
		return errors
	if workflow.size() == 1 and workflow.get("prompt") is Dictionary:
		workflow = workflow.prompt

	var loaded := load_file(requirements_path)
	if not loaded.ok:
		errors.append(loaded.error)
		return errors
	var requirements: Dictionary = loaded.requirements
	var declared_nodes := PackedStringArray(requirements.get("required_node_classes", []))
	var declared_models := {}
	for artifact in requirements.get("model_artifacts", []):
		declared_models["%s:%s:%s" % [artifact.loader, artifact.input, artifact.value]] = true

	for node in workflow.values():
		var class_type := str(node.get("class_type", ""))
		if not declared_nodes.has(class_type):
			errors.append("Undeclared workflow node class: %s" % class_type)
		for input_name in ["clip_name", "vae_name", "unet_name", "lora_name"]:
			if node.get("inputs", {}).get(input_name) is String:
				var key := "%s:%s:%s" % [class_type, input_name, node.inputs[input_name]]
				if not declared_models.has(key):
					errors.append("Undeclared model artifact: %s" % key)
	return errors
