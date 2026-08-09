@tool
extends Node

signal prompt_queued(prompt_id: String)
signal history_received(prompt_id: String, history: Dictionary)
signal request_failed(message: String)

var base_url := "http://127.0.0.1:8188"
var queue_request: HTTPRequest
var history_request: HTTPRequest
var requested_prompt_id := ""


func _ready() -> void:
	queue_request = HTTPRequest.new()
	queue_request.timeout = 30.0
	queue_request.request_completed.connect(_on_queue_completed)
	add_child(queue_request)

	history_request = HTTPRequest.new()
	history_request.timeout = 15.0
	history_request.request_completed.connect(_on_history_completed)
	add_child(history_request)


func configure(url: String) -> void:
	base_url = url.strip_edges().trim_suffix("/")


func queue_prompt(api_workflow: Dictionary, client_id := "") -> Error:
	if api_workflow.is_empty():
		request_failed.emit("The API workflow is empty.")
		return ERR_INVALID_DATA
	var payload := {"prompt": api_workflow}
	if not client_id.is_empty():
		payload["client_id"] = client_id
	return queue_request.request(
		base_url + "/prompt",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func request_history(prompt_id: String) -> Error:
	requested_prompt_id = prompt_id
	return history_request.request(base_url + "/history/" + prompt_id.uri_encode())


func load_api_workflow(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		request_failed.emit("Workflow not found: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		request_failed.emit("Workflow is not valid API-format JSON: %s" % path)
		return {}
	if parsed.size() == 1 and parsed.get("prompt") is Dictionary:
		return parsed.prompt
	return parsed


func _on_queue_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		request_failed.emit("ComfyUI queue request failed (%d)." % response_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or str(parsed.get("prompt_id", "")).is_empty():
		request_failed.emit("ComfyUI returned an invalid queue response.")
		return
	prompt_queued.emit(str(parsed.prompt_id))


func _on_history_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		request_failed.emit("ComfyUI history request failed (%d)." % response_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		request_failed.emit("ComfyUI returned invalid history data.")
		return
	history_received.emit(requested_prompt_id, parsed)
