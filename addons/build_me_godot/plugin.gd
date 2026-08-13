@tool
extends EditorPlugin

const BuildMeGodotDock = preload("res://addons/build_me_godot/ui/build_me_godot_dock.gd")
const BuildMeGodotEditorSettings = preload("res://addons/build_me_godot/services/editor_settings.gd")

var dock: Control
var dock_scroll: ScrollContainer


func _enter_tree() -> void:
	BuildMeGodotEditorSettings.register(get_editor_interface().get_editor_settings())
	dock = BuildMeGodotDock.new()
	dock_scroll = ScrollContainer.new()
	dock_scroll.name = "Build Me Godot"
	dock_scroll.custom_minimum_size = Vector2(320, 0)
	dock_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_scroll.add_child(dock)
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_scroll)


func _exit_tree() -> void:
	if dock_scroll:
		remove_control_from_docks(dock_scroll)
		dock_scroll.queue_free()
		dock_scroll = null
	elif dock:
		dock.queue_free()
	dock = null
