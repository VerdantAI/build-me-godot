extends SceneTree

const EnvironmentChecker = preload("res://addons/build_me_godot/services/environment/environment_checker.gd")
const EnvironmentReport = preload("res://addons/build_me_godot/services/environment/environment_report.gd")
const InstallPlan = preload("res://addons/build_me_godot/services/environment/install_plan.gd")
const InstallActions = preload("res://addons/build_me_godot/services/environment/install_actions.gd")
const Config = preload("res://addons/build_me_godot/services/config.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not parsed.ok:
		printerr(parsed.error)
		quit(2)
		return
	var checker := EnvironmentChecker.new()
	get_root().add_child(checker)
	var configured := Config.resolve(parsed.overrides)
	var options := {
		"comfyui_url": configured[Config.COMFYUI_URL],
		"blender_executable": configured[Config.BLENDER_PATH],
		"comfyui_root": configured[Config.COMFYUI_ROOT],
		"reconstruction_command": configured[Config.RECONSTRUCTION_COMMAND],
		"animation_asset": configured[Config.ANIMATION_ASSET],
		"deep_check": parsed.deep_check
	}
	var report: Dictionary = await checker.check(parsed.capability, options)
	if report.has("error"):
		printerr(report.error)
		quit(int(report.get("exit_code", 2)))
		return
	if parsed.support_report:
		report = EnvironmentReport.redact(report)
	var output := report
	if parsed.command == "plan":
		output = {"environment": report, "install_plan": InstallPlan.build(report, options)}
	elif parsed.command == "apply":
		var plan := InstallPlan.build(report, options)
		var selected := _find_action(plan.actions, parsed.action)
		if selected.is_empty():
			printerr("Action is not present in the current plan: %s" % parsed.action)
			quit(2)
			return
		var action_result := InstallActions.apply(selected)
		output = {"environment": report, "action": selected, "result": action_result}
		if not action_result.ok or not action_result.get("verification", false):
			_render(output, parsed.format)
			quit(3)
			return
	elif parsed.command == "verify":
		output = report
	_render(output, parsed.format)
	quit(int(report.exit_code) if parsed.command in ["check", "plan", "verify"] else 0)


func _render(value: Dictionary, format: String) -> void:
	if format == "json":
		print(JSON.stringify(value))
	else:
		if value.has("checks"):
			print(EnvironmentReport.render_text(value))
		else:
			print(JSON.stringify(value, "  "))


func _parse_args(arguments: PackedStringArray) -> Dictionary:
	if arguments.is_empty() or arguments[0] not in ["check", "plan", "apply", "verify"]:
		return {"ok": false, "error": "Usage: check|plan|apply|verify [--capability NAME] [--format text|json] [--action ID]"}
	var result := {
		"ok": true,
		"command": arguments[0],
		"capability": "all",
		"format": "text",
		"overrides": {},
		"support_report": false,
		"deep_check": false,
		"action": ""
	}
	var index := 1
	while index < arguments.size():
		if arguments[index] == "--support-report":
			result.support_report = true
			index += 1
			continue
		if arguments[index] == "--deep-check":
			result.deep_check = true
			index += 1
			continue
		if index + 1 >= arguments.size():
			return {"ok": false, "error": "Missing value for %s" % arguments[index]}
		var option := arguments[index]
		var value := arguments[index + 1]
		match option:
			"--capability": result.capability = value
			"--format": result.format = value
			"--comfyui-url": result.overrides[Config.COMFYUI_URL] = value
			"--blender": result.overrides[Config.BLENDER_PATH] = value
			"--comfyui-root": result.overrides[Config.COMFYUI_ROOT] = value
			"--reconstruction-command": result.overrides[Config.RECONSTRUCTION_COMMAND] = value
			"--animation-asset": result.overrides[Config.ANIMATION_ASSET] = value
			"--action": result.action = value
			_: return {"ok": false, "error": "Unknown option: %s" % option}
		index += 2
	if not EnvironmentChecker.supports_capability(result.capability):
		return {"ok": false, "error": "Unknown capability: %s" % result.capability}
	if result.format not in ["text", "json"]:
		return {"ok": false, "error": "Unknown format: %s" % result.format}
	if result.command == "apply" and result.action.is_empty():
		return {"ok": false, "error": "apply requires --action ID"}
	return result


func _find_action(actions: Array, id: String) -> Dictionary:
	for action in actions:
		if action.id == id:
			return action
	return {}
