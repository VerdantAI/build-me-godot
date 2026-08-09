@tool
extends EditorPlugin


const PLUGIN_NAME = "Build Me Godot"


func _enter_tree() -> void:
	print("[%s] Plugin enabled." % PLUGIN_NAME)


func _exit_tree() -> void:
	print("[%s] Plugin disabled." % PLUGIN_NAME)
