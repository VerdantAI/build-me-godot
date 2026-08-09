@tool
extends EditorPlugin

const BuildMeGodotDock = preload("res://addons/build_me_godot/ui/build_me_godot_dock.gd")
const BuildMeGodotEditorSettings = preload("res://addons/build_me_godot/services/editor_settings.gd")

var dock: Control


func _enter_tree() -> void:
	BuildMeGodotEditorSettings.register(get_editor_interface().get_editor_settings())
	dock = BuildMeGodotDock.new()
	dock.name = "Build Me Godot"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
