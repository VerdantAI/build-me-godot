extends SceneTree

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")


func _init() -> void:
	var test_root := "user://tests/%s" % Time.get_ticks_usec()
	var store := CharacterStore.new(test_root)
	for character in [
		{"id": "party_fighter_v1", "role": "fighter", "equipment": [{"part_id": "sword", "socket": "hand_r", "representation": "primitive", "object": "EQUIP_sword"}]},
		{"id": "village_healer_v1", "role": "healer", "equipment": [{"part_id": "staff", "socket": "hand_r", "representation": "primitive", "object": "EQUIP_staff"}]}
	]:
		if not _prepare_registered_character(store, test_root, character):
			return
		var loaded := store.load_character(character.id)
		if not _check(loaded.ok, loaded.get("error", "manifest did not load")): return
		if not _check(loaded.manifest.stage == "assembly_registered", "character was not registered for play-test: %s" % character.id): return
		var scene_path := str(loaded.manifest.assets.character_scene)
		if not _check(FileAccess.file_exists(scene_path), "registered scene does not exist: %s" % scene_path): return
		var packed := ResourceLoader.load(scene_path)
		if not _check(packed is PackedScene, "registered scene did not load as PackedScene: %s" % scene_path): return
		var instance = packed.instantiate()
		if not _check(instance is Node3D, "registered scene root is not Node3D: %s" % scene_path): return
		if not _check(instance.get_node_or_null("Model") != null, "registered scene is missing Model node: %s" % scene_path): return
		var animation_player: Node = instance.get_node_or_null("AnimationPlayer")
		if not _check(animation_player is AnimationPlayer, "registered scene is missing AnimationPlayer: %s" % scene_path): return
		if not _check(animation_player.has_animation_library("UAL1_Standard"), "registered scene is missing UAL1_Standard animation library: %s" % scene_path): return
		var animation_library: AnimationLibrary = animation_player.get_animation_library("UAL1_Standard")
		if not _check(animation_library.has_animation("Idle"), "registered scene is missing Idle animation: %s" % scene_path): return
		if not _check(animation_library.has_animation("Walk"), "registered scene is missing Walk animation: %s" % scene_path): return
		if not _check(instance.get_node_or_null("Sockets/hand_r") != null, "registered scene is missing hand_r socket: %s" % scene_path): return
		instance.free()
	quit(0)


func _prepare_registered_character(store: CharacterStore, root: String, character: Dictionary) -> bool:
	var saved := store.save_character({
		"character_id": str(character.id),
		"display_name": str(character.id).capitalize(),
		"metadata": {"role": str(character.role), "style": "isometric fixture", "pose_contract": "neutral_a_pose_30deg_v1"},
		"prompt": "fixture concept already approved",
		"rigged_meshes": {
			"primary": root.path_join("source/%s_primary.glb" % str(character.id)),
			"secondary": root.path_join("source/%s_secondary.glb" % str(character.id))
		}
	})
	if not _check(saved.ok, saved.get("error", "save failed")): return false
	var character_id := str(saved.manifest.character_id)
	var import_scene_path := root.path_join("characters/%s/assembly/v1/%s_import.tscn" % [character_id, character_id])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(import_scene_path.get_base_dir()))
	_write_text(import_scene_path, "[gd_scene format=3]\n\n[node name=\"ImportedModel\" type=\"Node3D\"]\n")
	var manifest: Dictionary = saved.manifest
	manifest["generation"] = {
		"selected_version": "v1",
		"runs": [{
			"run_id": "%s_reference" % character_id,
			"version": "v1",
			"status": "completed",
			"positive_prompt": "fixture concept already approved",
			"negative_prompt": "",
			"outputs": {"front": root.path_join("characters/%s/references/v1/front.png" % character_id)}
		}]
	}
	var updated := store.save_character(manifest)
	if not _check(updated.ok, updated.get("error", "generation setup failed")): return false
	var approved := store.approve_generation_version(character_id, "v1")
	if not _check(approved.ok, approved.get("error", "approval failed")): return false
	var recipe := store.create_character_recipe(character_id, {"version": "v1", "game_mode_profile_id": "3d_isometric_party"})
	if not _check(recipe.ok, recipe.get("error", "recipe failed")): return false
	var approved_recipe := store.approve_character_recipe(character_id, {"version": "v1"})
	if not _check(approved_recipe.ok, approved_recipe.get("error", "recipe approval failed")): return false
	var assembly_report_path := root.path_join("characters/%s/assembly/v1/assembly_report.json" % character_id)
	var report := {
		"schema_version": 1,
		"status": "assembled",
		"character_id": character_id,
		"recipe_version": "v1",
		"recipe_path": root.path_join("characters/%s/recipes/v1/character_recipe.json" % character_id),
		"warnings": [],
		"body_source": root.path_join("source/%s_primary.glb" % character_id),
		"body_objects": ["ImportedModel"],
		"reference_images": [root.path_join("characters/%s/references/v1/front.png" % character_id)],
		"sockets": [{"name": "hand_r", "parent_bone": "RightHand", "required": true}],
		"equipment": character.equipment,
		"outputs": {
			"blender_work_file": root.path_join("characters/%s/assembly/v1/%s.blend" % [character_id, character_id]),
			"godot_import_asset": import_scene_path,
			"assembly_report": assembly_report_path
		}
	}
	var report_file := FileAccess.open(assembly_report_path, FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	report_file.close()
	var registered := store.register_assembly_result(character_id, {"version": "v1", "assembly_report": assembly_report_path})
	return _check(registered.ok, registered.get("error", "registration failed"))


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _write_text(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
