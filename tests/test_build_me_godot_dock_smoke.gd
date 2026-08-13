extends SceneTree

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")
const BuildMeGodotDock = preload("res://addons/build_me_godot/ui/build_me_godot_dock.gd")

const BASE_CHARACTER_SCENE := "res://addons/build_me_godot/examples/base_characters.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_root := "user://dock_smoke/%s" % Time.get_ticks_usec()
	var store := CharacterStore.new(test_root)
	var dock := BuildMeGodotDock.new()
	dock.store = store
	get_root().add_child(dock)
	await process_frame
	if not _check(dock.prompt.text.contains("neutral A-pose"), "dock default prompt was not populated"): return
	if not _check(dock.negative_prompt.text.contains("cropped head"), "dock default negative prompt was not populated"): return
	if not _check(dock.example_scene_path.text == BASE_CHARACTER_SCENE, "dock default base character scene was not populated"): return
	if not _check(dock.status_indicators.has("comfyui.reachable"), "dock did not create the ComfyUI running indicator"): return
	if not _check(dock.status_indicators.has("ollama.running"), "dock did not create the Ollama running indicator"): return
	if not _check(dock.status_indicators["example.scene"].value.text == "Yes", "packaged base scene should be available"): return
	if not _check(_base_character_scene_has_rigged_mannequins(), "packaged base scene should contain two rigged mannequins with animations"): return
	if not _check(_has_menu_item_text(dock, "Save JSON report"), "dock setup did not expose a Save JSON report action"): return
	dock._begin_dependency_check(false)
	if not _check(dock.dependency_check_button.disabled, "dependency button was not disabled while checking"): return
	if not _check(dock.status_indicators["comfyui.nodes"].value.text.contains("Checking"), "ComfyUI node status did not show the spinner state"): return
	dock._advance_dependency_spinner()
	if not _check(dock.dependency_status.text.contains("Checking local environment"), "dependency summary did not show the spinner state"): return
	dock._end_dependency_check()
	if not _check(not dock.dependency_check_button.disabled and dock.dependency_check_button.text == "Check dependencies", "dependency button was not restored after checking"): return

	dock.character_id.text = "Dock Smoke"
	dock.display_name.text = "Dock Smoke"
	dock.role.text = "test role"
	dock.style_notes.text = "test style"
	dock.prompt.text = "full body character"
	dock.negative_prompt.text = "cropped"
	dock.primary_rigged_mesh.text = "res://characters/primary.glb"
	dock.secondary_rigged_mesh.text = "res://characters/secondary.glb"
	dock.animation_asset.text = "res://animations/humanoid.glb"
	var saved := dock._save_character()
	if not _check(saved.ok, saved.get("error", "dock draft save failed")): return

	var run := store.create_generation_run("dock_smoke", {"status": "pending"})
	if not _check(run.ok, run.get("error", "dock run creation failed")): return
	var fake_comfy_output_root := ProjectSettings.globalize_path(test_root.path_join("fake_comfy/output"))
	var fake_comfy_character_dir := fake_comfy_output_root.path_join("character_turnaround/dock_smoke")
	DirAccess.make_dir_recursive_absolute(fake_comfy_character_dir)
	var fake_image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	fake_image.fill(Color.WHITE)
	fake_image.save_png(fake_comfy_character_dir.path_join("front.png"))
	var completed := store.complete_generation_run(
		"dock_smoke",
		"v1",
		{
			"outputs": {
				"save_front": {
					"images": [{
						"filename": "front.png",
						"subfolder": "character_turnaround/dock_smoke",
						"type": "output"
					}]
				}
			}
		},
		fake_comfy_output_root,
		"res://addons/build_me_godot/workflows/canonical_only_api.requirements.json"
	)
	if not _check(completed.ok, completed.get("error", "dock completion failed")): return
	dock._refresh_review(completed.manifest)
	if not _check(dock.run_select.item_count == 1, "dock review did not list the completed run"): return
	if not _check(dock.run_details.text.contains("Version: v1"), "dock review did not render run details"): return

	dock._approve_selected_run()
	var approved := store.load_character("dock_smoke")
	if not _check(approved.ok and approved.manifest.generation.selected_version == "v1", "dock approval did not select v1"): return
	dock._continue_selected_run()
	var continued := store.load_character("dock_smoke")
	if not _check(continued.ok and continued.manifest.stage == "pipeline_enabled", "dock continuation did not enable pipeline"): return
	dock.queue_free()
	await process_frame
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _has_button_text(node: Node, text: String) -> bool:
	if node is Button and node.text == text:
		return true
	for child in node.get_children():
		if _has_button_text(child, text):
			return true
	return false


func _has_menu_item_text(node: Node, text: String) -> bool:
	if node is MenuButton:
		var popup: PopupMenu = node.get_popup()
		for index in popup.item_count:
			if popup.get_item_text(index) == text:
				return true
	for child in node.get_children():
		if _has_menu_item_text(child, text):
			return true
	return false


func _base_character_scene_has_rigged_mannequins() -> bool:
	var scene := load(BASE_CHARACTER_SCENE)
	if not scene is PackedScene:
		return false
	var instance: Node = scene.instantiate()
	get_root().add_child(instance)
	var primary := instance.get_node_or_null("PrimaryRiggedMesh")
	var secondary := instance.get_node_or_null("SecondaryRiggedMesh")
	var ok := (
		_mannequin_has_rig_and_animations(primary)
		and _mannequin_has_rig_and_animations(secondary)
	)
	instance.queue_free()
	return ok


func _mannequin_has_rig_and_animations(node: Node) -> bool:
	return (
		node != null
		and _has_descendant_class(node, "Skeleton3D")
		and _has_animation_library(node)
	)


func _has_descendant_class(node: Node, expected_class: String) -> bool:
	if node.is_class(expected_class):
		return true
	for child in node.get_children():
		if _has_descendant_class(child, expected_class):
			return true
	return false


func _has_animation_library(node: Node) -> bool:
	if node is AnimationPlayer and not node.get_animation_library_list().is_empty():
		return true
	for child in node.get_children():
		if _has_animation_library(child):
			return true
	return false
