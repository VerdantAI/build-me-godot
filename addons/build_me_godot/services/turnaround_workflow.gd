@tool
extends RefCounted

const CANONICAL_WORKFLOW := "res://addons/build_me_godot/workflows/canonical_only_api.json"
const MULTIVIEW_WORKFLOW := "res://addons/build_me_godot/workflows/multiview_only_api.json"


static func configure_canonical(workflow: Dictionary, manifest: Dictionary) -> Dictionary:
	var configured := workflow.duplicate(true)
	var required_nodes := PackedStringArray(["1", "3", "4", "5", "10"])
	for node_id in required_nodes:
		if not configured.get(node_id) is Dictionary:
			return {}
	configured["1"].inputs.value = str(manifest.get("prompt", ""))
	configured["3"].inputs.value = int(manifest.get("seed", 0))
	configured["4"].inputs.value = int(manifest.get("image", {}).get("width", 768))
	configured["5"].inputs.value = int(manifest.get("image", {}).get("height", 1024))
	configured["10"].inputs.value = str(manifest.get("character_id", "character"))
	return configured
