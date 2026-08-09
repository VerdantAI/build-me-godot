@tool
extends RefCounted

const LOCAL_FILE := "res://build_me_godot.local.cfg"
const SECTION := "local_models"
const EDITOR_PREFIX := "build_me_godot/"
const ENVIRONMENT_PREFIX := "BUILD_ME_GODOT_"

const COMFYUI_URL := "comfyui_url"
const COMFYUI_ROOT := "comfyui_root"
const BLENDER_PATH := "blender_path"
const RECONSTRUCTION_COMMAND := "reconstruction_command"
const ANIMATION_ASSET := "animation_asset"

const DEFAULTS := {
	COMFYUI_URL: "http://127.0.0.1:8188",
	COMFYUI_ROOT: "",
	BLENDER_PATH: "blender",
	RECONSTRUCTION_COMMAND: "",
	ANIMATION_ASSET: "",
}


static func get_value(key: String, overrides := {}, editor_settings: Object = null) -> Variant:
	if overrides.has(key):
		return overrides[key]
	var environment_value := OS.get_environment(ENVIRONMENT_PREFIX + key.to_upper())
	if not environment_value.is_empty():
		return environment_value
	var local := ConfigFile.new()
	if local.load(LOCAL_FILE) == OK and local.has_section_key(SECTION, key):
		return local.get_value(SECTION, key)
	if editor_settings != null and editor_settings.has_setting(EDITOR_PREFIX + key):
		return editor_settings.get_setting(EDITOR_PREFIX + key)
	return DEFAULTS.get(key)


static func source_of(key: String, overrides := {}, editor_settings: Object = null) -> String:
	if overrides.has(key):
		return "command line"
	if not OS.get_environment(ENVIRONMENT_PREFIX + key.to_upper()).is_empty():
		return "environment"
	var local := ConfigFile.new()
	if local.load(LOCAL_FILE) == OK and local.has_section_key(SECTION, key):
		return "local file"
	if editor_settings != null and editor_settings.has_setting(EDITOR_PREFIX + key):
		return "editor settings"
	return "default"


static func resolve(overrides := {}, editor_settings: Object = null) -> Dictionary:
	var values := {}
	for key in DEFAULTS:
		values[key] = get_value(key, overrides, editor_settings)
	return values


static func save_local(values: Dictionary) -> Error:
	var local := ConfigFile.new()
	local.load(LOCAL_FILE)
	for key in values:
		if DEFAULTS.has(key):
			local.set_value(SECTION, key, values[key])
	return local.save(LOCAL_FILE)
