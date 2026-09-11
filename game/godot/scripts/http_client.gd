extends Node

signal idle

const ENDPOINT := "http://127.0.0.1:8377/v1/chat/completions"
const MODEL := "mistralai/mistral-medium-3-5"

var last_error := ""
var _busy := false


func ask(messages: Array, max_tokens := 400) -> String:
	while _busy:
		await idle
	_busy = true
	var request := HTTPRequest.new()
	request.timeout = _timeout()
	request.body_size_limit = 262144
	add_child(request)
	# "cache": true lets the proxy serve repeat dialogues from its persistent
	# cache (instant + free + demo-consistent); see mistral-proxy/README.
	var payload := JSON.stringify({"messages": messages, "max_tokens": clampi(max_tokens, 1, 2000), "model": MODEL, "cache": true})
	var error := request.request(_endpoint(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)
	var reply := ""
	if error == OK:
		var response: Array = await request.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200:
			reply = _content(response[3])
	request.queue_free()
	last_error = "PROXY_DOWN" if reply.is_empty() else ""
	_release.call_deferred()
	return reply


func _endpoint() -> String:
	return ENDPOINT


func _timeout() -> float:
	return 8.0


func _release() -> void:
	_busy = false
	idle.emit()


func _content(body: PackedByteArray) -> String:
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return ""
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return ""
	var choices: Variant = parsed.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		return ""
	var message: Variant = choices[0].get("message")
	if not message is Dictionary or not message.get("content") is String:
		return ""
	return message.content.strip_edges()
