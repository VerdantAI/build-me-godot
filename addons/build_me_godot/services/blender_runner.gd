@tool
extends RefCounted

const BUILD_SCRIPT := "res://addons/build_me_godot/integrations/blender/build_humanoid_character.py"


func start_build(blender_executable: String, config_path: String) -> Dictionary:
	var executable := blender_executable.strip_edges()
	if executable.is_empty():
		executable = "blender"
	if not FileAccess.file_exists(config_path):
		return {"ok": false, "error": "Blender configuration not found: %s" % config_path}
	var arguments := PackedStringArray([
		"-b",
		"--factory-startup",
		"--python", ProjectSettings.globalize_path(BUILD_SCRIPT),
		"--",
		"--config", ProjectSettings.globalize_path(config_path),
		"--project-root", ProjectSettings.globalize_path("res://")
	])
	var pid := OS.create_process(executable, arguments)
	if pid <= 0:
		return {"ok": false, "error": "Could not start Blender: %s" % executable}
	return {"ok": true, "pid": pid}


func is_running(pid: int) -> bool:
	return pid > 0 and OS.is_process_running(pid)


func load_report(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Build report not found: %s" % path}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "Invalid Blender build report: %s" % path}
	return {"ok": true, "report": parsed}
