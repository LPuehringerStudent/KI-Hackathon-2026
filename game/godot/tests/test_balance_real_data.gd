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
	if FileAccess.file_exists(DATA_DIR + "airquality.json"):  # optional, like data_loader.gd
		data["airquality"] = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR + "airquality.json"))
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

	# Hitzetag air quality: bounded, day 3 only, and exactly the modifier (fresh happiness has room for +-10).
	var day3: Dictionary = GS.create()
	GS.next_day(day3)
	GS.next_day(day3)
	var air := GS.air_quality_modifier(day3, data)
	check(absf(air) <= GS.AIR_MODIFIER, "air modifier out of bounds: %+.1f" % air)
	check(is_equal_approx(GS.compute_meters(day3, data).happiness, fresh.happiness + air),
		"day-3 happiness should be fresh %+.1f air, got %.1f vs %.1f" % [air, GS.compute_meters(day3, data).happiness, fresh.happiness])
	if data.has("airquality"):
		print("  INFO real air quality: PM10 %s at %s -> day-3 happiness %+.1f" % [data.airquality.get("pm10"), data.airquality.get("station"), air])

	for venue: Dictionary in data.venues:
		var m := _after(data, "venue", venue.id, "shuttle")
		# >= 0.5, not 1: gains scale with event weight, and the smallest isolated venue (Powerplayground,
		# weight 5 of 267) gains (SHUTTLE_REACH - ISOLATED_REACH) * 5/267 = 0.94.
		check(m.attendance - fresh.attendance >= 0.5, "shuttle at %s should add >= 0.5 attendance" % venue.name)
		check(m.money < fresh.money, "shuttle at %s should cost money" % venue.name)

	var best_relocation := 0.0
	for type: String in ["fountain", "toilet"]:
		for service: Dictionary in data[type + "s"]:
			var closed := _after(data, type, service.id, "close")
			# <= 7.0 (was 5.0): continuous scoring is proportional, not flat — closing
			# the toilet that uniquely covers ~24% of venue demand (wc_m20) legitimately
			# costs ~6. Team-agreed calibration, see PR #23 review thread.
			check(fresh.happiness - closed.happiness <= 7.0, "closing %s %s is a cliff (-%.1f)" % [type, service.id, fresh.happiness - closed.happiness])
			best_relocation = maxf(best_relocation, _after(data, type, service.id, "relocate").happiness - fresh.happiness)
	check(best_relocation >= 1.0, "some relocation should add >= 1 happiness, best %.1f" % best_relocation)

	for tree: Dictionary in data.trees:
		check(_after(data, "tree", tree.id, "cut").happiness < fresh.happiness, "cutting tree %s should lower happiness" % tree.id)

	var best_street := 0.0
	for street: Dictionary in data.streets:
		best_street = maxf(best_street, _after(data, "street", street.id, "pedestrian").attendance - fresh.attendance)
	check(best_street >= 1.0, "some pedestrian street should add >= 1 attendance, best %.1f" % best_street)


func _meters_on_day_three(state: Dictionary, data: Dictionary) -> Dictionary:
	var s := state.duplicate(true)
	GS.next_day(s)
	GS.next_day(s)
	return GS.compute_meters(s, data)


## Balance against the verdict tiers (GameState.verdict_title, which main.gd delegates to).
func test_real_data_verdicts() -> void:
	var data := _load_data()
	if data.is_empty():
		print("  SKIP test_real_data_verdicts: no extracted data in %s yet" % DATA_DIR)
		return
	var verdict_title: Callable = GS.verdict_title

	# Doing nothing is judged neutral, whatever the Hitzetag weather.
	for air: Variant in [null, { "pm10": 6.7 }, { "pm10": 35.0 }, { "pm10": 50.0 }]:
		var d := data.duplicate()
		d.erase("airquality")
		if air != null:
			d["airquality"] = air
		var title: String = verdict_title.call(_meters_on_day_three(GS.create(), d))
		check(title == "Stadt im Gleichgewicht", "untouched city with air %s should be neutral, got %s" % [air, title])

	# No single decision wins the best title (it used to take one shuttle).
	var singles: Array = []
	for venue: Dictionary in data.venues:
		singles.append(["venue", venue.id, "shuttle"])
	for street: Dictionary in data.streets:
		singles.append(["street", street.id, "pedestrian"])
	for type: String in ["fountain", "toilet"]:
		for service: Dictionary in data[type + "s"]:
			singles.append([type, service.id, "relocate"])
	singles.append(["tree", data.trees[0].id, "keep"])
	for single: Array in singles:
		var state: Dictionary = GS.create()
		GS.decide(state, GS.find_entity(data, single[1], single[0]), single[2])
		var title: String = verdict_title.call(_meters_on_day_three(state, data))
		check(title not in ["Volksnahe Stadtplanung", "Goldene:r Bürgermeister:in"], "a single %s on %s %s already wins a top title" % [single[2], single[0], single[1]])
		check(title != "Stadt in Schieflage", "a single %s on %s %s already ruins the city" % [single[2], single[0], single[1]])

	# The new middle tier is reachable with a couple of real decisions: two shuttles at the two
	# biggest venue clusters.
	var solid_or_better := false
	for first: Dictionary in data.venues:
		for second: Dictionary in data.venues:
			if solid_or_better or str(first.id) >= str(second.id):
				continue
			var state: Dictionary = GS.create()
			GS.decide(state, GS.find_entity(data, first.id, "venue"), "shuttle")
			GS.decide(state, GS.find_entity(data, second.id, "venue"), "shuttle")
			solid_or_better = verdict_title.call(_meters_on_day_three(state, data)) in ["Solide Verwaltung", "Gastgeber:in der Stadt", "Volksnahe Stadtplanung"]
	check(solid_or_better, "two shuttles should be able to lift the city to at least 'Solide Verwaltung'")


## Mentor pack on real data: purchases at headline venues and pricing must visibly matter.
func test_real_data_mentor_pack() -> void:
	var data := _load_data()
	if data.is_empty():
		print("  SKIP test_real_data_mentor_pack: no extracted data in %s yet" % DATA_DIR)
		return
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var headline: Array = data.venues.filter(func(v): return float(v.get("events", 0)) >= GS.HEADLINE_MIN_EVENTS)
	check(headline.size() >= 3, "expected several headline venues, got %d" % headline.size())
	for venue: Dictionary in headline:
		for kind: String in ["foodtruck", "security"]:
			var m := _after(data, "venue", venue.id, kind)
			var moved: float = maxf(m.happiness - fresh.happiness, m.attendance - fresh.attendance)
			check(moved >= 0.3, "one %s at %s should move a meter by >= 0.3, got %.2f" % [kind, venue.name, moved])
			check(m.money < fresh.money, "a %s at %s should cost money" % [kind, venue.name])
	var festival := GS.find_entity(data, "festival", "festival")
	var fair := _after(data, "festival", "festival", "fair")
	var premium := _after(data, "festival", "festival", "premium")
	check(fair.attendance > fresh.attendance and fair.money < fresh.money, "fair pricing: more visitors, less money")
	check(premium.attendance < fresh.attendance and premium.money > fresh.money, "premium pricing: fewer visitors, more money")
	var extended := _after(data, "venue", headline[0].id, "extend")
	check(extended.attendance > fresh.attendance and extended.happiness < fresh.happiness, "curfew extension trades happiness for attendance")
