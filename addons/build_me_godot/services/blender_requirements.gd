@tool
extends RefCounted

const REQUIREMENTS := "res://addons/build_me_godot/integrations/blender/build_humanoid_character.requirements.json"


static func load_metadata(path := REQUIREMENTS) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Blender builder requirements not found: %s" % path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		return {"ok": false, "error": "Unsupported Blender builder requirements: %s" % path}
	return {"ok": true, "metadata": parsed}


static func validate_config(config: Dictionary, metadata: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for field in metadata.get("configuration", {}).get("required", []):
		if not config.has(field):
			errors.append("Missing required Blender configuration field: %s" % field)
	if config.get("pose_contract") != metadata.get("pose_contract"):
		errors.append("Unsupported pose_contract: %s" % config.get("pose_contract"))
	return errors


static func validate_report(report: Dictionary, metadata: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for field in metadata.get("outputs", {}).get("report_required_fields", []):
		if not report.has(field):
			errors.append("Missing required Blender report field: %s" % field)
	return errors
