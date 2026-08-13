@tool
extends VBoxContainer

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")
const ComfyUIClient = preload("res://addons/build_me_godot/services/comfyui_client.gd")
const TurnaroundWorkflow = preload("res://addons/build_me_godot/services/turnaround_workflow.gd")
const EnvironmentChecker = preload("res://addons/build_me_godot/services/environment/environment_checker.gd")
const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const Config = preload("res://addons/build_me_godot/services/config.gd")

class StatusIndicatorDot:
	extends Control

	var indicator_color := Color("6f7378")

	func _init() -> void:
		custom_minimum_size = Vector2(12, 12)

	func set_indicator_color(value: Color) -> void:
		indicator_color = value
		queue_redraw()

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.35, indicator_color)


const DEFAULT_PROMPT := "Full-body game character reference of a practical field engineer and surveyor, sturdy work boots, durable work trousers, canvas work jacket, utility belt, functional realistic clothing construction, neutral A-pose, arms approximately 30 degrees away from the torso, feet shoulder-width apart, neutral expression, straight posture, complete head and feet visible, centered, minimal perspective distortion, approximately orthographic character-development reference, uniform diffuse studio lighting, plain neutral light gray background, clothing seams and construction clearly visible, no props obscuring the body."
const DEFAULT_NEGATIVE_PROMPT := "cropped head, cropped feet, missing limbs, extra limbs, crossed arms, crossed legs, action pose, contrapposto, foreshortening, wide angle, perspective distortion, dramatic lighting, hard cast shadow, cluttered background, handheld props, text, watermark"
const DEFAULT_EXAMPLE_SCENE := "res://addons/build_me_godot/examples/base_characters.tscn"
const INDICATOR_PASS := Color("43a047")
const INDICATOR_FAIL := Color("d64545")
const INDICATOR_WARNING := Color("d6a21f")
const INDICATOR_UNKNOWN := Color("6f7378")
const SPINNER_FRAMES := ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

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
var example_scene_path: LineEdit
var comfyui_url: LineEdit
var comfyui_root: LineEdit
var blender_path: LineEdit
var reconstruction_command: LineEdit
var animation_asset: LineEdit
var workflow_import_path: LineEdit
var dependency_status: RichTextLabel
var technical_details: CheckButton
var status: Label
var comfy_client: Node
var environment_checker: Node
var last_environment_report := {}
var configuration_status: Label
var status_indicators := {}
var pending_generation_character_id := ""
var pending_generation_version := ""
var run_select: OptionButton
var reference_preview: TextureRect
var run_details: RichTextLabel
var dependency_check_button: Button
var deep_check_button: Button
var dependency_spinner: Timer
var dependency_spinner_frame := 0
var dependency_check_in_progress := false
var open_example_scene_button: Button


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

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	var draft_tab := _add_tab(tabs, "1 Draft")
	character_id = _add_line_edit(draft_tab, "Character ID", "field_engineer")
	display_name = _add_line_edit(draft_tab, "Display name", "Field Engineer")
	role = _add_line_edit(draft_tab, "Role / archetype", "construction field engineer")
	style_notes = _add_line_edit(draft_tab, "Style notes", "realistic game character")
	prompt = _add_text_edit(draft_tab, "Character prompt", 150)
	prompt.text = DEFAULT_PROMPT
	prompt.tooltip_text = "Edit the subject, clothing, silhouette, style, and pose constraints; keep full-body neutral reference requirements for Blender."
	negative_prompt = _add_text_edit(draft_tab, "Negative prompt", 80)
	negative_prompt.text = DEFAULT_NEGATIVE_PROMPT
	negative_prompt.tooltip_text = "Edit unwanted crops, pose drift, extra limbs, perspective distortion, lighting issues, and background clutter."

	seed = SpinBox.new()
	seed.min_value = 0
	seed.max_value = 2147483647
	seed.allow_greater = true
	seed.value = 0
	_add_labeled_control(draft_tab, "Seed", seed)

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
	draft_tab.add_child(character_buttons)

	var setup_tab := _add_tab(tabs, "2 Setup")
	var status_title := Label.new()
	status_title.text = "Local status"
	setup_tab.add_child(status_title)
	var status_grid := GridContainer.new()
	status_grid.columns = 2
	status_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_tab.add_child(status_grid)
	_add_status_indicator(status_grid, "comfyui.root", "ComfyUI found")
	_add_status_indicator(status_grid, "comfyui.reachable", "ComfyUI running")
	_add_status_indicator(status_grid, "comfyui.nodes", "ComfyUI nodes")
	_add_status_indicator(status_grid, "comfyui.models", "ComfyUI models")
	_add_status_indicator(status_grid, "blender.executable", "Blender found")
	_add_status_indicator(status_grid, "ollama.executable", "Ollama found")
	_add_status_indicator(status_grid, "ollama.running", "Ollama running")
	_add_status_indicator(status_grid, "animation.asset", "Animation asset")
	_add_status_indicator(status_grid, "example.scene", "Base character scene")
	var dependency_actions := HBoxContainer.new()
	dependency_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dependency_check_button = Button.new()
	dependency_check_button.text = "Check dependencies"
	dependency_check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dependency_check_button.pressed.connect(_check_dependencies)
	dependency_actions.add_child(dependency_check_button)
	deep_check_button = Button.new()
	deep_check_button.text = "Deep-check Blender"
	deep_check_button.tooltip_text = "Starts Blender in background mode and verifies the builder operators"
	deep_check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deep_check_button.pressed.connect(_deep_check_dependencies)
	dependency_actions.add_child(deep_check_button)
	var report_menu := MenuButton.new()
	report_menu.text = "⋮"
	report_menu.tooltip_text = "Report actions"
	report_menu.custom_minimum_size.x = 32
	report_menu.get_popup().add_item("Copy report", 0)
	report_menu.get_popup().add_item("Save JSON report", 1)
	report_menu.get_popup().id_pressed.connect(_environment_report_menu_action)
	dependency_actions.add_child(report_menu)
	setup_tab.add_child(dependency_actions)
	technical_details = CheckButton.new()
	technical_details.text = "Show technical details"
	technical_details.toggled.connect(_toggle_technical_details)
	setup_tab.add_child(technical_details)
	dependency_status = RichTextLabel.new()
	dependency_status.fit_content = true
	dependency_status.custom_minimum_size.y = 55
	setup_tab.add_child(dependency_status)
	dependency_spinner = Timer.new()
	dependency_spinner.wait_time = 0.1
	dependency_spinner.timeout.connect(_advance_dependency_spinner)
	add_child(dependency_spinner)

	primary_rigged_mesh = _add_line_edit(setup_tab, "Primary rigged mesh", CharacterStore.DEFAULT_PRIMARY_RIGGED_MESH)
	secondary_rigged_mesh = _add_line_edit(setup_tab, "Secondary rigged mesh", CharacterStore.DEFAULT_SECONDARY_RIGGED_MESH)
	example_scene_path = _add_line_edit(setup_tab, "Base character scene", DEFAULT_EXAMPLE_SCENE)
	example_scene_path.text = DEFAULT_EXAMPLE_SCENE
	var scene_buttons := HBoxContainer.new()
	open_example_scene_button = Button.new()
	open_example_scene_button.text = "Load base character scene"
	open_example_scene_button.tooltip_text = "Load the scene containing the base mannequin characters to be skinned"
	open_example_scene_button.pressed.connect(_open_example_scene)
	scene_buttons.add_child(open_example_scene_button)
	setup_tab.add_child(scene_buttons)
	comfyui_url = _add_line_edit(setup_tab, "ComfyUI URL", "http://127.0.0.1:8188")
	comfyui_root = _add_line_edit(setup_tab, "ComfyUI directory", "/path/to/ComfyUI")
	blender_path = _add_line_edit(setup_tab, "Blender executable", "blender")
	reconstruction_command = _add_line_edit(setup_tab, "Reconstruction command", "/path/to/provider")
	animation_asset = _add_line_edit(setup_tab, "Animation library", "res://path/to/animations.glb")
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
	setup_tab.add_child(settings_buttons)
	configuration_status = Label.new()
	configuration_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_tab.add_child(configuration_status)

	var generate_tab := _add_tab(tabs, "3 Generate")
	workflow_import_path = _add_line_edit(generate_tab, "Comfy workflow JSON", "res://addons/build_me_godot/workflows/character_turnaround_open.json")
	var import_workflow_button := Button.new()
	import_workflow_button.text = "Import workflow prompts"
	import_workflow_button.tooltip_text = "Copy prompt fields from a ComfyUI workflow JSON into this Godot draft"
	import_workflow_button.pressed.connect(_import_workflow_prompts)
	generate_tab.add_child(import_workflow_button)
	var canonical_button := Button.new()
	canonical_button.text = "Queue canonical character"
	canonical_button.tooltip_text = "Explicitly queue the selected character in local ComfyUI"
	canonical_button.pressed.connect(_queue_canonical)
	generate_tab.add_child(canonical_button)

	var review_tab := _add_tab(tabs, "4 Review")
	run_select = OptionButton.new()
	run_select.tooltip_text = "Generated reference versions for the selected character"
	run_select.item_selected.connect(_on_run_selected)
	review_tab.add_child(run_select)
	reference_preview = TextureRect.new()
	reference_preview.custom_minimum_size = Vector2(320, 180)
	reference_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	reference_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	review_tab.add_child(reference_preview)
	run_details = RichTextLabel.new()
	run_details.fit_content = true
	run_details.custom_minimum_size.y = 120
	review_tab.add_child(run_details)
	var review_buttons := HBoxContainer.new()
	var approve_button := Button.new()
	approve_button.text = "Approve version"
	approve_button.pressed.connect(_approve_selected_run)
	review_buttons.add_child(approve_button)
	var rerun_button := Button.new()
	rerun_button.text = "Rerun version"
	rerun_button.pressed.connect(_rerun_selected_run)
	review_buttons.add_child(rerun_button)
	var continue_button := Button.new()
	continue_button.text = "Continue pipeline"
	continue_button.pressed.connect(_continue_selected_run)
	review_buttons.add_child(continue_button)
	var open_comfy_button := Button.new()
	open_comfy_button.text = "Open in ComfyUI"
	open_comfy_button.pressed.connect(_open_selected_run_in_comfyui)
	review_buttons.add_child(open_comfy_button)
	review_tab.add_child(review_buttons)

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


func _add_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.name = title
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(container)
	return container


func _add_line_edit(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var control := LineEdit.new()
	control.placeholder_text = placeholder
	_add_labeled_control(parent, label_text, control)
	return control


func _add_text_edit(parent: Control, label_text: String, minimum_height: float) -> TextEdit:
	var control := TextEdit.new()
	control.custom_minimum_size.y = minimum_height
	control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_add_labeled_control(parent, label_text, control)
	return control


func _add_labeled_control(parent: Control, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	parent.add_child(control)


func _add_status_indicator(parent: Control, id: String, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dot := StatusIndicatorDot.new()
	row.add_child(dot)
	var value := Label.new()
	value.text = "Unchecked"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	parent.add_child(row)
	status_indicators[id] = {"dot": dot, "value": value}
	_set_status_indicator(id, "unknown", "Unchecked")


func _set_status_indicator(id: String, state: String, text: String) -> void:
	if not status_indicators.has(id):
		return
	var indicator: Dictionary = status_indicators[id]
	var dot: StatusIndicatorDot = indicator.dot
	var value: Label = indicator.value
	match state:
		"pass":
			dot.set_indicator_color(INDICATOR_PASS)
		"fail":
			dot.set_indicator_color(INDICATOR_FAIL)
		"warning":
			dot.set_indicator_color(INDICATOR_WARNING)
		_:
			dot.set_indicator_color(INDICATOR_UNKNOWN)
	value.text = text


func _refresh_static_status_indicators() -> void:
	var comfy_root_text := comfyui_root.text.strip_edges() if comfyui_root else ""
	var comfy_root_found := not comfy_root_text.is_empty() and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(comfy_root_text))
	_set_status_indicator("comfyui.root", "pass" if comfy_root_found else "fail", "Yes" if comfy_root_found else "No")

	var animation_text := animation_asset.text.strip_edges() if animation_asset else ""
	if animation_text.is_empty():
		_set_status_indicator("animation.asset", "unknown", "Not set")
	else:
		var animation_found := FileAccess.file_exists(animation_text)
		_set_status_indicator("animation.asset", "pass" if animation_found else "fail", "Yes" if animation_found else "No")

	var scene_text := example_scene_path.text.strip_edges() if example_scene_path else ""
	if scene_text.is_empty():
		_set_status_indicator("example.scene", "unknown", "Not set")
	else:
		var scene_found := FileAccess.file_exists(scene_text)
		_set_status_indicator("example.scene", "pass" if scene_found else "warning", "Yes" if scene_found else "Optional missing")
		if open_example_scene_button:
			var edited_root := _edited_scene_root()
			var current_path := edited_root.scene_file_path if edited_root else ""
			open_example_scene_button.text = "Base character scene loaded" if current_path == scene_text else "Load base character scene"


func _update_status_indicators_from_report(report: Dictionary, ollama: Dictionary) -> void:
	_refresh_static_status_indicators()
	_set_status_indicator("blender.executable", _state_from_report(report, "blender.executable"), _yes_no_from_report(report, "blender.executable"))
	_set_status_indicator("comfyui.reachable", _state_from_report(report, "comfyui.reachable"), _yes_no_from_report(report, "comfyui.reachable"))
	_set_status_indicator("comfyui.nodes", _aggregate_state(report, "comfyui.nodes."), _aggregate_label(report, "comfyui.nodes."))
	_set_status_indicator("comfyui.models", _aggregate_state(report, "comfyui.models."), _aggregate_label(report, "comfyui.models."))
	_set_status_indicator("ollama.executable", "pass" if bool(ollama.get("found", false)) else "fail", "Yes" if bool(ollama.get("found", false)) else "No")
	_set_status_indicator("ollama.running", "pass" if bool(ollama.get("running", false)) else "fail", "Yes" if bool(ollama.get("running", false)) else "No")


func _state_from_report(report: Dictionary, id: String) -> String:
	for check in report.get("checks", []):
		if str(check.get("id", "")) == id:
			return _indicator_state_for_check(str(check.get("status", "")))
	return "unknown"


func _yes_no_from_report(report: Dictionary, id: String) -> String:
	for check in report.get("checks", []):
		if str(check.get("id", "")) == id:
			return "Yes" if str(check.get("status", "")) == "pass" else "No"
	return "Unchecked"


func _aggregate_state(report: Dictionary, id_prefix: String) -> String:
	var saw_match := false
	var saw_warning := false
	for check in report.get("checks", []):
		if not str(check.get("id", "")).begins_with(id_prefix):
			continue
		saw_match = true
		var state := _indicator_state_for_check(str(check.get("status", "")))
		if state == "fail":
			return "fail"
		if state != "pass":
			saw_warning = true
	if not saw_match:
		return "unknown"
	return "warning" if saw_warning else "pass"


func _aggregate_label(report: Dictionary, id_prefix: String) -> String:
	var saw_match := false
	for check in report.get("checks", []):
		if not str(check.get("id", "")).begins_with(id_prefix):
			continue
		saw_match = true
		if str(check.get("status", "")) != "pass":
			return "No"
	return "Yes" if saw_match else "Unchecked"


func _indicator_state_for_check(status_text: String) -> String:
	match status_text:
		"pass":
			return "pass"
		"fail":
			return "fail"
		"warning", "unknown":
			return "warning"
		_:
			return "unknown"


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
	_refresh_review(manifest)
	_set_status("Loaded %s" % result.path)


func _new_character() -> void:
	character_select.select(0)
	character_id.clear()
	display_name.clear()
	role.clear()
	style_notes.clear()
	prompt.text = DEFAULT_PROMPT
	negative_prompt.text = DEFAULT_NEGATIVE_PROMPT
	primary_rigged_mesh.text = CharacterStore.DEFAULT_PRIMARY_RIGGED_MESH
	secondary_rigged_mesh.text = CharacterStore.DEFAULT_SECONDARY_RIGGED_MESH
	seed.value = 0
	_refresh_review({})
	_set_status("Edit the default prompt for this character, then save.")


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
	_refresh_review(result.manifest)
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


func _refresh_review(manifest: Dictionary) -> void:
	run_select.clear()
	reference_preview.texture = null
	run_details.clear()
	if manifest.is_empty():
		run_select.add_item("No character selected")
		return
	var generation: Dictionary = manifest.get("generation", {})
	var selected_version := str(generation.get("selected_version", ""))
	var runs: Array = generation.get("runs", [])
	if runs.is_empty():
		run_select.add_item("No reference runs yet")
		run_details.text = "Queue a reference workflow to create v1."
		return
	for run in runs:
		if not (run is Dictionary):
			continue
		var version := str(run.get("version", ""))
		var label := "%s - %s" % [version, str(run.get("status", "draft"))]
		if version == selected_version:
			label += " (approved)"
		run_select.add_item(label)
		run_select.set_item_metadata(run_select.item_count - 1, version)
		if version == selected_version:
			run_select.select(run_select.item_count - 1)
	_render_selected_run(manifest)


func _on_run_selected(_index: int) -> void:
	var loaded := store.load_character(character_id.text)
	if loaded.ok:
		_render_selected_run(loaded.manifest)


func _render_selected_run(manifest: Dictionary) -> void:
	var run := _selected_run(manifest)
	reference_preview.texture = null
	run_details.clear()
	if run.is_empty():
		return
	var outputs: Dictionary = run.get("outputs", {})
	_load_reference_preview(outputs)
	var lines := PackedStringArray([
		"Version: %s" % str(run.get("version", "")),
		"Status: %s" % str(run.get("status", "")),
		"Prompt: %s" % str(run.get("positive_prompt", "")),
		"Negative: %s" % str(run.get("negative_prompt", "")),
		"Seed: %d" % int(run.get("seed", 0)),
		"Prompt ID: %s" % str(run.get("prompt_id", ""))
	])
	for key in outputs:
		lines.append("%s: %s" % [str(key), str(outputs[key])])
	run_details.text = "\n".join(lines)


func _selected_run(manifest: Dictionary) -> Dictionary:
	if run_select.item_count == 0:
		return {}
	var selected_index := run_select.selected
	if selected_index < 0:
		return {}
	var selected_version := str(run_select.get_item_metadata(selected_index))
	var generation: Dictionary = manifest.get("generation", {})
	for run in generation.get("runs", []):
		if run is Dictionary and str(run.get("version", "")) == selected_version:
			return run
	return {}


func _selected_run_version() -> String:
	if run_select.item_count == 0 or run_select.selected < 0:
		return ""
	return str(run_select.get_item_metadata(run_select.selected))


func _load_reference_preview(outputs: Dictionary) -> void:
	for key in ["turnaround_sheet", "contact_sheet", "front", "canonical"]:
		if not outputs.has(key):
			continue
		var path := str(outputs[key])
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		if image.load(path) != OK:
			continue
		reference_preview.texture = ImageTexture.create_from_image(image)
		return


func _approve_selected_run() -> void:
	var version := _selected_run_version()
	if version.is_empty():
		_set_status("Select a generated version before approving.", true)
		return
	var approved := store.approve_generation_version(character_id.text, version)
	if not approved.ok:
		_set_status(approved.error, true)
		return
	_refresh_review(approved.manifest)
	_set_status("Approved %s." % version)


func _rerun_selected_run() -> void:
	var loaded := store.load_character(character_id.text)
	if not loaded.ok:
		_set_status(loaded.error, true)
		return
	var run := _selected_run(loaded.manifest)
	if run.is_empty():
		_set_status("Select a generated version before rerunning.", true)
		return
	prompt.text = str(run.get("positive_prompt", ""))
	negative_prompt.text = str(run.get("negative_prompt", ""))
	seed.value = int(run.get("seed", 0))
	_queue_canonical()


func _continue_selected_run() -> void:
	var version := _selected_run_version()
	if version.is_empty():
		_set_status("Select an approved version before continuing.", true)
		return
	var continued := store.continue_pipeline(character_id.text, {
		"version": version,
		"warnings_acknowledged": true
	})
	if not continued.ok:
		_set_status(continued.error, true)
		return
	_refresh_review(continued.manifest)
	_set_status("Pipeline enabled for %s." % version)


func _open_selected_run_in_comfyui() -> void:
	var loaded := store.load_character(character_id.text)
	if not loaded.ok:
		_set_status(loaded.error, true)
		return
	var run := _selected_run(loaded.manifest)
	var prompt_id := str(run.get("prompt_id", ""))
	var url := comfyui_url.text.strip_edges()
	if url.is_empty():
		_set_status("ComfyUI URL is required.", true)
		return
	if not prompt_id.is_empty():
		url = url.trim_suffix("/") + "/history/" + prompt_id.uri_encode()
	OS.shell_open(url)


func _open_example_scene() -> void:
	var path := example_scene_path.text.strip_edges()
	if path.is_empty():
		path = DEFAULT_EXAMPLE_SCENE
	if not FileAccess.file_exists(path):
		_refresh_static_status_indicators()
		_set_status("Optional base character scene is not present in this project: %s" % path, true)
		return
	var edited_root := _edited_scene_root()
	if edited_root and edited_root.scene_file_path == path:
		if EditorInterface.has_method("set_main_screen_editor"):
			EditorInterface.call("set_main_screen_editor", "3D")
		_refresh_static_status_indicators()
		_set_status("Base character scene is already loaded: %s" % path)
		return
	if not EditorInterface.has_method("open_scene_from_path"):
		_set_status("Editor scene loading is not available in this context.", true)
		return
	EditorInterface.call("open_scene_from_path", path)
	if EditorInterface.has_method("set_main_screen_editor"):
		EditorInterface.call("set_main_screen_editor", "3D")
	_refresh_static_status_indicators()
	_set_status("Loaded base character scene: %s" % path)


func _load_configuration() -> void:
	var settings := _editor_settings()
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
	_refresh_static_status_indicators()


func _save_configuration(local: bool) -> void:
	var settings := _editor_settings()
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
		if settings == null:
			_set_status("Editor settings are not available in this context.", true)
			return
		for key in values:
			settings.set_setting(Config.EDITOR_PREFIX + key, values[key])
	_load_configuration()
	_set_status("Saved %s configuration." % ("project-local" if local else "global editor"))


func _editor_settings() -> Object:
	if Engine.is_editor_hint() and EditorInterface.has_method("get_editor_settings"):
		return EditorInterface.call("get_editor_settings")
	return null


func _edited_scene_root() -> Node:
	if Engine.is_editor_hint() and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.call("get_edited_scene_root")
	return null


func _check_dependencies() -> void:
	await _run_environment_check(false)


func _deep_check_dependencies() -> void:
	await _run_environment_check(true)


func _run_environment_check(deep_check: bool) -> void:
	if dependency_check_in_progress:
		return
	_begin_dependency_check(deep_check)
	var report: Dictionary = await environment_checker.check("all", {
		"comfyui_url": comfyui_url.text,
		"comfyui_root": comfyui_root.text,
		"blender_executable": blender_path.text,
		"reconstruction_command": reconstruction_command.text,
		"animation_asset": animation_asset.text,
		"deep_check": deep_check
	})
	var ollama := await _probe_ollama()
	last_environment_report = report
	_render_environment_report()
	_update_status_indicators_from_report(report, ollama)
	_end_dependency_check()


func _begin_dependency_check(deep_check: bool) -> void:
	dependency_check_in_progress = true
	dependency_spinner_frame = 0
	dependency_check_button.disabled = true
	deep_check_button.disabled = true
	dependency_check_button.text = "Checking dependencies…"
	deep_check_button.text = "Deep-checking Blender…" if deep_check else "Deep-check Blender"
	dependency_spinner.start()
	_advance_dependency_spinner()


func _advance_dependency_spinner() -> void:
	if not dependency_check_in_progress:
		return
	var frame: String = SPINNER_FRAMES[dependency_spinner_frame % SPINNER_FRAMES.size()]
	dependency_spinner_frame += 1
	dependency_status.text = "%s Checking local environment…" % frame
	for id in status_indicators:
		_set_status_indicator(id, "unknown", "%s Checking" % frame)


func _end_dependency_check() -> void:
	dependency_check_in_progress = false
	dependency_spinner.stop()
	dependency_check_button.disabled = false
	deep_check_button.disabled = false
	dependency_check_button.text = "Check dependencies"
	deep_check_button.text = "Deep-check Blender"


func _probe_ollama() -> Dictionary:
	var output := []
	var found := OS.execute("ollama", ["--version"], output, true) == 0
	var request := HTTPRequest.new()
	request.timeout = 2.0
	add_child(request)
	var start_error := request.request("http://127.0.0.1:11434/api/tags")
	if start_error != OK:
		request.queue_free()
		return {"found": found, "running": false}
	var response: Array = await request.request_completed
	request.queue_free()
	return {"found": found, "running": response[0] == HTTPRequest.RESULT_SUCCESS and response[1] >= 200 and response[1] < 300}


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


func _environment_report_menu_action(id: int) -> void:
	match id:
		0:
			_copy_environment_report()
		1:
			_save_environment_report()


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


func _import_workflow_prompts() -> void:
	var path := workflow_import_path.text.strip_edges()
	if path.is_empty():
		_set_status("Workflow JSON path is required.", true)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Could not open workflow JSON: %s" % path, true)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_set_status("Workflow JSON did not parse as an object: %s" % path, true)
		return
	var fields := TurnaroundWorkflow.extract_prompt_fields(parsed)
	if fields.is_empty():
		_set_status("No importable prompt fields were found in %s." % path, true)
		return
	if fields.has("character_id") and not str(fields.character_id).strip_edges().is_empty():
		character_id.text = str(fields.character_id)
	if fields.has("prompt"):
		prompt.text = str(fields.prompt)
	if fields.has("negative_prompt"):
		negative_prompt.text = str(fields.negative_prompt)
	if fields.has("seed"):
		seed.value = int(fields.seed)
	_set_status("Imported prompt fields from %s. Save the draft to make Godot the source of truth." % path)


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
		"seed": int(saved.manifest.get("seed", 0)),
		"workflow_snapshot": workflow,
		"workflow_source_path": workflow_path,
		"workflow_format": "api"
	})
	if not run.ok:
		_set_status(run.error, true)
		return
	var runs: Array = run.manifest.generation.runs
	var run_record: Dictionary = runs[runs.size() - 1]
	pending_generation_character_id = str(run.manifest.character_id)
	pending_generation_version = str(run_record.version)
	_refresh_review(run.manifest)
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
		var queued := store.update_generation_run(pending_generation_character_id, pending_generation_version, {
			"status": "queued",
			"prompt_id": prompt_id,
			"queued_at": Time.get_datetime_string_from_system(true)
		})
		if queued.ok:
			_refresh_review(queued.manifest)
	comfy_client.request_history(prompt_id)
	_set_status("ComfyUI queued %s prompt %s" % [pending_generation_version, prompt_id])


func _on_history_received(prompt_id: String, history: Dictionary) -> void:
	if pending_generation_character_id.is_empty() or pending_generation_version.is_empty():
		return
	var prompt_history: Dictionary = history.get(prompt_id, {})
	if prompt_history.has("outputs"):
		var configured_comfyui_root := comfyui_root.text.strip_edges()
		var comfy_output_root := configured_comfyui_root.path_join("output") if not configured_comfyui_root.is_empty() else ""
		var completed := store.complete_generation_run(
			pending_generation_character_id,
			pending_generation_version,
			prompt_history,
			comfy_output_root,
			"res://addons/build_me_godot/workflows/canonical_only_api.requirements.json"
		)
		if completed.ok:
			_refresh_review(completed.manifest)
			_set_status("ComfyUI completed %s and copied outputs into the project." % pending_generation_version)
		else:
			var failed := store.update_generation_run(pending_generation_character_id, pending_generation_version, {
				"status": "failed",
				"history": prompt_history,
				"error": completed.error,
				"completed_at": Time.get_datetime_string_from_system(true)
			})
			if failed.ok:
				_refresh_review(failed.manifest)
			_set_status(completed.error, true)
		return
	var updated := store.update_generation_run(pending_generation_character_id, pending_generation_version, {
		"status": "queued",
		"history": prompt_history
	})
	if updated.ok:
		_refresh_review(updated.manifest)


func _on_comfy_error(message: String) -> void:
	if not pending_generation_character_id.is_empty() and not pending_generation_version.is_empty():
		var failed := store.update_generation_run(pending_generation_character_id, pending_generation_version, {
			"status": "failed",
			"error": message,
			"completed_at": Time.get_datetime_string_from_system(true)
		})
		if failed.ok:
			_refresh_review(failed.manifest)
	_set_status(message, true)


func _set_status(message: String, is_error := false) -> void:
	status.text = message
	status.modulate = Color("ff8080") if is_error else Color.WHITE
