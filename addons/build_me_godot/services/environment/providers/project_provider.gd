@tool
extends RefCounted

const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")


func check(capability: String) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	var plugin_path := "res://addons/build_me_godot/plugin.cfg"
	checks.append(EnvironmentReport.result(
		"godot.addon.manifest", capability,
		"pass" if FileAccess.file_exists(plugin_path) else "fail", "required",
		"Build Me Godot addon manifest is available.", plugin_path, plugin_path, {},
		PackedStringArray(["install.godot.addon"])
	))
	var enabled_plugins := ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray()) as PackedStringArray
	checks.append(EnvironmentReport.result(
		"godot.addon.enabled", capability,
		"pass" if enabled_plugins.has(plugin_path) else "fail", "required",
		"Build Me Godot is enabled for this project.", enabled_plugins.has(plugin_path), true, {},
		PackedStringArray(["configure.godot.enable_addon"])
	))
	var workspace := "res://build_me_godot"
	var workspace_exists := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(workspace))
	checks.append(EnvironmentReport.result(
		"project.workspace", "project_workspace",
		"pass" if workspace_exists else "fail", "required",
		"Project character workspace exists." if workspace_exists else "Project character workspace is missing.", workspace, workspace, {},
		PackedStringArray(["create.project.workspace"])
	))
	if capability in ["all", "canonical_generation"]:
		checks.append(_packaged_file("workflow.template.canonical", "canonical_generation", "res://addons/build_me_godot/workflows/canonical_only_api.json"))
		checks.append(_packaged_file("workflow.requirements.canonical", "canonical_generation", "res://addons/build_me_godot/workflows/canonical_only_api.requirements.json"))
	if capability in ["all", "multiview_generation"]:
		checks.append(_packaged_file("workflow.template.multiview", "multiview_generation", "res://addons/build_me_godot/workflows/multiview_only_api.json"))
		checks.append(_packaged_file("workflow.requirements.multiview", "multiview_generation", "res://addons/build_me_godot/workflows/multiview_only_api.requirements.json"))
	if capability in ["all", "field_engineer_mesh_conformance"]:
		checks.append(_packaged_file("conformance.providers", "field_engineer_mesh_conformance", "res://addons/build_me_godot/integrations/reconstruction/conformance_providers.json"))
		checks.append(_packaged_file("conformance.requirements.triposr", "field_engineer_mesh_conformance", "res://addons/build_me_godot/integrations/reconstruction/triposr/triposr.requirements.json"))
	return checks


func _packaged_file(id: String, capability: String, path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	return EnvironmentReport.result(
		id, capability, "pass" if exists else "fail", "required",
		"Packaged workflow declaration is available." if exists else "Packaged workflow declaration is missing.",
		path if exists else null, path, {}, PackedStringArray(["reinstall.godot.addon"])
	)
