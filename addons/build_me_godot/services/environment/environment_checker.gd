@tool
extends Node

const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const ProjectProvider = preload("res://addons/build_me_godot/services/environment/providers/project_provider.gd")
const LocalToolsProvider = preload("res://addons/build_me_godot/services/environment/providers/local_tools_provider.gd")
const ComfyUIProvider = preload("res://addons/build_me_godot/services/environment/providers/comfyui_provider.gd")

const CAPABILITIES := [
	"project_workspace", "canonical_generation", "multiview_generation",
	"reconstruction", "blender_humanoid_build", "godot_character_import",
	"last_mile_refinement", "field_engineer_mesh_conformance", "all"
]


static func supports_capability(capability: String) -> bool:
	return CAPABILITIES.has(capability)


func check(capability: String, options := {}) -> Dictionary:
	if not supports_capability(capability):
		return {"error": "Unknown capability: %s" % capability, "exit_code": 2}
	var checks: Array[Dictionary] = []
	checks.append_array(ProjectProvider.new().check(capability))
	checks.append_array(LocalToolsProvider.new().check(capability, options))
	if capability in ["all", "canonical_generation", "multiview_generation"]:
		var comfy_provider := ComfyUIProvider.new()
		add_child(comfy_provider)
		checks.append_array(await comfy_provider.check(capability, str(options.get("comfyui_url", "http://127.0.0.1:8188"))))
		comfy_provider.queue_free()
	var report := EnvironmentReport.build(capability, checks, _addon_version())
	report["exit_code"] = EnvironmentReport.exit_code(report)
	return report


func _addon_version() -> String:
	var config := ConfigFile.new()
	if config.load("res://addons/build_me_godot/plugin.cfg") != OK:
		return "unknown"
	return str(config.get_value("plugin", "version", "unknown"))
