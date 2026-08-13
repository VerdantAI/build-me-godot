@tool
extends RefCounted

const CANONICAL_WORKFLOW := "res://addons/build_me_godot/workflows/canonical_only_api.json"
const MULTIVIEW_WORKFLOW := "res://addons/build_me_godot/workflows/multiview_only_api.json"
const POSITIVE_PROMPT_NODE := "1"
const NEGATIVE_PROMPT_NODE := "2"
const SEED_NODE := "3"
const CHARACTER_NAME_NODE := "10"


static func configure_canonical(workflow: Dictionary, manifest: Dictionary) -> Dictionary:
	var configured := workflow.duplicate(true)
	var required_nodes := PackedStringArray([POSITIVE_PROMPT_NODE, SEED_NODE, "4", "5", CHARACTER_NAME_NODE])
	for node_id in required_nodes:
		if not (configured.get(node_id) is Dictionary):
			return {}
	configured[POSITIVE_PROMPT_NODE].inputs.value = str(manifest.get("prompt", ""))
	if configured.get(NEGATIVE_PROMPT_NODE) is Dictionary:
		configured[NEGATIVE_PROMPT_NODE].inputs.value = str(manifest.get("negative_prompt", ""))
	configured[SEED_NODE].inputs.value = int(manifest.get("seed", 0))
	configured["4"].inputs.value = int(manifest.get("image", {}).get("width", 768))
	configured["5"].inputs.value = int(manifest.get("image", {}).get("height", 1024))
	configured[CHARACTER_NAME_NODE].inputs.value = str(manifest.get("character_id", "character"))
	return configured


static func extract_prompt_fields(workflow: Dictionary) -> Dictionary:
	if workflow.has("nodes") and (workflow.get("nodes", []) is Array):
		return _extract_open_prompt_fields(workflow.get("nodes", []))
	var graph := workflow.get("prompt", workflow)
	if graph is Dictionary:
		return _extract_api_prompt_fields(graph)
	return {}


static func _extract_api_prompt_fields(graph: Dictionary) -> Dictionary:
	var fields := {}
	if graph.get(POSITIVE_PROMPT_NODE) is Dictionary:
		fields["prompt"] = str(graph[POSITIVE_PROMPT_NODE].get("inputs", {}).get("value", ""))
	if graph.get(NEGATIVE_PROMPT_NODE) is Dictionary:
		fields["negative_prompt"] = str(graph[NEGATIVE_PROMPT_NODE].get("inputs", {}).get("value", ""))
	if graph.get(SEED_NODE) is Dictionary:
		fields["seed"] = int(graph[SEED_NODE].get("inputs", {}).get("value", 0))
	if graph.get(CHARACTER_NAME_NODE) is Dictionary:
		fields["character_id"] = str(graph[CHARACTER_NAME_NODE].get("inputs", {}).get("value", ""))
	return fields


static func _extract_open_prompt_fields(nodes: Array) -> Dictionary:
	var fields := {}
	for node in nodes:
		if not (node is Dictionary):
			continue
		var raw_id = node.get("id", "")
		var id := str(int(raw_id)) if raw_id is float or raw_id is int else str(raw_id)
		var widgets: Array = node.get("widgets_values", [])
		if widgets.is_empty():
			continue
		if id == POSITIVE_PROMPT_NODE:
			fields["prompt"] = str(widgets[0])
		elif id == NEGATIVE_PROMPT_NODE:
			fields["negative_prompt"] = str(widgets[0])
		elif id == SEED_NODE:
			fields["seed"] = int(widgets[0])
		elif id == CHARACTER_NAME_NODE:
			fields["character_id"] = str(widgets[0])
	return fields
