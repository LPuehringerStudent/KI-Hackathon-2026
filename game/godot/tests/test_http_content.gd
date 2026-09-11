extends "res://tests/base_test.gd"

const Client := preload("res://scripts/http_client.gd")


func test_response_shapes() -> void:
	var client := Client.new()
	for value: Variant in [null, [], {}, {"choices": []}, {"choices": [null]}, {"choices": [{"message": null}]}, {"choices": [{"message": {"content": 12}}]}]:
		check(client._content(JSON.stringify(value).to_utf8_buffer()) == "", "invalid response must fail")
	check(client._content('{"choices":[{"message":{"content":" OK "}}]}'.to_utf8_buffer()) == "OK", "valid response extracted")
	client.free()
