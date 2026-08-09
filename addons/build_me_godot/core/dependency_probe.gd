@tool
extends RefCounted


static func blender(executable: String) -> Dictionary:
	var command := executable.strip_edges()
	if command.is_empty():
		command = "blender"
	var output := []
	var exit_code := OS.execute(command, ["--version"], output, true)
	if exit_code != 0 or output.is_empty():
		return {"ok": false, "label": "Blender not found", "detail": command}
	var first_line := str(output[0]).split("\n", false)[0]
	var version := PackedInt32Array()
	var parts := first_line.split(" ", false)
	if parts.size() >= 2:
		for component in parts[1].split("."):
			if not component.is_valid_int():
				break
			version.append(component.to_int())
	return {"ok": true, "label": first_line, "detail": command, "version": version}


static func gator_model_studio() -> Dictionary:
	const plugin_path := "res://addons/gator_model_studio/plugin.cfg"
	if not FileAccess.file_exists(plugin_path):
		return {"ok": false, "label": "not installed (optional)", "detail": plugin_path}
	var config := ConfigFile.new()
	if config.load(plugin_path) != OK:
		return {"ok": false, "label": "manifest unreadable", "detail": plugin_path}
	var version := str(config.get_value("plugin", "version", "unknown"))
	var enabled_plugins := ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()) as PackedStringArray
	var enabled := enabled_plugins.has(plugin_path)
	var state := "enabled" if enabled else "installed, disabled"
	return {"ok": true, "label": "%s (%s)" % [version, state], "detail": plugin_path}
