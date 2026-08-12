extends SceneTree

const ComfyUIClient = preload("res://addons/build_me_godot/services/comfyui_client.gd")

var queued_prompt_id := ""
var received_prompt_id := ""
var received_history := {}
var failure := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var port := OS.get_environment("BUILD_ME_GODOT_MOCK_COMFYUI_PORT")
	if port.is_empty():
		push_error("BUILD_ME_GODOT_MOCK_COMFYUI_PORT is required")
		quit(1)
		return
	var client := ComfyUIClient.new()
	client.configure("http://127.0.0.1:%s" % port)
	client.prompt_queued.connect(func(prompt_id: String) -> void:
		queued_prompt_id = prompt_id
	)
	client.history_received.connect(func(prompt_id: String, history: Dictionary) -> void:
		received_prompt_id = prompt_id
		received_history = history
	)
	client.request_failed.connect(func(message: String) -> void:
		failure = message
	)
	get_root().add_child(client)

	var queue_error := client.queue_prompt({"1": {"class_type": "MockNode", "inputs": {}}}, "mock-client")
	if not _check(queue_error == OK, "queue request did not start: %s" % error_string(queue_error)): return
	if not await _wait_for(func() -> bool: return not queued_prompt_id.is_empty()):
		push_error("queue response timed out: %s" % failure)
		quit(1)
		return
	if not _check(queued_prompt_id == "mock-prompt-1", "prompt id was not parsed"): return

	var history_error := client.request_history(queued_prompt_id)
	if not _check(history_error == OK, "history request did not start: %s" % error_string(history_error)): return
	if not await _wait_for(func() -> bool: return not received_prompt_id.is_empty()):
		push_error("history response timed out: %s" % failure)
		quit(1)
		return
	if not _check(received_prompt_id == "mock-prompt-1", "history prompt id did not round-trip"): return
	if not _check(received_history["mock-prompt-1"].outputs.save_front.images[0].filename == "front.png", "history image output was not parsed"): return
	quit(0)


func _wait_for(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
