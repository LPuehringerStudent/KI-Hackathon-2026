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
	var day2: Dictionary = GS.create()
	GS.next_day(day2)
	var day3: Dictionary = GS.create()
	GS.next_day(day3)
	GS.next_day(day3)
	var air := GS.air_quality_modifier(day3, data)
	check(absf(air) <= GS.AIR_MODIFIER, "air modifier out of bounds: %+.1f" % air)
	check(is_equal_approx(GS.air_quality_modifier(day2, data), 0.0), "the Hitzetag modifier is day 3 only")
	# Day 2 and day 3 carry the same security incidents (both >= SECURITY_INCIDENT_FIRST_DAY), so
	# the difference between them is exactly the air modifier.
	check(is_equal_approx(GS.compute_meters(day3, data).happiness, GS.compute_meters(day2, data).happiness + air),
		"day-3 happiness should be day-2 %+.1f air, got %.1f vs %.1f" % [air, GS.compute_meters(day3, data).happiness, GS.compute_meters(day2, data).happiness])
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
		best_street = maxf(best_street, _after(data, "street", street.id, "carfree").attendance - fresh.attendance)
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

	# Doing nothing is judged neutral in ordinary weather. On the worst Hitzetag the unstaffed crowds
	# (security incidents from day SECURITY_INCIDENT_FIRST_DAY) plus the air penalty push happiness
	# below VERDICT_LOW -- intended pressure, but never the crisis ending.
	for air: Variant in [null, { "pm10": 6.7 }, { "pm10": 35.0 }, { "pm10": 50.0 }]:
		var d := data.duplicate()
		d.erase("airquality")
		if air != null:
			d["airquality"] = air
		var title: String = verdict_title.call(_meters_on_day_three(GS.create(), d))
		var allowed := ["Stadt im Gleichgewicht", "Effizienz-Tyrann:in"] if air == { "pm10": 50.0 } else ["Stadt im Gleichgewicht"]
		check(title in allowed, "untouched city with air %s should be %s, got %s" % [air, allowed, title])

	# No single decision wins the best title (it used to take one shuttle).
	var singles: Array = []
	for venue: Dictionary in data.venues:
		singles.append(["venue", venue.id, "shuttle"])
	for street: Dictionary in data.streets:
		singles.append(["street", street.id, "carfree"])
	for type: String in ["fountain", "toilet"]:
		for service: Dictionary in data[type + "s"]:
			singles.append([type, service.id, "relocate"])
	for venue: Dictionary in data.venues.slice(0, 5):
		singles.append(["venue", venue.id, "plant"])
	singles.append(["tree", data.trees[0].id, "trim"])
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
	# Food trucks pay off from day 1; security only bites once the crowds do, so it is measured on the
	# first incident day. A venue whose risk stays below the threshold still buys back its share of the
	# understaffing penalty -- smaller, and deliberately so.
	var day2: Dictionary = GS.create()
	GS.next_day(day2)
	var day2_fresh: Dictionary = GS.compute_meters(day2, data)
	for venue: Dictionary in headline:
		var truck := _after(data, "venue", venue.id, "foodtruck")
		check(maxf(truck.happiness - fresh.happiness, truck.attendance - fresh.attendance) >= 0.3,
			"one foodtruck at %s should move a meter by >= 0.3" % venue.name)
		check(truck.money < fresh.money, "a foodtruck at %s should cost money" % venue.name)
		var guarded: Dictionary = day2.duplicate(true)
		check(GS.decide(guarded, GS.find_entity(data, venue.id, "venue"), "security"), "security at %s" % venue.name)
		var m: Dictionary = GS.compute_meters(guarded, data)
		var moved: float = maxf(m.happiness - day2_fresh.happiness, m.attendance - day2_fresh.attendance)
		var at_risk: bool = GS.security_risk(venue, 0) >= GS.SECURITY_INCIDENT_THRESHOLD
		var floor_moved: float = 0.3 if at_risk else 0.1
		check(moved >= floor_moved, "one security at %s (risk %.2f) should move a meter by >= %.1f on day 2, got %.2f"
			% [venue.name, GS.security_risk(venue, 0), floor_moved, moved])
		check(m.money < day2_fresh.money, "security at %s should cost money" % venue.name)
	var festival := GS.find_entity(data, "festival", "festival")
	var fair := _after(data, "festival", "festival", "fair")
	var premium := _after(data, "festival", "festival", "premium")
	check(fair.attendance > fresh.attendance and fair.money < fresh.money, "fair pricing: more visitors, less money")
	check(premium.attendance < fresh.attendance and premium.money > fresh.money, "premium pricing: fewer visitors, more money")
	var extended := _after(data, "venue", headline[0].id, "extend")
	check(extended.attendance > fresh.attendance and extended.happiness < fresh.happiness, "curfew extension trades happiness for attendance")


## Plays a named route on the real data. Each day is a list of [type, id-or-name, decision];
## "pricing" steps use the festival entity, "talk" steps only consult a tree. Returns final meters.
func _play_route(data: Dictionary, days: Array) -> Dictionary:
	# Names repeat across types (a toilet is also called "Lentos Kunstmuseum"), so resolve a step's
	# name inside its own collection and fall back to treating it as an id.
	var by_type := {}
	for key: String in ["venues", "streets", "toilets", "fountains"]:
		var names := {}
		for record: Dictionary in data[key]:
			names[str(record.get("name", ""))] = str(record.id)
		by_type[key.trim_suffix("s")] = names
	var game: Dictionary = GS.create()
	for day_index in days.size():
		for step: Array in days[day_index]:
			var id: String = by_type.get(step[0], {}).get(step[1], step[1])
			if step[0] == "talk":
				GS.consult(game, GS.find_entity(data, id, "tree"))
				continue
			var entity := GS.find_entity(data, "festival", "festival") if step[0] == "pricing" else GS.find_entity(data, id, step[0])
			check(GS.decide(game, entity, step[2]), "route step %s %s %s must be accepted on day %d" % [step[0], step[1], step[2], day_index + 1])
		if day_index < days.size() - 1:
			GS.next_day(game)
	return GS.compute_meters(game, data)


## Every ending is reachable within a 3-day run with the committed air-quality cache, and the scripted
## demo (docs/pitch/demo-script.md) lands on a strong-but-not-gold ending with gold still in reach.
func test_real_data_endings() -> void:
	var data := _load_data()
	if data.is_empty() or not data.has("airquality"):
		print("  SKIP test_real_data_endings: needs res://data/ with the air-quality cache")
		return
	var fair := ["pricing", "festival", "fair"]
	var tree := ["talk", "baum_53e4b829ebce51b14361", "talk"]  # plane tree at the Mariendom; wc_18 = toilet "Promenade" (a street shares the name)
	# The demo answers two of the three Bürgeranliegen; a third planting tips it into gold.
	var demo_day_one := [["venue", "Lentos Kunstmuseum", "shuttle"], ["venue", "OK Platz", "shuttle"],
		["street", "Hauptplatz", "carfree"], fair]
	# Day 2 is the first incident day: the demo answers it with security at the two busiest venues.
	var demo_day_two := [fair, ["toilet", "Stadtpark Huemerstraße", "relocate"], ["toilet", "Promenade", "close"],
		["venue", "Ars Electronica Center", "security"], ["venue", "OK Platz", "security"]]
	var routes := {
		"DEMO -> Volksnahe Stadtplanung": [demo_day_one, demo_day_two,
			[fair, tree, ["venue", "Ars Electronica Center", "plant"], ["venue", "Ars Electronica Center", "plant"]]],
		"SHOWCASE -> Goldene:r Bürgermeister:in": [demo_day_one, demo_day_two,
			[fair, tree, ["venue", "Ars Electronica Center", "plant"], ["venue", "Ars Electronica Center", "plant"],
			["venue", "Ars Electronica Center", "extend"]]],
		"Effizienz-Tyrann:in": [[], [], [["tree", "baum_1b51840024c31e2584c5", "cut"], ["tree", "baum_22b431ea60149d6bee10", "cut"]]],
		"Beliebt, aber pleite": [[["venue", "splace", "shuttle"], ["venue", "Kunstuniversität Linz, Hauptplatz 6 (Ostgebäude)", "shuttle"],
			["venue", "JKU MED Campus (MED Campus I)", "shuttle"], ["venue", "Ars Electronica Center", "shuttle"],
			["venue", "Hauptplatz Linz", "shuttle"], ["venue", "Mariendom", "shuttle"]],
			[["toilet", "wc_m1", "relocate"], ["toilet", "wc_m2", "relocate"]], []],
		"Gastgeber:in der Stadt": [[["venue", "C. Bechstein Centrum Linz", "shuttle"], ["venue", "Kunstuniversität Linz, Hauptplatz 6 (Ostgebäude)", "shuttle"], fair], [fair], [fair]],
		"Solide Verwaltung": [[["venue", "splace", "shuttle"], fair], [fair], [fair]],
		"Stadt in Schieflage": [[["venue", "JKU MED Campus (MED Campus I)", "shuttle"], ["venue", "Ars Electronica Center", "shuttle"],
			["venue", "PopUp Store", "shuttle"], ["venue", "Kunstuniversität Linz, Hauptplatz 6 (Ostgebäude)", "shuttle"], ["venue", "splace", "shuttle"],
			["venue", "Hauptplatz Linz", "shuttle"], ["venue", "Mariendom", "shuttle"], ["venue", "Posthof – Zeitkultur am Hafen", "shuttle"]],
			[["toilet", "wc_m2", "relocate"], ["toilet", "wc_m3", "relocate"], ["toilet", "wc_m4", "relocate"], ["fountain", "brunnen_bop01", "relocate"]],
			[["tree", "baum_1b51840024c31e2584c5", "cut"], ["tree", "baum_22b431ea60149d6bee10", "cut"]]],
		"Stadt im Gleichgewicht": [[], [], [tree]],
	}
	for label: String in routes:
		var expected: String = label.get_slice(" -> ", 1) if label.contains(" -> ") else label
		var meters := _play_route(data, routes[label])
		var title := GS.verdict_title(meters)
		check(title == expected, "%s: expected %s, got %s (%.1f / %.1f / %.1f)" % [label, expected, title, meters.attendance, meters.money, meters.happiness])
