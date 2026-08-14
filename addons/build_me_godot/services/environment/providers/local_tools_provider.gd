@tool
extends RefCounted

const DependencyProbe = preload("res://addons/build_me_godot/core/dependency_probe.gd")
const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const BlenderRequirements = preload("res://addons/build_me_godot/services/blender_requirements.gd")


func check(capability: String, options: Dictionary) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	if capability in ["all", "blender_humanoid_build", "godot_character_import"]:
		var blender := DependencyProbe.blender(str(options.get("blender_executable", "blender")))
		var requirements := BlenderRequirements.load_metadata()
		var minimum: Array = requirements.metadata.minimum_blender_version if requirements.ok else [4, 2, 0]
		var compatible: bool = bool(blender.ok) and _version_at_least(blender.get("version", PackedInt32Array()), minimum)
		checks.append(EnvironmentReport.result(
			"blender.executable", "blender_humanoid_build",
			"pass" if compatible else "fail", "required",
			blender.label if compatible else ("Blender %s or newer is required." % _version_text(minimum) if blender.ok else blender.label),
			blender.get("version", blender.detail), minimum, {"command": blender.detail},
			PackedStringArray(["configure.blender.executable"])
		))
		if compatible and bool(options.get("deep_check", false)):
			checks.append(_deep_blender_check(str(blender.detail), requirements.metadata if requirements.ok else {}))
	if capability in ["all", "last_mile_refinement"]:
		var gator := DependencyProbe.gator_model_studio()
		checks.append(EnvironmentReport.result(
			"gator.addon", "last_mile_refinement",
			"pass" if gator.ok else "warning", "optional", gator.label,
			gator.detail, "Compatible Gator Model Studio installation", {},
			PackedStringArray(["install.optional.gator_model_studio"])
		))
	if capability in ["all", "reconstruction"]:
		var reconstruction_command := str(options.get("reconstruction_command", "")).strip_edges()
		var reconstruction_status := "unknown"
		var reconstruction_summary := "No reconstruction provider is configured for this project."
		if not reconstruction_command.is_empty():
			var output := []
			var exit_code := OS.execute(reconstruction_command, ["--version"], output, true)
			reconstruction_status = "pass" if exit_code == 0 else "fail"
			reconstruction_summary = "Reconstruction provider is available." if exit_code == 0 else "Configured reconstruction provider did not pass its version probe."
		checks.append(EnvironmentReport.result(
			"reconstruction.provider", "reconstruction", reconstruction_status, "required",
			reconstruction_summary, reconstruction_command if not reconstruction_command.is_empty() else null,
			"Configured local reconstruction provider", {},
			PackedStringArray(["configure.reconstruction.provider"])
		))
	if capability in ["all", "field_engineer_mesh_conformance"]:
		checks.append(_triposr_conformance_check(str(options.get("reconstruction_command", "")).strip_edges()))
		checks.append(_trellis_conformance_check(str(options.get("reconstruction_command", "")).strip_edges()))
	if capability in ["all", "blender_humanoid_build"]:
		var animation_asset := str(options.get("animation_asset", "")).strip_edges()
		var animation_exists := not animation_asset.is_empty() and FileAccess.file_exists(animation_asset)
		var animation_status := "pass" if animation_exists else ("unknown" if animation_asset.is_empty() else "fail")
		var animation_summary := "Animation library asset is available." if animation_exists else ("No animation library asset is configured for this project." if animation_asset.is_empty() else "Configured animation library asset is missing.")
		checks.append(EnvironmentReport.result(
			"animation.asset", "blender_humanoid_build", animation_status, "required",
			animation_summary, animation_asset if not animation_asset.is_empty() else null,
			"Configured commercially usable animation library", {},
			PackedStringArray(["configure.animation.asset"])
		))
	return checks


func _triposr_conformance_check(reconstruction_command: String) -> Dictionary:
	var requirements_path := "res://addons/build_me_godot/integrations/reconstruction/triposr/triposr.requirements.json"
	var requirements := _load_json(requirements_path)
	var evidence := {
		"requirements": requirements_path,
		"provider_id": "triposr",
		"provider_status": "supported_user_managed_command",
		"automatic_downloads_allowed": false,
		"license_record": requirements.get("code_license", "MIT"),
		"command_contract": requirements.get("build_me_godot_command_contract", {})
	}
	if reconstruction_command.is_empty():
		return EnvironmentReport.result(
			"conformance.provider.triposr", "field_engineer_mesh_conformance", "warning", "optional",
			"TripoSR proxy generation command is not configured; conformance can still import user-provided proxy meshes.",
			null, "Configured user-managed TripoSR command", evidence,
			PackedStringArray(["write.container.config", "install.manual.triposr.provider"])
		)
	var output := []
	var exit_code := OS.execute(reconstruction_command, ["--version"], output, true)
	return EnvironmentReport.result(
		"conformance.provider.triposr", "field_engineer_mesh_conformance",
		"pass" if exit_code == 0 else "warning", "optional",
		"TripoSR proxy generation command is configured." if exit_code == 0 else "Configured TripoSR command did not pass its version probe; manual proxy import remains available.",
		reconstruction_command, "User-managed TripoSR command", evidence,
		PackedStringArray(["write.container.config", "install.manual.triposr.provider"])
	)


func _trellis_conformance_check(reconstruction_command: String) -> Dictionary:
	var requirements_path := "res://addons/build_me_godot/integrations/reconstruction/trellis/trellis.requirements.json"
	var requirements := _load_json(requirements_path)
	var evidence := {
		"requirements": requirements_path,
		"provider_id": "trellis",
		"provider_status": "experimental_user_managed_command",
		"automatic_downloads_allowed": false,
		"license_record": requirements.get("code_license", "MIT"),
		"weight_license": requirements.get("weight_license", "MIT"),
		"command_contract": requirements.get("build_me_godot_command_contract", {}),
		"minimum_vram_gb": requirements.get("hardware", {}).get("minimum_vram_gb", 16)
	}
	var root := OS.get_environment("BUILD_ME_GODOT_TRELLIS_ROOT")
	if root.is_empty():
		root = OS.get_environment("TRELLIS_ROOT")
	var model := OS.get_environment("BUILD_ME_GODOT_TRELLIS_MODEL_PATH")
	evidence["trellis_root"] = root
	evidence["model_path"] = model
	if root.is_empty() or model.is_empty():
		return EnvironmentReport.result(
			"conformance.provider.trellis", "field_engineer_mesh_conformance", "warning", "optional",
			"TRELLIS is not configured; set a user-managed checkout and local model path before evaluation.",
			null, "Configured experimental TRELLIS command", evidence,
			PackedStringArray(["install.manual.trellis.provider"])
		)
	var script := ProjectSettings.globalize_path("res://utils/run-trellis.sh")
	var output := []
	var exit_code := OS.execute("bash", [script, "--version"], output, true) if FileAccess.file_exists(script) else 1
	return EnvironmentReport.result(
		"conformance.provider.trellis", "field_engineer_mesh_conformance",
		"pass" if exit_code == 0 else "warning", "optional",
		"TRELLIS provider is configured." if exit_code == 0 else "TRELLIS provider configuration did not pass its version probe; manual proxy import remains available.",
		reconstruction_command if not reconstruction_command.is_empty() else null,
		"User-managed TRELLIS command", evidence,
		PackedStringArray(["install.manual.trellis.provider"])
	)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _version_at_least(detected: PackedInt32Array, minimum: Array) -> bool:
	if detected.size() < 2:
		return false
	for index in minimum.size():
		var actual := detected[index] if index < detected.size() else 0
		if actual != int(minimum[index]):
			return actual > int(minimum[index])
	return true


func _version_text(version: Array) -> String:
	var parts := PackedStringArray()
	for component in version:
		parts.append(str(component))
	return ".".join(parts)


func _deep_blender_check(executable: String, metadata: Dictionary) -> Dictionary:
	var output := []
	var script := ProjectSettings.globalize_path("res://addons/build_me_godot/integrations/blender/probe_builder.py")
	var exit_code := OS.execute(executable, ["-b", "--factory-startup", "--python", script], output, true)
	var probe := {}
	for chunk in output:
		for line in str(chunk).split("\n"):
			if line.begins_with("BUILD_ME_GODOT_PROBE="):
				var parsed = JSON.parse_string(line.trim_prefix("BUILD_ME_GODOT_PROBE="))
				if parsed is Dictionary:
					probe = parsed
	var missing := PackedStringArray()
	for operator in metadata.get("required_operators", []):
		if not bool(probe.get("operators", {}).get(operator, false)):
			missing.append(operator)
	var passed := exit_code == 0 and not probe.is_empty() and missing.is_empty()
	return EnvironmentReport.result(
		"blender.builder.deep_probe", "blender_humanoid_build", "pass" if passed else "fail", "required",
		"Blender builder operators are available." if passed else "Blender builder deep probe failed or required operators are missing.",
		{"version": probe.get("blender_version"), "missing_operators": missing}, metadata.get("required_operators", []),
		{"probe_script": "res://addons/build_me_godot/integrations/blender/probe_builder.py"}, PackedStringArray(["configure.blender.executable"])
	)
