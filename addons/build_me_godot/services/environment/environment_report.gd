@tool
extends RefCounted

const SCHEMA_VERSION := 1


static func result(id: String, capability: String, status: String, importance: String, summary: String, detected = null, expected = null, evidence := {}, remediation_ids := PackedStringArray()) -> Dictionary:
	return {
		"id": id,
		"capability": capability,
		"status": status,
		"importance": importance,
		"summary": summary,
		"detected": detected,
		"expected": expected,
		"evidence": evidence,
		"remediation_ids": remediation_ids
	}


static func build(capability: String, checks: Array[Dictionary], addon_version := "unknown") -> Dictionary:
	checks.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.id) < str(right.id))
	var ready := true
	for check in checks:
		if check.importance == "required" and check.status in ["fail", "unknown"]:
			ready = false
	return {
		"schema_version": SCHEMA_VERSION,
		"addon_version": addon_version,
		"godot_version": Engine.get_version_info().string,
		"requested_capability": capability,
		"generated_at": Time.get_datetime_string_from_system(true),
		"overall_status": "ready" if ready else "not_ready",
		"checks": checks,
		"remediations": _remediations(checks)
	}


static func exit_code(report: Dictionary) -> int:
	return 0 if report.get("overall_status") == "ready" else 1


static func redact(report: Dictionary) -> Dictionary:
	var copy := report.duplicate(true)
	var home := OS.get_environment("HOME").trim_suffix("/")
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return _redact_value(copy, home, project)


static func render_text(report: Dictionary) -> String:
	var lines := PackedStringArray([
		"Build Me Godot environment: %s" % report.overall_status,
		"Capability: %s" % report.requested_capability
	])
	var grouped := {}
	for check in report.checks:
		if not grouped.has(check.capability):
			grouped[check.capability] = []
		grouped[check.capability].append(check)
	var capabilities := PackedStringArray(grouped.keys())
	capabilities.sort()
	for capability in capabilities:
		lines.append("")
		lines.append(capability.replace("_", " ").capitalize())
		for check in grouped[capability]:
			lines.append("  [%s] %s: %s" % [str(check.status).to_upper(), check.id, check.summary])
	return "\n".join(lines)


static func _remediations(checks: Array[Dictionary]) -> Array[Dictionary]:
	var ids := {}
	for check in checks:
		if check.status == "pass" or check.status == "skipped":
			continue
		for remediation_id in check.remediation_ids:
			ids[remediation_id] = true
	var result: Array[Dictionary] = []
	var ordered := PackedStringArray(ids.keys())
	ordered.sort()
	for remediation_id in ordered:
		result.append({"id": remediation_id, "mode": "manual", "applied": false})
	return result


static func _redact_value(value, home: String, project: String):
	if value is Dictionary:
		for key in value.keys():
			value[key] = _redact_value(value[key], home, project)
		return value
	if value is Array:
		for index in value.size():
			value[index] = _redact_value(value[index], home, project)
		return value
	if value is String:
		var text: String = value
		if not project.is_empty():
			text = text.replace(project, "res://")
		if not home.is_empty():
			text = text.replace(home, "<home>")
		return text
	return value
