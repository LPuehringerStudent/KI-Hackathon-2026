extends SceneTree

class TestClient extends "res://scripts/http_client.gd":
	var url := ""
	var timeout := 1.0

	func _endpoint() -> String:
		return url

	func _timeout() -> float:
		return timeout

var failures := 0
var concurrent: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func _run() -> void:
	var base := OS.get_environment("TEST_PROXY_URL")
	if base.is_empty():
		printerr("Run through tools/check_proxy_client.py")
		quit(1)
		return
	var client := TestClient.new()
	root.add_child(client)
	for path in ["/ok", "/status/401", "/status/403", "/status/429", "/status/500", "/malformed", "/empty", "/ok"]:
		client.url = base + path
		var result := await client.ask([{"role": "user", "content": "Sag OK"}], 50)
		var success: bool = path == "/ok"
		check(result == ("OK" if success else ""), path + " result")
		check(client.last_error == ("" if success else "PROXY_DOWN"), path + " error state")
	client.url = base + "/timeout"
	client.timeout = 0.1
	check(await client.ask([], 50) == "" and client.last_error == "PROXY_DOWN", "timeout")
	client.url = "http://127.0.0.1:1/"
	check(await client.ask([], 50) == "" and client.last_error == "PROXY_DOWN", "connection refused")
	client.url = base + "/ok"
	client.timeout = 1.0
	_collect(client)
	_collect(client)
	while concurrent.size() < 2:
		await process_frame
	check(concurrent == ["OK", "OK"], "queued requests complete")
	await process_frame
	client.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _collect(client: Node) -> void:
	concurrent.append(await client.ask([], 50))
