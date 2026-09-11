extends "res://tests/base_test.gd"

const Dialogue := preload("res://scripts/dialogue.gd")


func test_intents_are_validated_and_hidden() -> void:
	var dialogue := Dialogue.new()
	var tree := {"type": "tree"}
	check(dialogue.parse_reply("Gut. [[ENTSCHEID:trim]]", tree) == {"reply": "Gut.", "intent": {"type": "decide", "decision_id": "trim"}}, "valid decision")
	check(dialogue.parse_reply("[[NAECHSTER_TAG]]", tree).intent == {"type": "next_day"}, "next day")
	for text in ["[[ENTSCHEID:shuttle]]", "[[ENTSCHEID:keep]]", "[[ENTSCHEID:trim]][[NAECHSTER_TAG]]", "[[ENTSCHEID:trim]][[ENTSCHEID:cut]]", "[[ENTSCHEID:", "[[other]]"]:
		var result := dialogue.parse_reply(text, tree)
		check(result.intent == null and not result.reply.contains("[["), "reject invalid or ambiguous marker: " + text)
	dialogue.free()


func test_prompt_keeps_facts_and_day_grounded() -> void:
	var dialogue := Dialogue.new()
	var prompt := dialogue._prompt({"type": "tree", "species": "Linde", "age_estimate": null, "crown_m": 9.0}, 3)
	check(prompt.contains("Linde") and prompt.contains("unbekannt") and prompt.contains("Tag 3"), "record and day in prompt")
	check(not prompt.contains("shuttle:"), "tree has no venue decisions")
	dialogue.free()
