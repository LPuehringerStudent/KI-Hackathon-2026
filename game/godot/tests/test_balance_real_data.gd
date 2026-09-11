extends "res://tests/base_test.gd"
## Balance guards on the real extract in res://data/ (Track A, Task 1): every decision type must
## move a meter visibly, without cliffs. Skips while the data files are not there yet.

const GS := preload("res://scripts/game_state.gd")
const DATA_DIR := "res://data/"


func _load_data() -> Dictionary:
	var data := {}
	for key: String in ["venues", "trees", "fountains", "toilets", "streets"]:
		var path := DATA_DIR + key + ".json"
		if not FileAccess.file_exists(path):
			return {}
		data[key] = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data


func _after(data: Dictionary, type: String, id: String, decision_id: String) -> Dictionary:
	var state: Dictionary = GS.create()
	GS.decide(state, GS.find_entity(data, id, type), decision_id)
	return GS.compute_meters(state, data)


func test_real_data_balance() -> void:
	var data := _load_data()
	if data.is_empty():
		print("  SKIP test_real_data_balance: no extracted data in %s yet" % DATA_DIR)
		return
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	for key: String in ["attendance", "money", "happiness"]:
		check(fresh[key] >= 40.0 and fresh[key] <= 90.0, "fresh %s should leave room both ways (40..90), got %.1f" % [key, fresh[key]])

	for venue: Dictionary in data.venues:
		var m := _after(data, "venue", venue.id, "shuttle")
		check(m.attendance - fresh.attendance >= 1.0, "shuttle at %s should add >= 1 attendance" % venue.name)
		check(m.money < fresh.money, "shuttle at %s should cost money" % venue.name)

	# Losses are proportional to the event weight a service uniquely covers, so a big one may sting
	# (wc_m20 is the only toilet near the whole OK cluster: -6.1) — but no single service may carry
	# more than 30 % of its happiness term; the old threshold model cost -20.
	var max_single_close := 0.3 * maxf(GS.FOUNTAIN_WEIGHT, GS.TOILET_WEIGHT)
	var best_relocation := 0.0
	for type: String in ["fountain", "toilet"]:
		for service: Dictionary in data[type + "s"]:
			var closed := _after(data, type, service.id, "close")
			var loss: float = fresh.happiness - closed.happiness
			check(loss <= max_single_close, "closing %s %s is a cliff (-%.1f > %.1f)" % [type, service.id, loss, max_single_close])
			best_relocation = maxf(best_relocation, _after(data, type, service.id, "relocate").happiness - fresh.happiness)
	check(best_relocation >= 1.0, "some relocation should add >= 1 happiness, best %.1f" % best_relocation)

	for tree: Dictionary in data.trees:
		check(_after(data, "tree", tree.id, "cut").happiness < fresh.happiness, "cutting tree %s should lower happiness" % tree.id)

	var best_street := 0.0
	for street: Dictionary in data.streets:
		best_street = maxf(best_street, _after(data, "street", street.id, "pedestrian").attendance - fresh.attendance)
	check(best_street >= 1.0, "some pedestrian street should add >= 1 attendance, best %.1f" % best_street)
