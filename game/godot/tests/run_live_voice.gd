extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var reply: String = await get_root().get_node("Voices").ask([{"role": "user", "content": "Antworte nur mit OK."}], 20)
	print("LIVE_REPLY_EMPTY=" + str(reply.is_empty()))
	print("LIVE_ERROR=" + str(get_root().get_node("Voices").last_error))
	quit(1 if reply.is_empty() else 0)
