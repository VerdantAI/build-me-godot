@tool
extends VBoxContainer

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")
const ComfyUIClient = preload("res://addons/build_me_godot/services/comfyui_client.gd")
const TurnaroundWorkflow = preload("res://addons/build_me_godot/services/turnaround_workflow.gd")
const EnvironmentChecker = preload("res://addons/build_me_godot/services/environment/environment_checker.gd")
const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const Config = preload("res://addons/build_me_godot/services/config.gd")

var store := CharacterStore.new()
var character_select: OptionButton
var project_context: Label
var character_id: LineEdit
var display_name: LineEdit
var role: LineEdit
var style_notes: LineEdit
var prompt: TextEdit
var negative_prompt: TextEdit
var seed: SpinBox
var primary_rigged_mesh: LineEdit
var secondary_rigged_mesh: LineEdit
var comfyui_url: LineEdit
var comfyui_root: LineEdit
var blender_path: LineEdit
var reconstruction_command: LineEdit
var animation_asset: LineEdit
var dependency_status: RichTextLabel
var technical_details: CheckButton
var status: Label
var comfy_client: Node
var environment_checker: Node
var last_environment_report := {}
var configuration_status: Label
var pending_generation_character_id := ""
var pending_generation_version := ""


func _ready() -> void:
	_build_ui()
	_load_configuration()
	_refresh_characters()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "Build Me Godot"
	title.add_theme_font_size_override("font_size", 20)
	add_child(title)

	character_select = OptionButton.new()
	character_select.tooltip_text = "Saved project characters"
	character_select.item_selected.connect(_on_character_selected)
	add_child(character_select)

	project_context = Label.new()
	project_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	project_context.text = "Project: %s" % ProjectSettings.get_setting("application/config/name", "Unnamed project")
	add_child(project_context)

	character_id = _add_line_edit("Character ID", "field_engineer")
	display_name = _add_line_edit("Display name", "Field Engineer")
	role = _add_line_edit("Role / archetype", "construction field engineer")
	style_notes = _add_line_edit("Style notes", "realistic game character")
	prompt = _add_text_edit("Character prompt", 150)
	negative_prompt = _add_text_edit("Negative prompt", 80)
	var rigged_mesh_title := Label.new()
	rigged_mesh_title.text = "Rigged mesh inputs"
	add_child(rigged_mesh_title)
	primary_rigged_mesh = _add_line_edit("Primary rigged mesh", CharacterStore.DEFAULT_PRIMARY_RIGGED_MESH)
	secondary_rigged_mesh = _add_line_edit("Secondary rigged mesh", CharacterStore.DEFAULT_SECONDARY_RIGGED_MESH)

	seed = SpinBox.new()
	seed.min_value = 0
	seed.max_value = 2147483647
	seed.allow_greater = true
	seed.value = 0
	_add_labeled_control("Seed", seed)

	var character_buttons := HBoxContainer.new()
	var new_button := Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_new_character)
	character_buttons.add_child(new_button)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_save_character)
	character_buttons.add_child(save_button)
	var template_button := Button.new()
	template_button.text = "Field Engineer example"
	template_button.pressed.connect(_create_field_engineer)
	character_buttons.add_child(template_button)
	add_child(character_buttons)

	add_child(HSeparator.new())
	var dependencies_title := Label.new()
	dependencies_title.text = "Local dependencies"
	add_child(dependencies_title)
	comfyui_url = _add_line_edit("ComfyUI URL", "http://127.0.0.1:8188")
	comfyui_root = _add_line_edit("ComfyUI directory", "/path/to/ComfyUI")
	blender_path = _add_line_edit("Blender executable", "blender")
	reconstruction_command = _add_line_edit("Reconstruction command", "/path/to/provider")
	animation_asset = _add_line_edit("Animation library", "res://path/to/animations.glb")
	var settings_buttons := HBoxContainer.new()
	var save_global_button := Button.new()
	save_global_button.text = "Save for me"
	save_global_button.tooltip_text = "Editor settings for this developer across projects"
	save_global_button.pressed.connect(_save_configuration.bind(false))
	settings_buttons.add_child(save_global_button)
	var save_local_button := Button.new()
	save_local_button.text = "Save for this project"
	save_local_button.tooltip_text = "Gitignored project settings also available to headless tools"
	save_local_button.pressed.connect(_save_configuration.bind(true))
	settings_buttons.add_child(save_local_button)
	add_child(settings_buttons)
	configuration_status = Label.new()
	configuration_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(configuration_status)
	var probe_button := Button.new()
	probe_button.text = "Check dependencies"
	probe_button.pressed.connect(_check_dependencies)
	add_child(probe_button)
	var deep_probe_button := Button.new()
	deep_probe_button.text = "Deep-check Blender"
	deep_probe_button.tooltip_text = "Starts Blender in background mode and verifies the builder operators"
	deep_probe_button.pressed.connect(_deep_check_dependencies)
	add_child(deep_probe_button)
	var report_buttons := HBoxContainer.new()
	var copy_report_button := Button.new()
	copy_report_button.text = "Copy report"
	copy_report_button.pressed.connect(_copy_environment_report)
	report_buttons.add_child(copy_report_button)
	var save_report_button := Button.new()
	save_report_button.text = "Save report"
	save_report_button.pressed.connect(_save_environment_report)
	report_buttons.add_child(save_report_button)
	add_child(report_buttons)
	technical_details = CheckButton.new()
	technical_details.text = "Show technical details"
	technical_details.toggled.connect(_toggle_technical_details)
	add_child(technical_details)
	var canonical_button := Button.new()
	canonical_button.text = "Queue canonical character"
	canonical_button.tooltip_text = "Explicitly queue the selected character in local ComfyUI"
	canonical_button.pressed.connect(_queue_canonical)
	add_child(canonical_button)

	dependency_status = RichTextLabel.new()
	dependency_status.fit_content = true
	dependency_status.custom_minimum_size.y = 55
	add_child(dependency_status)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)

	comfy_client = ComfyUIClient.new()
	comfy_client.prompt_queued.connect(_on_prompt_queued)
	comfy_client.history_received.connect(_on_history_received)
	comfy_client.request_failed.connect(_on_comfy_error)
	add_child(comfy_client)

	environment_checker = EnvironmentChecker.new()
	add_child(environment_checker)


func _add_line_edit(label_text: String, placeholder: String) -> LineEdit:
	var control := LineEdit.new()
	control.placeholder_text = placeholder
	_add_labeled_control(label_text, control)
	return control


func _add_text_edit(label_text: String, minimum_height: float) -> TextEdit:
	var control := TextEdit.new()
	control.custom_minimum_size.y = minimum_height
	control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(label_text, control)
	return control


func _add_labeled_control(label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	add_child(label)
	add_child(control)


func _refresh_characters(selected_id := "") -> void:
	character_select.clear()
	character_select.add_item("Select a character…")
	for id in store.list_characters():
		character_select.add_item(id)
		character_select.set_item_metadata(character_select.item_count - 1, id)
		if id == selected_id:
			character_select.select(character_select.item_count - 1)


func _on_character_selected(index: int) -> void:
	if index == 0:
		return
	var result := store.load_character(str(character_select.get_item_metadata(index)))
	if not result.ok:
		_set_status(result.error, true)
		return
	var manifest: Dictionary = result.manifest
	character_id.text = str(manifest.get("character_id", ""))
	display_name.text = str(manifest.get("display_name", ""))
	var metadata: Dictionary = manifest.get("metadata", {})
	role.text = str(metadata.get("role", ""))
	style_notes.text = str(metadata.get("style", ""))
	prompt.text = str(manifest.get("prompt", ""))
	negative_prompt.text = str(manifest.get("negative_prompt", ""))
	var rigged_meshes: Dictionary = manifest.get("rigged_meshes", {})
	primary_rigged_mesh.text = str(rigged_meshes.get("primary", CharacterStore.DEFAULT_PRIMARY_RIGGED_MESH))
	secondary_rigged_mesh.text = str(rigged_meshes.get("secondary", CharacterStore.DEFAULT_SECONDARY_RIGGED_MESH))
	seed.value = int(manifest.get("seed", 0))
	_set_status("Loaded %s" % result.path)


func _new_character() -> void:
	character_select.select(0)
	character_id.clear()
	display_name.clear()
	role.clear()
	style_notes.clear()
	prompt.clear()
	negative_prompt.clear()
	primary_rigged_mesh.text = CharacterStore.DEFAULT_PRIMARY_RIGGED_MESH
	secondary_rigged_mesh.text = CharacterStore.DEFAULT_SECONDARY_RIGGED_MESH
	seed.value = 0
	_set_status("Enter a character ID and prompt, then save.")


func _save_character() -> Dictionary:
	var values := _draft_values()
	var errors := store.validate_draft(values)
	if not errors.is_empty():
		var result := {"ok": false, "error": "\n".join(errors)}
		_set_status(result.error, true)
		return result
	var result := store.save_draft(values)
	if not result.ok:
		_set_status(result.error, true)
		return result
	character_id.text = result.manifest.character_id
	_refresh_characters(result.manifest.character_id)
	_set_status("Saved %s" % result.path)
	return result


func _draft_values() -> Dictionary:
	return {
		"character_id": character_id.text,
		"display_name": display_name.text,
		"metadata": {
			"role": role.text.strip_edges(),
			"style": style_notes.text.strip_edges(),
			"pose_contract": "neutral_a_pose_30deg_v1"
		},
		"prompt": prompt.text,
		"negative_prompt": negative_prompt.text,
		"rigged_meshes": {
			"primary": primary_rigged_mesh.text.strip_edges(),
			"secondary": secondary_rigged_mesh.text.strip_edges()
		},
		"animation_asset": animation_asset.text.strip_edges(),
		"seed": int(seed.value)
	}


func _create_field_engineer() -> void:
	var result := store.create_from_template("res://addons/build_me_godot/templates/field_engineer.json")
	if not result.ok:
		_set_status(result.error, true)
		return
	_refresh_characters(result.manifest.character_id)
	var selected := character_select.selected
	_on_character_selected(selected)
	_set_status("Created %s" % result.path)


func _load_configuration() -> void:
	var settings := EditorInterface.get_editor_settings()
	var values := Config.resolve({}, settings)
	comfyui_url.text = str(values[Config.COMFYUI_URL])
	comfyui_root.text = str(values[Config.COMFYUI_ROOT])
	blender_path.text = str(values[Config.BLENDER_PATH])
	reconstruction_command.text = str(values[Config.RECONSTRUCTION_COMMAND])
	animation_asset.text = str(values[Config.ANIMATION_ASSET])
	var sources: Array[String] = []
	for key in Config.DEFAULTS:
		sources.append("%s: %s" % [key, Config.source_of(key, {}, settings)])
	configuration_status.text = ", ".join(sources)


func _save_configuration(local: bool) -> void:
	var settings := EditorInterface.get_editor_settings()
	var values := {
		Config.COMFYUI_URL: comfyui_url.text.strip_edges(),
		Config.COMFYUI_ROOT: comfyui_root.text.strip_edges(),
		Config.BLENDER_PATH: blender_path.text.strip_edges(),
		Config.RECONSTRUCTION_COMMAND: reconstruction_command.text.strip_edges(),
		Config.ANIMATION_ASSET: animation_asset.text.strip_edges()
	}
	if local:
		var error := Config.save_local(values)
		if error != OK:
			_set_status("Could not write %s: %s" % [Config.LOCAL_FILE, error_string(error)], true)
			return
	else:
		for key in values:
			settings.set_setting(Config.EDITOR_PREFIX + key, values[key])
	_load_configuration()
	_set_status("Saved %s configuration." % ("project-local" if local else "global editor"))


func _check_dependencies() -> void:
	await _run_environment_check(false)


func _deep_check_dependencies() -> void:
	await _run_environment_check(true)


func _run_environment_check(deep_check: bool) -> void:
	dependency_status.text = "Checking local environment…"
	var report: Dictionary = await environment_checker.check("all", {
		"comfyui_url": comfyui_url.text,
		"comfyui_root": comfyui_root.text,
		"blender_executable": blender_path.text,
		"reconstruction_command": reconstruction_command.text,
		"animation_asset": animation_asset.text,
		"deep_check": deep_check
	})
	last_environment_report = report
	_render_environment_report()


func _toggle_technical_details(_enabled: bool) -> void:
	_render_environment_report()


func _render_environment_report() -> void:
	if last_environment_report.is_empty():
		return
	dependency_status.text = JSON.stringify(EnvironmentReport.redact(last_environment_report), "  ") if technical_details.button_pressed else EnvironmentReport.render_text(last_environment_report)


func _copy_environment_report() -> void:
	if last_environment_report.is_empty():
		_set_status("Run the environment check before copying a report.", true)
		return
	DisplayServer.clipboard_set(JSON.stringify(EnvironmentReport.redact(last_environment_report), "  "))
	_set_status("Environment report copied as JSON.")


func _save_environment_report() -> void:
	if last_environment_report.is_empty():
		_set_status("Run the environment check before saving a report.", true)
		return
	var directory := "res://build_me_godot/reports"
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		_set_status("Could not create the report directory: %s" % error_string(error), true)
		return
	var path := directory.path_join("environment.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Could not write %s" % path, true)
		return
	file.store_string(JSON.stringify(EnvironmentReport.redact(last_environment_report), "  ") + "\n")
	_set_status("Saved %s" % path)


func _queue_canonical() -> void:
	var errors := store.validate_draft(_draft_values(), true)
	if not errors.is_empty():
		_set_status("\n".join(errors), true)
		return
	var saved := _save_character()
	if not saved.ok:
		return
	var loaded := store.load_character(character_id.text)
	if not loaded.ok:
		_set_status(loaded.error, true)
		return
	var workflow_path := str(loaded.manifest.get("workflow", {}).get("canonical", TurnaroundWorkflow.CANONICAL_WORKFLOW))
	var workflow: Dictionary = comfy_client.load_api_workflow(workflow_path)
	if workflow.is_empty():
		return
	workflow = TurnaroundWorkflow.configure_canonical(workflow, loaded.manifest)
	if workflow.is_empty():
		_set_status("The canonical workflow is missing required template inputs.", true)
		return
	var run := store.create_generation_run(saved.manifest.character_id, {
		"workflow_id": "canonical_character_reference",
		"workflow_version": "1",
		"status": "pending",
		"positive_prompt": str(saved.manifest.get("prompt", "")),
		"negative_prompt": str(saved.manifest.get("negative_prompt", "")),
		"seed": int(saved.manifest.get("seed", 0))
	})
	if not run.ok:
		_set_status(run.error, true)
		return
	var runs: Array = run.manifest.generation.runs
	var run_record: Dictionary = runs[runs.size() - 1]
	pending_generation_character_id = str(run.manifest.character_id)
	pending_generation_version = str(run_record.version)
	comfy_client.configure(comfyui_url.text)
	var error: Error = comfy_client.queue_prompt(workflow)
	if error != OK:
		store.update_generation_run(pending_generation_character_id, pending_generation_version, {
			"status": "failed",
			"error": "Could not start the ComfyUI queue request (%s)." % error_string(error),
			"completed_at": Time.get_datetime_string_from_system(true)
		})
		_set_status("Could not start the ComfyUI queue request (%s)." % error_string(error), true)
		return
	_set_status("Submitting %s to ComfyUI…" % pending_generation_version)


func _on_prompt_queued(prompt_id: String) -> void:
	if not pending_generation_character_id.is_empty() and not pending_generation_version.is_empty():
		store.update_generation_run(pending_generation_character_id, pending_generation_version, {
			"status": "queued",
			"prompt_id": prompt_id,
			"queued_at": Time.get_datetime_string_from_system(true)
		})
	comfy_client.request_history(prompt_id)
	_set_status("ComfyUI queued %s prompt %s" % [pending_generation_version, prompt_id])


func _on_history_received(prompt_id: String, history: Dictionary) -> void:
	if pending_generation_character_id.is_empty() or pending_generation_version.is_empty():
		return
	var prompt_history: Dictionary = history.get(prompt_id, {})
	var updates := {
		"status": "completed" if prompt_history.has("outputs") else "queued",
		"history": prompt_history,
		"completed_at": Time.get_datetime_string_from_system(true) if prompt_history.has("outputs") else ""
	}
	store.update_generation_run(pending_generation_character_id, pending_generation_version, updates)
	if prompt_history.has("outputs"):
		_set_status("ComfyUI completed %s." % pending_generation_version)


func _on_comfy_error(message: String) -> void:
	if not pending_generation_character_id.is_empty() and not pending_generation_version.is_empty():
		store.update_generation_run(pending_generation_character_id, pending_generation_version, {
			"status": "failed",
			"error": message,
			"completed_at": Time.get_datetime_string_from_system(true)
		})
	_set_status(message, true)


func _set_status(message: String, is_error := false) -> void:
	status.text = message
	status.modulate = Color("ff8080") if is_error else Color.WHITE
