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
	var source_mesh_dir := test_root.path_join("source_meshes")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(source_mesh_dir))
	var primary_source_mesh := source_mesh_dir.path_join("base_primary.glb")
	var secondary_source_mesh := source_mesh_dir.path_join("base_secondary.glb")
	_write_text(primary_source_mesh, "primary mesh bytes")
	_write_text(secondary_source_mesh, "secondary mesh bytes")
	var source_rig_contract := {
		"profile": "SkeletonProfileHumanoid",
		"stable_bone_names": ["Hips", "Spine", "Chest", "Neck", "Head", "LeftHand", "RightHand"],
		"socket_names": ["head", "hand_l", "hand_r", "chest", "hips"]
	}
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
			"primary": primary_source_mesh,
			"secondary": secondary_source_mesh
		},
		"source_rig_contract": source_rig_contract
	})
	if not _check(draft.ok, draft.get("error", "draft save failed")): return
	if not _check(draft.manifest.stage == "draft", "draft stage was not set"): return
	if not _check(draft.manifest.project_context.workspace_root == test_root, "project context did not record workspace root"): return
	if not _check(draft.manifest.project_context.animation_library == "res://animations/shared_library.glb", "project animation library was not recorded"): return
	if not _check(draft.manifest.metadata.role == "test role", "metadata role did not round-trip"): return
	if not _check(draft.manifest.metadata.style == "test style", "metadata style did not round-trip"): return
	if not _check(draft.manifest.rigged_meshes.primary == primary_source_mesh, "primary rigged mesh did not round-trip"): return
	if not _check(draft.manifest.rigged_meshes.secondary == secondary_source_mesh, "secondary rigged mesh did not round-trip"): return
	if not _check(draft.manifest.source_rig_contract == source_rig_contract, "source rig contract did not round-trip"): return
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
	var run_v2 := store.create_generation_run("draft_character", {
		"positive_prompt": "v2 prompt",
		"seed": 8,
		"workflow_snapshot": {"1": {"class_type": "PrimitiveStringMultiline", "inputs": {"value": "v2 prompt"}}},
		"workflow_source_path": "res://addons/build_me_godot/workflows/canonical_only_api.json"
	})
	if not _check(run_v2.ok, run_v2.get("error", "v2 run failed")): return
	if not _check(run_v2.manifest.generation.runs[1].version == "v2", "second generation run was not v2"): return
	if not _check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root.path_join("characters/draft_character/references/v2"))), "v2 reference folder was not created"): return
	if not _check(run_v2.manifest.generation.runs[0].positive_prompt == "v1 prompt", "v1 prompt was overwritten"): return
	if not _check(run_v2.manifest.generation.runs[1].workflow_snapshot.path.ends_with("workflows/v2_api.json"), "workflow snapshot path was not recorded"): return
	if not _check(not str(run_v2.manifest.generation.runs[1].workflow_snapshot.sha256).is_empty(), "workflow snapshot hash was not recorded"): return
	if not _check(run_v2.manifest.generation.runs[1].workflow_snapshot.source_path.ends_with("canonical_only_api.json"), "workflow source path was not recorded"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/workflows/v2_api.json")), "workflow snapshot was not written"): return
	var queued_v2 := store.update_generation_run("draft_character", "v2", {
		"status": "queued",
		"prompt_id": "prompt-test-2",
		"queued_at": "2026-08-12T00:00:00"
	})
	if not _check(queued_v2.ok, queued_v2.get("error", "run queue update failed")): return
	if not _check(queued_v2.manifest.generation.runs[1].prompt_id == "prompt-test-2", "prompt id was not recorded on run"): return
	if not _check(queued_v2.manifest.generation.runs[1].status == "queued", "run status was not updated to queued"): return
	if not _check(queued_v2.manifest.generation.runs[0].get("prompt_id", "") == "", "run update changed another version"): return
	var fake_comfy_output_root := ProjectSettings.globalize_path(test_root.path_join("fake_comfy/output"))
	var fake_comfy_character_dir := fake_comfy_output_root.path_join("character_turnaround/draft_character")
	DirAccess.make_dir_recursive_absolute(fake_comfy_character_dir)
	var fake_front := FileAccess.open(fake_comfy_character_dir.path_join("front.png"), FileAccess.WRITE)
	fake_front.store_string("fake image bytes")
	fake_front.close()
	var completed_v2 := store.complete_generation_run(
		"draft_character",
		"v2",
		{
			"outputs": {
				"save_front": {
					"images": [{
						"filename": "front.png",
						"subfolder": "character_turnaround/draft_character",
						"type": "output"
					}]
				}
			}
		},
		fake_comfy_output_root,
		"res://addons/build_me_godot/workflows/canonical_only_api.requirements.json"
	)
	if not _check(completed_v2.ok, completed_v2.get("error", "run completion update failed")): return
	if not _check(completed_v2.manifest.generation.runs[1].status == "completed", "run status was not updated to completed"): return
	if not _check(completed_v2.manifest.generation.runs[1].outputs.front.ends_with("references/v2/front.png"), "copied run output path was not recorded"): return
	if not _check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_root.path_join("characters/draft_character/references/v2"))), "reference output folder was not present"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/references/v2/front.png")), "completed output was not copied into the project"): return
	if not _check(completed_v2.manifest.generation.runs[1].model_provenance.workflow_id == "qwen_character_canonical_2512", "workflow provenance was not recorded"): return
	if not _check(completed_v2.changed_paths.has(test_root.path_join("characters/draft_character/references/v2/front.png")), "changed output path was not reported"): return
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
	var unapproved_conformance := store.prepare_conformance("test_character", {"version": "v1"})
	if not _check(not unapproved_conformance.ok, "conformance should require an approved reference"): return
	var rigged_before: Dictionary = draft.manifest.rigged_meshes.duplicate(true)
	var source_rig_contract_before: Dictionary = draft.manifest.source_rig_contract.duplicate(true)
	var primary_mesh_before := _read_text(primary_source_mesh)
	var secondary_mesh_before := _read_text(secondary_source_mesh)
	var bad_pose := store.save_character({
		"character_id": "draft_character",
		"pose_contract": "custom_pose",
		"metadata": {"pose_contract": "custom_pose"}
	})
	if not _check(bad_pose.ok, bad_pose.get("error", "bad pose setup failed")): return
	var bad_pose_conformance := store.prepare_conformance("draft_character", {"version": "v2"})
	if not _check(not bad_pose_conformance.ok and str(bad_pose_conformance.error).contains("neutral_a_pose_30deg_v1"), "conformance should reject pose contract drift"): return
	var restored_pose := store.save_character({
		"character_id": "draft_character",
		"pose_contract": "neutral_a_pose_30deg_v1",
		"metadata": {"pose_contract": "neutral_a_pose_30deg_v1"}
	})
	if not _check(restored_pose.ok, restored_pose.get("error", "pose restore failed")): return
	var missing_proxy_license := store.prepare_conformance("draft_character", {
		"version": "v2",
		"proxy_meshes": {"front_proxy": "res://build_me_godot/characters/draft_character/conformance/v2/proxy_meshes/front_proxy.glb"},
		"proxy_provenance": {"source": "test"}
	})
	if not _check(not missing_proxy_license.ok and str(missing_proxy_license.error).contains("proxy-license-record"), "manual proxy should require a license record"): return
	var missing_proxy_provenance := store.prepare_conformance("draft_character", {
		"version": "v2",
		"proxy_meshes": {"front_proxy": "res://build_me_godot/characters/draft_character/conformance/v2/proxy_meshes/front_proxy.glb"},
		"proxy_license_record": "user_supplied"
	})
	if not _check(not missing_proxy_provenance.ok and str(missing_proxy_provenance.error).contains("proxy-provenance"), "manual proxy should require provenance"): return
	var invalid_proxy_extension := store.prepare_conformance("draft_character", {
		"version": "v2",
		"proxy_meshes": {"front_proxy": "res://build_me_godot/characters/draft_character/conformance/v2/proxy_meshes/front_proxy.txt"},
		"proxy_license_record": "user_supplied",
		"proxy_provenance": {"source": "test"}
	})
	if not _check(not invalid_proxy_extension.ok and str(invalid_proxy_extension.error).contains(".glb"), "manual proxy should reject unsupported extensions"): return
	var addon_proxy_path := store.prepare_conformance("draft_character", {
		"version": "v2",
		"proxy_meshes": {"front_proxy": "res://addons/build_me_godot/proxy.glb"},
		"proxy_license_record": "user_supplied",
		"proxy_provenance": {"source": "test"}
	})
	if not _check(not addon_proxy_path.ok and str(addon_proxy_path.error).contains("addon"), "manual proxy should reject addon paths"): return
	var rejected_provider := store.prepare_conformance("draft_character", {
		"version": "v2",
		"provider_id": "stable_fast_3d"
	})
	if not _check(not rejected_provider.ok and str(rejected_provider.error).contains("Rejected"), "rejected provider should not prepare conformance"): return
	var missing_proxy_command_plan := store.prepare_conformance("draft_character", {"version": "v2"})
	if not _check(missing_proxy_command_plan.ok, missing_proxy_command_plan.get("error", "conformance without provider command should prepare")): return
	if not _check(missing_proxy_command_plan.conformance_plan.providers[0].status == "manual_setup_required", "missing provider command should be recorded as manual setup required"): return
	var missing_proxy_command := store.generate_proxy("draft_character", {"version": "v2", "provider_id": "triposr"})
	if not _check(not missing_proxy_command.ok and str(missing_proxy_command.error).contains("No reconstruction command"), "proxy generation should require configured command"): return
	if not _check(missing_proxy_command.changed_paths[0].ends_with("triposr_front_proxy_generation.json"), "failed proxy attempt report path was not returned"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/conformance/v2/reports/triposr_front_proxy_generation.json")), "failed proxy attempt report was not written"): return
	var conformance := store.prepare_conformance("draft_character", {
		"version": "v2",
		"proxy_meshes": {
			"front_proxy": "res://build_me_godot/characters/draft_character/conformance/v2/proxy_meshes/front_proxy.glb"
		},
		"proxy_license_record": "user_supplied",
		"proxy_provenance": {"source": "unit-test"}
	})
	if not _check(conformance.ok, conformance.get("error", "conformance preparation failed")): return
	if not _check(conformance.manifest.stage == "conformance_prepared", "conformance stage was not recorded"): return
	if not _check(conformance.manifest.conformance.plan_path.ends_with("conformance/v2/conformance_plan.json"), "conformance plan path was not recorded"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/conformance/v2/conformance_plan.json")), "conformance plan was not written"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/conformance/v2/provider_inputs.json")), "provider inputs were not written"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/conformance/v2/reports/validation.json")), "validation report was not written"): return
	if not _check(conformance.conformance_plan.validation_constraints.source_meshes_immutable, "immutable mesh constraint was not recorded"): return
	if not _check(conformance.conformance_plan.field_engineer_targets.avoid.has("fused_tools"), "avoidance targets were not recorded"): return
	if not _check(conformance.conformance_plan.providers.size() >= 2, "manual proxy provider provenance was not recorded"): return
	var manual_proxy_recorded := false
	for provider in conformance.conformance_plan.providers:
		if provider is Dictionary and str(provider.get("provider_id", "")) == "external_proxy_mesh":
			manual_proxy_recorded = true
	if not _check(manual_proxy_recorded, "manual proxy provider provenance was not recorded"): return
	if not _check(conformance.changed_paths.has(test_root.path_join("characters/draft_character/conformance/v2/conformance_plan.json")), "conformance changed path was not reported"): return
	if not _check(conformance.manifest.rigged_meshes == rigged_before, "conformance preparation changed rigged mesh slots"): return
	if not _check(conformance.manifest.source_rig_contract == source_rig_contract_before, "conformance preparation changed source rig metadata"): return
	if not _check(_read_text(primary_source_mesh) == primary_mesh_before, "conformance preparation changed primary source mesh file"): return
	if not _check(_read_text(secondary_source_mesh) == secondary_mesh_before, "conformance preparation changed secondary source mesh file"): return
	if not _check(conformance.conformance_plan.validation_constraints.preserve_skeleton_profile_humanoid, "SkeletonProfileHumanoid validation constraint was not recorded"): return
	if not _check(conformance.conformance_plan.validation_constraints.preserve_stable_socket_names, "stable socket validation constraint was not recorded"): return
	var conformance_inspection := store.inspect_conformance("draft_character", "v2")
	if not _check(conformance_inspection.ok, conformance_inspection.get("error", "conformance inspect failed")): return
	if not _check(conformance_inspection.conformance_plan.reference_version == "v2", "conformance inspect did not load plan"): return
	var conformance_approval := store.approve_conformance("draft_character", {"version": "v2"})
	if not _check(conformance_approval.ok, conformance_approval.get("error", "conformance approval failed")): return
	if not _check(conformance_approval.manifest.stage == "conformance_approved", "conformance approval stage was not recorded"): return
	if not _check(conformance_approval.manifest.conformance.approved, "conformance approval flag was not recorded"): return
	var missing_conformance_approval := store.approve_conformance("draft_character", {"version": "v99"})
	if not _check(not missing_conformance_approval.ok, "missing conformance approval should fail"): return
	var plan_path := test_root.path_join("characters/draft_character/conformance/v2/conformance_plan.json")
	var plan_file := FileAccess.open(plan_path, FileAccess.READ)
	if not _check(plan_file != null, "conformance plan could not be opened for negative approval test"): return
	var saved_plan = JSON.parse_string(plan_file.get_as_text())
	saved_plan["providers"] = []
	var write_plan := FileAccess.open(plan_path, FileAccess.WRITE)
	write_plan.store_string(JSON.stringify(saved_plan, "  ") + "\n")
	write_plan.close()
	var empty_provider_approval := store.approve_conformance("draft_character", {"version": "v2"})
	if not _check(not empty_provider_approval.ok and str(empty_provider_approval.error).contains("provider provenance"), "empty provider list should block conformance approval"): return
	saved_plan["providers"] = [{"provider_id": "hunyuan3d_2"}]
	write_plan = FileAccess.open(plan_path, FileAccess.WRITE)
	write_plan.store_string(JSON.stringify(saved_plan, "  ") + "\n")
	write_plan.close()
	var rejected_provider_approval := store.approve_conformance("draft_character", {"version": "v2"})
	if not _check(not rejected_provider_approval.ok and str(rejected_provider_approval.error).contains("Rejected"), "rejected provider should block conformance approval"): return
	var blocked_continue := store.continue_pipeline("draft_character", {"version": "v2"})
	if not _check(not blocked_continue.ok, "continuation should require warning acknowledgement"): return
	var continued := store.continue_pipeline("draft_character", {"version": "v2", "warnings_acknowledged": true})
	if not _check(continued.ok, continued.get("error", "continuation failed")): return
	if not _check(continued.manifest.stage == "pipeline_enabled", "pipeline stage was not enabled"): return
	if not _check(continued.manifest.pipeline.approved_version == "v2", "pipeline approved version was not recorded"): return
	if not _check(continued.manifest.pipeline.readiness_warnings.size() == 1, "pipeline readiness warnings were not recorded"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/blender/v2/reference_inputs.json")), "Blender reference input was not written"): return
	if not _check(FileAccess.file_exists(test_root.path_join("characters/draft_character/blender/v2/mesh_guidance.json")), "mesh guidance was not written"): return
	if not _check(continued.changed_paths.has(test_root.path_join("characters/draft_character/blender/v2/reference_inputs.json")), "Blender reference input changed path was not reported"): return
	if not _check(continued.changed_paths.has(test_root.path_join("characters/draft_character/blender/v2/mesh_guidance.json")), "mesh guidance changed path was not reported"): return
	if not _check(continued.manifest.pipeline.mesh_guidance_path.ends_with("blender/v2/mesh_guidance.json"), "mesh guidance path was not recorded"): return
	if not _check(continued.mesh_guidance.validation_constraints.source_meshes_immutable, "mesh guidance immutable-source constraint was not recorded"): return
	if not _check(continued.mesh_guidance.secondary_asset_candidates[0].socket == "hand_l", "mesh guidance secondary asset socket was not recorded"): return
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
	var canonical_fields := TurnaroundWorkflow.extract_prompt_fields(workflow)
	if not _check(canonical_fields.prompt.begins_with("Full-body game character reference"), "canonical prompt import failed"): return
	if not _check(int(canonical_fields.seed) == 424242, "canonical seed import failed"): return
	if not _check(canonical_fields.character_id == "field_engineer", "canonical character import failed"): return
	var open_file := FileAccess.open("res://addons/build_me_godot/workflows/character_turnaround_open.json", FileAccess.READ)
	if not _check(open_file != null, "open workflow could not be loaded"): return
	var open_workflow = JSON.parse_string(open_file.get_as_text())
	if not _check(open_workflow is Dictionary, "open workflow is malformed"): return
	var open_fields := TurnaroundWorkflow.extract_prompt_fields(open_workflow)
	if not _check(open_fields.prompt.begins_with("Full-body game character reference"), "open workflow prompt import failed"): return
	if not _check(open_fields.negative_prompt.contains("cropped head"), "open workflow negative prompt import failed"): return
	if not _check(int(open_fields.seed) == 424242, "open workflow seed import failed"): return
	if not _check(open_fields.character_id == "field_engineer", "open workflow character import failed"): return
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
	var handoff_requirements_file := FileAccess.open("res://addons/build_me_godot/integrations/blender/prepare_conformance_handoff.requirements.json", FileAccess.READ)
	if not _check(handoff_requirements_file != null, "conformance handoff requirements could not be opened"): return
	var handoff_requirements = JSON.parse_string(handoff_requirements_file.get_as_text())
	if not _check(handoff_requirements is Dictionary and handoff_requirements.pose_contract == "neutral_a_pose_30deg_v1", "conformance handoff requirements are malformed"): return
	if not _check(handoff_requirements.configuration.optional.has("mesh_guidance"), "conformance handoff must accept mesh guidance input"): return
	if not _check(handoff_requirements.configuration.optional.has("target_rig"), "conformance handoff must accept target rig isolation input"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("changed_paths"), "conformance handoff report must declare changed paths"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("target_rig"), "conformance handoff report must declare target rig"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("shell_guides"), "conformance handoff report must declare shell guides"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("alignment"), "conformance handoff report must declare alignment metadata"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("bounds"), "conformance handoff report must declare bounds metadata"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("guidance"), "conformance handoff report must declare guidance path"): return
	if not _check(handoff_requirements.outputs.report_required_fields.has("silhouette_overlays"), "conformance handoff report must declare silhouette overlays"): return
	if not _check(handoff_requirements.outputs.guidance_required_fields.has("target_rig"), "conformance guidance requirements must declare target rig"): return
	if not _check(handoff_requirements.outputs.guidance_required_fields.has("shell_guides"), "conformance guidance requirements must declare shell guides"): return
	if not _check(handoff_requirements.outputs.guidance_required_fields.has("clothing_shell_candidates"), "conformance guidance requirements must declare clothing candidates"): return
	if not _check(handoff_requirements.outputs.guidance_required_fields.has("prop_candidates"), "conformance guidance requirements must declare prop candidates"): return
	if not _check(handoff_requirements.outputs.required_files.has("{target_rig}/conformance_guidance.json"), "conformance handoff requirements must declare target-scoped guidance JSON"): return
	if not _check(handoff_requirements.outputs.required_files.has("{target_rig}/overlays/front_silhouette_overlay.svg"), "conformance handoff requirements must declare target-scoped front overlay preview"): return
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
	var conformance_fixture_file := FileAccess.open("res://tests/fixtures/conformance_plans.json", FileAccess.READ)
	if not _check(conformance_fixture_file != null, "conformance fixtures could not be opened"): return
	var conformance_fixtures = JSON.parse_string(conformance_fixture_file.get_as_text())
	if not _check(conformance_fixtures is Array, "conformance fixtures are malformed"): return
	for fixture in conformance_fixtures:
		if not _check(fixture.has("status") and fixture.has("providers") and fixture.providers is Array, "conformance fixture missing required fields: %s" % fixture.get("name", "")): return
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
