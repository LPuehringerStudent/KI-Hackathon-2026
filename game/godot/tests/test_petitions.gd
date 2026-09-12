extends "res://tests/base_test.gd"
## Bürgeranliegen: one petition per day, picked from the untouched city, fulfilled by real decisions.

const GS := preload("res://scripts/game_state.gd")

const LAT := 48.306
const LON := 14.284


## Big isolated venue "Posthof" (no neighbour, no toilet, no trees) and a small served venue.
func _data() -> Dictionary:
	return {
		"venues": [
			{ "id": "P", "name": "Posthof", "lat": LAT + 0.02, "lon": LON, "events": 11, "event_weight": 20 },
			{ "id": "H", "name": "Hauptplatz", "lat": LAT, "lon": LON, "events": 28, "event_weight": 10 },
		],
		"trees": [{ "id": "t1", "lat": LAT + 0.0002, "lon": LON, "species": "Tilia cordata", "height_m": 15.0, "crown_m": 14.0, "age_estimate": 80 }],
		"fountains": [{ "id": "f1", "name": "Brunnen", "lat": LAT + 0.0005, "lon": LON }],
		"toilets": [{ "id": "wc1", "name": "WC Hauptplatz", "lat": LAT, "lon": LON + 0.0007 }],
		"streets": [], "meta": {},
	}


func _on_day(day: int) -> Dictionary:
	var state: Dictionary = GS.create()
	for i in day - 1:
		GS.next_day(state)
	return state


func test_each_day_asks_the_venue_that_fails_its_theme() -> void:
	var data := _data()
	var expected := { 1: ["mobility", "P"], 2: ["sanitation", "P"], 3: ["shade", "P"] }
	for day: int in expected:
		var petition := GS.petition_for_day(_on_day(day), data, day)
		check(petition.kind == expected[day][0] and petition.venue_id == expected[day][1],
			"day %d should ask %s for %s, got %s/%s" % [day, expected[day][1], expected[day][0], petition.venue_id, petition.kind])
		check(not petition.fulfilled and petition.title.begins_with("Posthof") and not petition.ask.is_empty(), "open petition with text: %s" % petition)


func test_the_target_does_not_move_once_fulfilled() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	GS.decide(state, GS.find_entity(data, "P", "venue"), "shuttle")
	var petition := GS.petition_for_day(state, data, 1)
	check(petition.venue_id == "P" and petition.fulfilled, "same venue, now fulfilled: %s" % petition)


func test_fulfilment_per_kind() -> void:
	var data := _data()
	var shuttled: Dictionary = GS.create()
	GS.decide(shuttled, GS.find_entity(data, "P", "venue"), "shuttle")
	check(GS.petition_for_day(shuttled, data, 1).fulfilled, "a shuttle at the venue answers the mobility ask")
	var relocated := _on_day(2)
	GS.decide(relocated, GS.find_entity(data, "wc1", "toilet"), "relocate")
	check(GS.petition_for_day(relocated, data, 2).fulfilled, "the relocated toilet moves to the venue without one")
	var planted := _on_day(3)
	check(not GS.petition_for_day(planted, data, 3).fulfilled, "no shade yet")
	for i in 2:
		GS.decide(planted, GS.find_entity(data, "P", "venue"), "plant")
	check(GS.petition_for_day(planted, data, 3).fulfilled, "2 x %d m crown reaches the %d m target" % [GS.PLANTED_CROWN_M, GS.PETITION_SHADE_TARGET_M])


func test_reward_counts_once_per_petition_and_only_up_to_today() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var shuttled: Dictionary = GS.create()
	GS.decide(shuttled, GS.find_entity(data, "P", "venue"), "shuttle")
	check(is_equal_approx(GS.compute_meters(shuttled, data).happiness - fresh.happiness, GS.PETITION_REWARD),
		"one fulfilled petition pays PETITION_REWARD once (a shuttle changes no other happiness term)")
	# Planting on day 1 already satisfies the day-3 ask, but it only pays from day 3 on. Compare with a
	# control that plants the same trees, so shade and greening cancel out.
	var control: Dictionary = GS.create()
	var both: Dictionary = GS.create()
	GS.decide(both, GS.find_entity(data, "P", "venue"), "shuttle")
	for i in 2:
		GS.decide(control, GS.find_entity(data, "P", "venue"), "plant")
		GS.decide(both, GS.find_entity(data, "P", "venue"), "plant")
	check(is_equal_approx(GS.compute_meters(both, data).happiness - GS.compute_meters(control, data).happiness, GS.PETITION_REWARD),
		"on day 1 only the mobility petition pays")
	for state: Dictionary in [control, both]:
		GS.next_day(state)
		GS.next_day(state)
	check(is_equal_approx(GS.compute_meters(control, data).happiness - GS.compute_meters(GS.create(), data).happiness,
		GS.PETITION_REWARD + 2.0 * GS.PLANT_GREENING_BONUS + GS.SHADE_WEIGHT * 2.0 * GS.PLANTED_CROWN_M / GS.SHADE_FULL_CROWN_M),
		"on day 3 the plantings also pay the shade petition")
	check(is_equal_approx(GS.compute_meters(both, data).happiness - GS.compute_meters(control, data).happiness, GS.PETITION_REWARD),
		"and the mobility petition still pays exactly once")


func test_petitions_until_lists_newest_first() -> void:
	var data := _data()
	var list := GS.petitions_until(_on_day(3), data, 3)
	check(list.size() == 3 and list[0].day == 3 and list[2].day == 1, "three petitions, newest first: %s" % [list.map(func(p): return p.day)])
	check(GS.petitions_until(GS.create(), data, 1).size() == 1, "day 1 knows only its own")


func test_no_petition_when_every_venue_is_served() -> void:
	var data := _data()
	data.venues = [data.venues[1]]  # Hauptplatz only: clustered? no, but it has a toilet and a tree
	data.venues.append({ "id": "H2", "name": "Nachbar", "lat": LAT + 0.0005, "lon": LON + 0.0005, "events": 5, "event_weight": 5 })
	data.toilets.append({ "id": "wc2", "lat": LAT + 0.0005, "lon": LON + 0.0005 })
	check(GS.petition_for_day(GS.create(), data, 1).is_empty(), "both venues have a neighbour -> no mobility ask")
	check(GS.petition_for_day(GS.create(), data, 2).is_empty(), "both venues have a toilet -> no sanitation ask")
