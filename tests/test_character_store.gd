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
	var draft := store.save_draft({
		"character_id": "Draft Character",
		"display_name": "Draft Character",
		"metadata": {
			"role": "test role",
			"style": "test style",
			"pose_contract": "neutral_a_pose_30deg_v1"
		},
		"prompt": "positive draft prompt",
		"negative_prompt": "negative draft prompt",
		"animation_asset": "res://animations/shared_library.glb",
		"rigged_meshes": {
			"primary": "res://characters/base_primary.glb",
			"secondary": "res://characters/base_secondary.glb"
		}
	})
	if not _check(draft.ok, draft.get("error", "draft save failed")): return
	if not _check(draft.manifest.stage == "draft", "draft stage was not set"): return
	if not _check(draft.manifest.project_context.workspace_root == test_root, "project context did not record workspace root"): return
	if not _check(draft.manifest.project_context.animation_library == "res://animations/shared_library.glb", "project animation library was not recorded"): return
	if not _check(draft.manifest.metadata.role == "test role", "metadata role did not round-trip"): return
	if not _check(draft.manifest.metadata.style == "test style", "metadata style did not round-trip"): return
	if not _check(draft.manifest.rigged_meshes.primary == "res://characters/base_primary.glb", "primary rigged mesh did not round-trip"): return
	if not _check(draft.manifest.rigged_meshes.secondary == "res://characters/base_secondary.glb", "secondary rigged mesh did not round-trip"): return
	if not _check(draft.manifest.generation.runs.is_empty(), "draft should not create generation runs"): return
	var validation_errors := store.validate_draft({
		"character_id": "Invalid/Name",
		"rigged_meshes": {"primary": "", "secondary": ""},
		"prompt": ""
	}, true)
	if not _check(validation_errors.size() == 4, "draft validation did not report every missing field"): return
	var run_v1 := store.create_generation_run("draft_character", {"positive_prompt": "v1 prompt", "negative_prompt": "v1 negative", "seed": 7})
	if not _check(run_v1.ok, run_v1.get("error", "v1 run failed")): return
	if not _check(run_v1.manifest.generation.runs[0].version == "v1", "first generation run was not v1"): return
	if not _check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root.path_join("characters/draft_character/references/v1"))), "v1 reference folder was not created"): return
	var run_v2 := store.create_generation_run("draft_character", {"positive_prompt": "v2 prompt", "seed": 8})
	if not _check(run_v2.ok, run_v2.get("error", "v2 run failed")): return
	if not _check(run_v2.manifest.generation.runs[1].version == "v2", "second generation run was not v2"): return
	if not _check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root.path_join("characters/draft_character/references/v2"))), "v2 reference folder was not created"): return
	if not _check(run_v2.manifest.generation.runs[0].positive_prompt == "v1 prompt", "v1 prompt was overwritten"): return
	var queued_v2 := store.update_generation_run("draft_character", "v2", {
		"status": "queued",
		"prompt_id": "prompt-test-2",
		"queued_at": "2026-08-12T00:00:00"
	})
	if not _check(queued_v2.ok, queued_v2.get("error", "run queue update failed")): return
	if not _check(queued_v2.manifest.generation.runs[1].prompt_id == "prompt-test-2", "prompt id was not recorded on run"): return
	if not _check(queued_v2.manifest.generation.runs[1].status == "queued", "run status was not updated to queued"): return
	if not _check(queued_v2.manifest.generation.runs[0].get("prompt_id", "") == "", "run update changed another version"): return
	var completed_v2 := store.update_generation_run("draft_character", "v2", {
		"status": "completed",
		"completed_at": "2026-08-12T00:01:00",
		"outputs": {"contact_sheet": "res://build_me_godot/characters/draft_character/references/v2/contact_sheet.png"}
	})
	if not _check(completed_v2.ok, completed_v2.get("error", "run completion update failed")): return
	if not _check(completed_v2.manifest.generation.runs[1].outputs.contact_sheet.ends_with("contact_sheet.png"), "run outputs were not recorded"): return
	var missing_run_update := store.update_generation_run("draft_character", "v99", {"status": "failed"})
	if not _check(not missing_run_update.ok, "missing run update should fail"): return
	var approved := store.approve_generation_version("draft_character", "v2")
	if not _check(approved.ok, approved.get("error", "approval failed")): return
	if not _check(approved.manifest.generation.selected_version == "v2", "selected version was not recorded"): return
	if not _check(approved.manifest.stage == "reference_approved", "approval stage was not recorded"): return
	var resaved_draft := store.save_draft({"character_id": "draft_character", "prompt": "updated after approval"})
	if not _check(resaved_draft.ok, resaved_draft.get("error", "resave draft failed")): return
	if not _check(resaved_draft.manifest.generation.runs.size() == 2, "draft resave wiped generation runs"): return
	if not _check(resaved_draft.manifest.generation.selected_version == "v2", "draft resave wiped selected version"): return
	if not _check(resaved_draft.manifest.stage == "reference_approved", "draft resave regressed stage"): return
	var missing_version := store.approve_generation_version("draft_character", "v99")
	if not _check(not missing_version.ok, "missing version approval should fail"): return
	var final_assets := store.register_final_assets("draft_character", {
		"character_scene": "res://build_me_godot/characters/draft_character/draft_character.tscn",
		"animations": ["res://build_me_godot/characters/draft_character/animations/idle.res"],
		"secondary_assets": [{"asset_id": "helmet", "scene": "res://build_me_godot/characters/draft_character/assets/helmet.tscn", "socket": "head"}]
	})
	if not _check(final_assets.ok, final_assets.get("error", "final asset registration failed")): return
	if not _check(final_assets.manifest.stage == "complete", "final asset stage was not recorded"): return
	if not _check(final_assets.manifest.assets.character_scene.ends_with("draft_character.tscn"), "character scene path was not recorded"): return
	if not _check(final_assets.manifest.assets.animations.size() == 1, "animation paths were not recorded"): return
	if not _check(final_assets.manifest.assets.secondary_assets[0].asset_id == "helmet", "secondary assets were not recorded"): return

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
