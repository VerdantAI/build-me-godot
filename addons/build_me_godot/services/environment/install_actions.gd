@tool
extends RefCounted


static func apply(action: Dictionary) -> Dictionary:
	match str(action.get("id", "")):
		"create.project.workspace": return _create_workspace()
		"install.comfyui.turnaround_helper": return _copy_comfyui_helper(action)
		_: return {"ok": false, "error": "Action is manual or unknown: %s" % action.get("id", "")}


static func _create_workspace() -> Dictionary:
	var created := PackedStringArray()
	for path in ["res://build_me_godot", "res://build_me_godot/characters"]:
		var absolute := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute):
			continue
		var error := DirAccess.make_dir_recursive_absolute(absolute)
		if error != OK:
			return {"ok": false, "error": "Could not create %s: %s" % [path, error_string(error)], "changed_paths": created}
		created.append(path)
	return {"ok": true, "changed_paths": created, "verification": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://build_me_godot/characters"))}


static func _copy_comfyui_helper(action: Dictionary) -> Dictionary:
	var target := str(action.get("target", ""))
	if target.is_empty():
		return {"ok": false, "error": "A ComfyUI root is required."}
	var target_dir := target.get_base_dir()
	if target_dir.get_file() != "custom_nodes" or not DirAccess.dir_exists_absolute(target_dir):
		return {"ok": false, "error": "Existing ComfyUI custom_nodes directory not found: %s" % target_dir}
	if FileAccess.file_exists(target):
		return {"ok": false, "error": "Target exists; automatic overwrite is disabled: %s" % target}
	var source := ProjectSettings.globalize_path(str(action.source))
	var error := DirAccess.copy_absolute(source, target)
	if error != OK:
		return {"ok": false, "error": "Could not copy helper: %s" % error_string(error)}
	return {"ok": true, "changed_paths": [target], "verification": FileAccess.file_exists(target), "restart_required": true}
