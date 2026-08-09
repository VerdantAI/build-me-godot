@tool
extends RefCounted

const Config = preload("res://addons/build_me_godot/services/config.gd")

const DEFINITIONS := {
	"build_me_godot/comfyui_url": {
		"default": Config.DEFAULTS[Config.COMFYUI_URL],
		"type": TYPE_STRING
	},
	"build_me_godot/comfyui_root": {
		"default": Config.DEFAULTS[Config.COMFYUI_ROOT],
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_DIR
	},
	"build_me_godot/blender_path": {
		"default": Config.DEFAULTS[Config.BLENDER_PATH],
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE
	},
	"build_me_godot/reconstruction_command": {
		"default": Config.DEFAULTS[Config.RECONSTRUCTION_COMMAND],
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE
	},
	"build_me_godot/animation_asset": {
		"default": Config.DEFAULTS[Config.ANIMATION_ASSET],
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_GLOBAL_FILE,
		"hint_string": "*.glb,*.gltf"
	}
}


static func register(settings: EditorSettings) -> void:
	for name in DEFINITIONS:
		var definition: Dictionary = DEFINITIONS[name]
		if not settings.has_setting(name):
			settings.set_setting(name, definition.default)
		settings.set_initial_value(name, definition.default, false)
		var info := {"name": name, "type": definition.type}
		if definition.has("hint"):
			info["hint"] = definition.hint
		if definition.has("hint_string"):
			info["hint_string"] = definition.hint_string
		settings.add_property_info(info)
