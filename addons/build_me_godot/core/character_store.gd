@tool
extends RefCounted

const SCHEMA_VERSION := 1
const WORKSPACE_ROOT := "res://build_me_godot"

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
	return {
		"schema_version": SCHEMA_VERSION,
		"character_id": character_id,
		"display_name": character_id.replace("_", " ").capitalize(),
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
		"licenses": [],
		"created_at": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_datetime_string_from_system(true)
	}


func _normalize_id(value: String) -> String:
	var normalized := value.strip_edges().to_snake_case()
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789_"
	for character in normalized:
		if not allowed.contains(character):
			return ""
	return normalized
