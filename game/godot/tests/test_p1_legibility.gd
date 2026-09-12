extends "res://tests/base_test.gd"
## Round 7 P1: impact previews, decision audit (no free no-ops), planting, verdict subtitle.

const GS := preload("res://scripts/game_state.gd")

const LAT := 48.306
const LON := 14.284


## Headline venue H ("Hauptplatz", events 40) with a lime tree 20 m away, a fountain and two toilets
## next to it, a street 75 m away, and a far, unserviced venue P (so relocating a toilet has a target).
func _data() -> Dictionary:
	return {
		"venues": [
			{ "id": "H", "name": "Hauptplatz", "lat": LAT, "lon": LON, "events": 40, "event_weight": 20 },
			{ "id": "P", "name": "Posthof", "lat": LAT + 0.009, "lon": LON, "events": 8, "event_weight": 10 },
		],
		"trees": [
			{ "id": "t1", "lat": LAT + 0.00018, "lon": LON, "species": "Tilia cordata", "height_m": 15.0, "crown_m": 12.0, "age_estimate": 80 },
			{ "id": "t9", "lat": LAT - 0.02, "lon": LON, "species": "Quercus robur", "height_m": 20.0, "crown_m": 14.0, "age_estimate": 120 },
		],
		"fountains": [{ "id": "f1", "name": "Brunnen", "lat": LAT + 0.0005, "lon": LON }],
		"toilets": [
			{ "id": "wc1", "name": "WC Hauptplatz", "lat": LAT, "lon": LON + 0.0007 },
			{ "id": "wc2", "name": "WC Rathaus", "lat": LAT, "lon": LON - 0.0007 },
		],
		"streets": [{ "id": "s1", "name": "Landstraße", "history": "", "lat": LAT, "lon": LON + 0.001 }],
		"meta": {},
	}


func _entity(id: String, type: String) -> Dictionary:
	return GS.find_entity(_data(), id, type)


func _ids(decisions: Array) -> Array:
	return decisions.map(func(d): return d.id)


func test_no_keep_and_no_listen_bonus_left() -> void:
	for type: String in GS.DECISIONS:
		for decision: Dictionary in GS.DECISIONS[type]:
			check(decision.id != "keep", "%s still offers keep" % type)
	var script: Script = load("res://scripts/game_state.gd")
	var constants: Dictionary = script.get_script_constant_map()
	check(not constants.has("LISTEN_BONUS") and not constants.has("LISTEN_BONUS_MAX"), "LISTEN_BONUS is gone")


func test_reverts_are_offered_only_when_relevant() -> void:
	var state: Dictionary = GS.create()
	var toilet := _entity("wc1", "toilet")
	check("reopen" not in _ids(GS.available_decisions(toilet, state)), "no reopen while open")
	GS.decide(state, toilet, "close")
	check("reopen" in _ids(GS.available_decisions(toilet, state)), "reopen once closed")
	var street := _entity("s1", "street")
	check("open" not in _ids(GS.available_decisions(street, state)), "no open while open")
	GS.decide(state, street, "carfree")
	check("open" in _ids(GS.available_decisions(street, state)), "open once pedestrian")
	var venue := _entity("H", "venue")
	check("curfew" not in _ids(GS.available_decisions(venue, state)), "no curfew revert before extending")
	GS.decide(state, venue, "extend")
	check("curfew" in _ids(GS.available_decisions(venue, state)), "curfew revert once extended")
	check(not GS.decide(GS.create(), street, "open"), "decide enforces requires too")


func test_every_option_trades_something() -> void:
	# Each available option (reverts in their relevant state) must have a gain and a cost among
	# attendance, happiness, money meter and budget.
	var cases := [
		[GS.create(), _entity("t1", "tree")],
		[GS.create(), _entity("wc1", "toilet")],
		[GS.create(), _entity("H", "venue")],
		[GS.create(), _entity("s1", "street")],
		[GS.create(), GS.find_entity(_data(), "festival", "festival")],
	]
	var closed: Dictionary = GS.create()
	GS.decide(closed, _entity("wc1", "toilet"), "close")
	cases.append([closed, _entity("wc1", "toilet")])
	var pedestrian: Dictionary = GS.create()
	GS.decide(pedestrian, _entity("s1", "street"), "carfree")
	cases.append([pedestrian, _entity("s1", "street")])
	var extended: Dictionary = GS.create()
	GS.decide(extended, _entity("H", "venue"), "extend")
	cases.append([extended, _entity("H", "venue")])
	var premium_today: Dictionary = GS.create()
	GS.decide(premium_today, GS.find_entity(_data(), "festival", "festival"), "premium")
	cases.append([premium_today, GS.find_entity(_data(), "festival", "festival")])
	for pair: Array in cases:
		var previews := GS.preview_decisions(pair[0], _data(), pair[1])
		for id: String in previews:
			var deltas: Dictionary = previews[id]
			if deltas.is_empty():
				continue  # e.g. standard pricing while standard is already in effect
			var values: Array = [deltas.attendance, deltas.happiness, deltas.budget, deltas.money if is_zero_approx(deltas.budget) else 0.0]
			var gains: Array = values.filter(func(v): return v > 0.0)
			var losses: Array = values.filter(func(v): return v < 0.0)
			check(not gains.is_empty() and not losses.is_empty(), "%s:%s must trade something: %s" % [pair[1].type, id, deltas])


func test_preview_directions_and_purity() -> void:
	var state: Dictionary = GS.create()
	var before := state.duplicate(true)
	var cut := GS.preview_decision(state, _data(), _entity("t1", "tree"), "cut")
	check(cut.happiness < 0.0 and cut.budget == -400.0 and cut.attendance > 0.0, "cut at a venue: less happiness, cleared room, -400: %s" % cut)
	var shuttle := GS.preview_decision(state, _data(), _entity("P", "venue"), "shuttle")
	check(shuttle.attendance > 0.0 and shuttle.budget == -1800.0, "shuttle: more visitors, -1800: %s" % shuttle)
	var plant := GS.preview_decision(state, _data(), _entity("H", "venue"), "plant")
	check(plant.happiness > 0.0 and plant.budget == -300.0, "plant: happier, -300: %s" % plant)
	check(state == before, "previews never modify the state")
	check(GS.preview_decision(state, _data(), _entity("wc1", "toilet"), "reopen").is_empty(), "impossible decision -> {}")
	var all := GS.preview_decisions(state, _data(), _entity("H", "venue"))
	check(all.keys() == ["shuttle", "extend", "foodtruck", "security", "plant"], "one preview per available decision: %s" % [all.keys()])
	check(all.plant == plant, "batch preview equals single preview")


func test_preview_text_format() -> void:
	check(GS.preview_text({ "attendance": 0.0, "money": -3.2, "happiness": 2.4, "budget": -800.0 }) == "≈ +2.4 Zuf · −800 €", "relocate chip")
	check(GS.preview_text({ "attendance": 3.4, "money": -5.3, "happiness": 0.0, "budget": -1800.0 }) == "≈ +3.4 Bes · −1.800 €", "shuttle chip, thousands separator")
	check(GS.preview_text({ "attendance": 0.4, "money": 0.0, "happiness": -9.7, "budget": -400.0 }) == "≈ −9.7 Zuf · −400 €", "attendance below 0.5 hidden")
	check(GS.preview_text({ "attendance": -5.4, "money": 8.3, "happiness": 0.0, "budget": 0.0 }) == "≈ −5.4 Bes · +8.3 Geld", "pricing shows the money meter")
	check(GS.preview_text({ "attendance": 0.0, "money": 1.0, "happiness": -2.4, "budget": 300.0 }) == "≈ −2.4 Zuf · +300 €", "refund shows plus")
	check(GS.preview_text({}) == "", "no preview -> empty")


func test_planting_is_capped_and_positioned() -> void:
	var state: Dictionary = GS.create()
	var venue := _entity("H", "venue")
	var accepted := 0
	for i in 5:
		if GS.decide(state, venue, "plant"):
			accepted += 1
	check(accepted == 3, "max 3 trees per entity, got %d" % accepted)
	check(state.planted_trees.size() == 3, "state.planted_trees has one entry per tree")
	var positions := {}
	for tree: Dictionary in state.planted_trees:
		var distance: float = GS._distance_m(LAT, LON, tree.lat, tree.lon)
		check(absf(distance - GS.PLANT_OFFSET_M) < 1.0, "planted ~%d m from the venue, got %.1f" % [GS.PLANT_OFFSET_M, distance])
		check(tree.crown_m == GS.PLANTED_CROWN_M and tree.age == 0, "young tree record: %s" % tree)
		positions["%.6f,%.6f" % [tree.lat, tree.lon]] = true
	check(positions.size() == 3, "three distinct spots")
	check(GS._planted_trees(state, _data()) == state.planted_trees, "scoring derives the same trees from the log")
	check(GS.decide(state, _entity("s1", "street"), "plant"), "streets have their own cap")


func test_planted_tree_raises_shade_and_greening() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	GS.decide(state, _entity("H", "venue"), "plant")
	var venues: Array = data.venues
	check(GS._shade_score(venues, data.trees, {}, GS._planted_trees(state, data)) > GS._shade_score(venues, data.trees, {}), "planted tree adds shade near the venue")
	var expected: float = GS.PLANT_GREENING_BONUS + GS.SHADE_WEIGHT * GS.PLANTED_CROWN_M / GS.SHADE_FULL_CROWN_M
	check(is_equal_approx(GS.compute_meters(state, data).happiness - fresh.happiness, expected), "greening + young shade: expected %+.2f" % expected)


func test_cut_at_a_venue_stings_but_clears_room() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	GS.decide(state, _entity("t1", "tree"), "cut")
	var m: Dictionary = GS.compute_meters(state, data)
	check(fresh.happiness - m.happiness >= GS.CUT_PENALTY + GS.CUT_NEAR_VENUE_PENALTY, "near-venue cut costs at least %.0f happiness" % (GS.CUT_PENALTY + GS.CUT_NEAR_VENUE_PENALTY))
	check(m.attendance > fresh.attendance, "but clears room for visitors")


func test_consult_records_each_entity_once() -> void:
	var state: Dictionary = GS.create()
	check(state.consulted == [], "create() starts with no consultations")
	GS.consult(state, _entity("t1", "tree"))
	GS.consult(state, _entity("t1", "tree"))
	GS.consult(state, _entity("H", "venue"))
	check(state.consulted == ["tree:t1", "venue:H"], "unique keys in order: %s" % [state.consulted])
	GS.consult(state, {})
	check(state.consulted.size() == 2, "entities without id/type are ignored")


func test_verdict_subtitle_tells_the_story() -> void:
	var data := _data()
	check(GS.verdict_subtitle(GS.create(), data) == "Die Stadt blieb, wie sie war.", "nothing happened")
	var spared: Dictionary = GS.create()
	GS.consult(spared, _entity("t1", "tree"))
	check(GS.verdict_subtitle(spared, data) == "Die Linde nahe Hauptplatz durfte bleiben.", "talked to the lime tree, kept it: %s" % GS.verdict_subtitle(spared, data))
	var felled: Dictionary = spared.duplicate(true)
	GS.decide(felled, _entity("t1", "tree"), "cut")
	check(GS.verdict_subtitle(felled, data) == "Die Linde nahe Hauptplatz wurde gefällt.", "felled: %s" % GS.verdict_subtitle(felled, data))
	var far: Dictionary = GS.create()
	GS.consult(far, _entity("t9", "tree"))
	check(GS.verdict_subtitle(far, data) == "Die Eiche durfte bleiben.", "no venue within 300 m -> no place name: %s" % GS.verdict_subtitle(far, data))
	var busy: Dictionary = spared.duplicate(true)
	GS.decide(busy, _entity("H", "venue"), "plant")
	GS.decide(busy, _entity("H", "venue"), "plant")
	GS.decide(busy, _entity("H", "venue"), "foodtruck")
	GS.decide(busy, _entity("H", "venue"), "security")
	GS.decide(busy, _entity("P", "venue"), "shuttle")
	var lines: PackedStringArray = GS.verdict_subtitle(busy, data).split("\n")
	check(lines.size() == GS.SUBTITLE_MAX_LINES, "capped at %d lines: %s" % [GS.SUBTITLE_MAX_LINES, lines])
	check(lines[0] == "Die Linde nahe Hauptplatz durfte bleiben." and lines[1] == "2 neue Bäume wurden gepflanzt." and lines[2] == "1 Foodtruck und 1 Security-Team am Hauptplatz.", "story order: %s" % lines)
	var priced: Dictionary = GS.create()
	GS.next_day(priced)
	GS.next_day(priced)
	GS.decide(priced, GS.find_entity(data, "festival", "festival"), "premium")
	check(GS.verdict_subtitle(priced, data) == "Am Hitzetag galten Premiumpreise.", "Hitzetag pricing line")
