extends SceneTree

const CharacterStore = preload("res://addons/build_me_godot/core/character_store.gd")
const ComfyUIClient = preload("res://addons/build_me_godot/services/comfyui_client.gd")
const TurnaroundWorkflow = preload("res://addons/build_me_godot/services/turnaround_workflow.gd")
const WorkflowRequirements = preload("res://addons/build_me_godot/services/workflow_requirements.gd")
const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const BlenderRequirements = preload("res://addons/build_me_godot/services/blender_requirements.gd")


func _init() -> void:
	var test_root := "user://tests/%s" % Time.get_ticks_usec()
	var store := CharacterStore.new(test_root)
	var saved := store.save_character({
		"character_id": "Test Character",
		"display_name": "Test Character",
		"prompt": "A test humanoid",
		"seed": 42,
		"future_field": {"preserve": true}
	})
	if not _check(saved.ok, saved.get("error", "save failed")): return
	if not _check(saved.manifest.character_id == "test_character", "character ID was not normalized"): return

	var loaded := store.load_character("test_character")
	if not _check(loaded.ok, loaded.get("error", "load failed")): return
	if not _check(loaded.manifest.prompt == "A test humanoid", "prompt did not round-trip"): return
	if not _check(int(loaded.manifest.seed) == 42, "seed did not round-trip"): return
	var updated := store.save_character({"character_id": "test_character", "prompt": "Updated prompt"})
	if not _check(updated.ok, updated.get("error", "update failed")): return
	loaded = store.load_character("test_character")
	if not _check(loaded.manifest.future_field.preserve, "unknown manifest fields were not preserved"): return
	if not _check(loaded.manifest.display_name == "Test Character", "existing manifest fields were not preserved"): return
	if not _check(store.list_characters() == PackedStringArray(["test_character"]), "character listing failed"): return

	var client := ComfyUIClient.new()
	get_root().add_child(client)
	var workflow := client.load_api_workflow(TurnaroundWorkflow.CANONICAL_WORKFLOW)
	if not _check(workflow.has("1") and workflow.has("32"), "canonical workflow wrapper was not normalized"): return
	var configured := TurnaroundWorkflow.configure_canonical(workflow, loaded.manifest)
	if not _check(configured["1"].inputs.value == "Updated prompt", "workflow prompt binding failed"): return
	if not _check(configured["3"].inputs.value == 42, "workflow seed binding failed"): return
	if not _check(configured["10"].inputs.value == "test_character", "workflow character binding failed"): return
	var canonical_errors := WorkflowRequirements.validate_workflow(
		TurnaroundWorkflow.CANONICAL_WORKFLOW,
		"res://addons/build_me_godot/workflows/canonical_only_api.requirements.json"
	)
	if not _check(canonical_errors.is_empty(), "canonical requirements: %s" % ", ".join(canonical_errors)): return
	var multiview_errors := WorkflowRequirements.validate_workflow(
		TurnaroundWorkflow.MULTIVIEW_WORKFLOW,
		"res://addons/build_me_godot/workflows/multiview_only_api.requirements.json"
	)
	if not _check(multiview_errors.is_empty(), "multiview requirements: %s" % ", ".join(multiview_errors)): return

	var environment_checks: Array[Dictionary] = [
		EnvironmentReport.result("z.optional", "test", "warning", "optional", "Optional warning", null, null, {}, PackedStringArray(["optional.action"])),
		EnvironmentReport.result("a.required", "test", "pass", "required", "Required pass", true, true, {}, PackedStringArray(["unneeded.action"]))
	]
	var environment_report := EnvironmentReport.build("test", environment_checks, "test")
	if not _check(environment_report.overall_status == "ready", "optional warning blocked readiness"): return
	if not _check(environment_report.checks[0].id == "a.required", "environment checks were not stably sorted"): return
	if not _check(environment_report.remediations.size() == 1 and environment_report.remediations[0].id == "optional.action", "report remediation aggregation failed"): return
	var rendered_report := EnvironmentReport.render_text(environment_report)
	for check in environment_report.checks:
		if not _check(rendered_report.contains(check.id) and rendered_report.contains(str(check.status).to_upper()), "text renderer omitted report data: %s" % check.id): return
	var redacted := EnvironmentReport.redact({"path": OS.get_environment("HOME") + "/models/test.safetensors"})
	if not _check(redacted.path == "<home>/models/test.safetensors", "support report did not redact the home path"): return
	var builder := BlenderRequirements.load_metadata()
	if not _check(builder.ok, builder.get("error", "Blender requirements failed to load")): return
	var builder_config := {}
	for field in builder.metadata.configuration.required:
		builder_config[field] = null
	builder_config.pose_contract = builder.metadata.pose_contract
	if not _check(BlenderRequirements.validate_config(builder_config, builder.metadata).is_empty(), "Blender configuration contract did not validate"): return
	var fixture_file := FileAccess.open("res://tests/fixtures/environment_reports.json", FileAccess.READ)
	if not _check(fixture_file != null, "environment fixtures could not be opened"): return
	var fixtures = JSON.parse_string(fixture_file.get_as_text())
	if not _check(fixtures is Array, "environment fixtures are malformed"): return
	for fixture in fixtures:
		var fixture_checks: Array[Dictionary] = []
		for check in fixture.checks:
			fixture_checks.append(check)
		var fixture_report := EnvironmentReport.build("all", fixture_checks, "test")
		if not _check(fixture_report.overall_status == fixture.expected, "environment fixture failed: %s" % fixture.name): return
		if not _check(EnvironmentReport.exit_code(fixture_report) == (0 if fixture.expected == "ready" else 1), "fixture exit code failed: %s" % fixture.name): return
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
