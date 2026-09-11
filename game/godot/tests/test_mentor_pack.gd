extends "res://tests/base_test.gd"
## GameState: Round 6 mentor pack — food trucks & security, curfew, pricing.
## Expectations are derived from the named constants, so tuning them keeps these tests meaningful.

const GS := preload("res://scripts/game_state.gd")

const LAT := 48.306
const LON := 14.284


## Headline venue H (events 40, weight 20 -> demand 4 units) and a small venue S ~1 km away, each
## with a fountain and toilet next door (happiness 10 + 25 + 25 = 60 before mentor-pack terms, so
## penalties never hit the 0 clamp).
func _data() -> Dictionary:
	return {
		"venues": [
			{ "id": "H", "name": "Ars Electronica Center", "lat": LAT, "lon": LON, "events": 40, "event_weight": 20 },
			{ "id": "S", "name": "Atelierhaus", "lat": LAT + 0.009, "lon": LON, "events": 10, "event_weight": 10 },
		],
		"trees": [],
		"fountains": [{ "id": "fH", "lat": LAT + 0.0005, "lon": LON }, { "id": "fS", "lat": LAT + 0.0095, "lon": LON }],
		"toilets": [{ "id": "wH", "lat": LAT, "lon": LON + 0.0007 }, { "id": "wS", "lat": LAT + 0.009, "lon": LON + 0.0007 }],
		"streets": [], "meta": {},
	}


func _entity(id: String, type := "venue") -> Dictionary:
	return GS.find_entity(_data(), id, type)


func _ids(decisions: Array) -> Array:
	return decisions.map(func(d): return d.id)


func _buy(state: Dictionary, id: String, decision_id: String, times: int) -> int:
	var accepted := 0
	for i in times:
		if GS.decide(state, _entity(id), decision_id):
			accepted += 1
	return accepted


func _meters(state: Dictionary) -> Dictionary:
	return GS.compute_meters(state, _data())


func test_catalogue_offers_purchases_only_at_headline_venues() -> void:
	check(_ids(GS.available_decisions(_entity("H"))) == ["shuttle", "extend", "foodtruck", "security", "plant"],
		"headline venue decisions: %s" % [_ids(GS.available_decisions(_entity("H")))])
	check(_ids(GS.available_decisions(_entity("S"))) == ["shuttle", "extend", "plant"],
		"small venue decisions: %s" % [_ids(GS.available_decisions(_entity("S")))])
	for d: Dictionary in GS.available_decisions(_entity("H")):
		check(d.has("group"), "%s needs a group" % d.id)
	var truck: Dictionary = GS.available_decisions(_entity("H")).filter(func(d): return d.id == "foodtruck")[0]
	check(truck.get("repeatable") == true and truck.cost == 500.0, "foodtruck: repeatable, 500 EUR")


func test_festival_pseudo_entity() -> void:
	var festival := GS.find_entity(_data(), "festival", "festival")
	check(festival.get("id") == "festival" and festival.get("type") == "festival" and festival.get("name") == "Festivalzentrale",
		"festival entity: %s" % festival)
	check(_ids(GS.available_decisions(festival)) == ["fair", "standard", "premium"], "pricing decisions")


func test_purchases_are_repeatable_up_to_the_limit() -> void:
	var state: Dictionary = GS.create()
	check(state.get("purchases") == {}, "create() starts with no purchases")
	var accepted := _buy(state, "H", "foodtruck", GS.MAX_PURCHASES_PER_VENUE + 2)
	check(accepted == GS.MAX_PURCHASES_PER_VENUE, "only %d trucks per venue, got %d" % [GS.MAX_PURCHASES_PER_VENUE, accepted])
	check(state.purchases.get("H", {}).get("foodtruck") == GS.MAX_PURCHASES_PER_VENUE, "state.purchases tracks the count: %s" % state.purchases)
	check(state.decisions.size() == GS.MAX_PURCHASES_PER_VENUE, "one decision record per purchase")
	check(is_equal_approx(state.budget, GS.CONFIG.start_budget - 500.0 * GS.MAX_PURCHASES_PER_VENUE), "each truck is paid, budget %s" % state.budget)
	check(_buy(state, "S", "foodtruck", 1) == 0, "no food trucks at non-headline venues")


func test_purchases_do_not_collapse_other_decision_groups() -> void:
	var state: Dictionary = GS.create()
	check(GS.decide(state, _entity("H"), "shuttle"), "shuttle")
	check(_buy(state, "H", "security", 2) == 2, "two security teams")
	check(GS.decide(state, _entity("H"), "extend"), "extend opening hours")
	check(not GS.decide(state, _entity("H"), "shuttle"), "shuttle still in effect after other groups")
	check(not GS.decide(state, _entity("H"), "extend"), "extend still in effect after purchases")
	check(state.purchases.H.security == 2 and state.shuttles.size() == 1, "purchases and shuttle both kept")


func test_food_trucks_fill_the_shortfall() -> void:
	var fresh := _meters(GS.create())
	var stocked: Dictionary = GS.create()
	_buy(stocked, "H", "foodtruck", 4 - GS.BASELINE_UNITS_PER_VENUE)  # demand ceil(20 / 5) = 4
	var m := _meters(stocked)
	check(is_equal_approx(m.happiness - fresh.happiness, GS.FOOD_HAPPINESS_CAP * _fresh_share()),
		"full food coverage removes the food penalty: %+.2f" % (m.happiness - fresh.happiness))
	# attendance = reach_part * food_factor - security penalty; reach_part is unchanged
	var fresh_food := lerpf(GS.FOOD_ATTENDANCE_MAX, GS.FOOD_ATTENDANCE_MIN, _fresh_share())
	var reach_part: float = (fresh.attendance + GS.SECURITY_ATTENDANCE_CAP * _fresh_share()) / fresh_food
	check(is_equal_approx(m.attendance, reach_part * GS.FOOD_ATTENDANCE_MAX - GS.SECURITY_ATTENDANCE_CAP * _fresh_share()),
		"food factor goes up to MAX: %.2f -> %.2f" % [fresh.attendance, m.attendance])


func test_partial_and_excess_purchases() -> void:
	var fresh := _meters(GS.create())
	var one: Dictionary = GS.create()
	_buy(one, "H", "security", 1)
	check(is_equal_approx(_meters(one).happiness - fresh.happiness, GS.SECURITY_HAPPINESS_CAP / 4.0), "each of the 4 demanded units is worth a quarter of the cap")
	var full: Dictionary = GS.create()
	_buy(full, "H", "security", 4 - GS.BASELINE_UNITS_PER_VENUE)
	var excess: Dictionary = GS.create()
	_buy(excess, "H", "security", 4 - GS.BASELINE_UNITS_PER_VENUE + 1)
	check(is_equal_approx(_meters(excess).happiness, _meters(full).happiness), "a unit beyond demand adds nothing but cost")
	check(_meters(excess).money < _meters(full).money, "excess still costs money")
	check(is_equal_approx(_meters(full).attendance - fresh.attendance, GS.SECURITY_ATTENDANCE_CAP * _fresh_share()), "full security removes the incident attendance penalty")


## Shortfall share of H before any purchase: (demand 4 - baseline) / 4.
func _fresh_share() -> float:
	return (4.0 - GS.BASELINE_UNITS_PER_VENUE) / 4.0


func test_curfew_extension_trades_happiness_for_attendance() -> void:
	var fresh := _meters(GS.create())
	var state: Dictionary = GS.create()
	check(GS.decide(state, _entity("H"), "extend"), "extend")
	var extended := _meters(state)
	check(is_equal_approx(fresh.happiness - extended.happiness, GS.CURFEW_HAPPINESS_PENALTY), "one extension costs CURFEW_HAPPINESS_PENALTY")
	check(extended.attendance > fresh.attendance, "extension raises attendance: %.2f -> %.2f" % [fresh.attendance, extended.attendance])
	check(GS.decide(state, _entity("H"), "curfew"), "back to the normal curfew")
	check(is_equal_approx(_meters(state).happiness, fresh.happiness) and is_equal_approx(_meters(state).attendance, fresh.attendance), "reverting restores the meters")


func test_curfew_penalty_is_capped_and_needs_real_venues() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	for i in 6:
		data.venues.append({ "id": "v%d" % i, "name": "Bühne %d" % i, "lat": LAT - 0.002 * i, "lon": LON + 0.01, "events": 5, "event_weight": 5 })
		data.fountains.append({ "id": "fv%d" % i, "lat": LAT - 0.002 * i, "lon": LON + 0.01 })  # keep coverage full,
		data.toilets.append({ "id": "wv%d" % i, "lat": LAT - 0.002 * i, "lon": LON + 0.01 })    # away from the 0 clamp
		check(GS.decide(state, GS.find_entity(data, "v%d" % i, "venue"), "extend"), "extend v%d" % i)
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	check(is_equal_approx(fresh.happiness - GS.compute_meters(state, data).happiness, GS.CURFEW_HAPPINESS_CAP), "curfew penalty capped")
	var ghost: Dictionary = GS.create()
	ghost.decisions.append({ "entity_id": "nowhere", "entity_type": "venue", "decision_id": "extend", "day": 1, "cost": 600.0 })
	check(is_equal_approx(GS.compute_meters(ghost, data).happiness, fresh.happiness), "extensions at unknown venues have no effect")


func test_pricing_applies_per_day_and_averages_over_the_festival() -> void:
	var festival := GS.find_entity(_data(), "festival", "festival")
	var fresh := _meters(GS.create())
	var fair: Dictionary = GS.create()
	check(GS.decide(fair, festival, "fair"), "fair pricing")
	check(is_equal_approx(_meters(fair).attendance, fresh.attendance * (1.0 + GS.PRICING.fair.attendance)), "fair raises attendance on day 1")
	check(GS.decide(fair, festival, "premium"), "switch to premium on the same day")
	check(not GS.decide(fair, festival, "premium"), "premium already in effect today")
	check(is_equal_approx(_meters(fair).attendance, fresh.attendance * (1.0 + GS.PRICING.premium.attendance)), "latest choice of the day wins")
	GS.next_day(fair)
	# Day 2 has no choice yet (standard): the festival average is (premium + standard) / 2.
	var mixed_factor: float = 1.0 + (GS.PRICING.premium.attendance + GS.PRICING.standard.attendance) / 2.0
	check(is_equal_approx(_meters(fair).attendance, fresh.attendance * mixed_factor), "unset day counts as standard in the average")
	check(GS.decide(fair, festival, "premium"), "premium on day 2 is a new choice for that day")
	check(is_equal_approx(_meters(fair).attendance, fresh.attendance * (1.0 + GS.PRICING.premium.attendance)), "premium on both days")


func test_pricing_scales_the_money_meter() -> void:
	var festival := GS.find_entity(_data(), "festival", "festival")
	var state: Dictionary = GS.create()
	GS.decide(state, festival, "premium")
	var m := _meters(state)
	var income: float = m.attendance / 100.0 * GS.MAX_VISITOR_INCOME * GS.CONFIG.visitor_spend / GS.REFERENCE_SPEND
	var expected: float = 100.0 * (GS.CONFIG.start_budget + income) / (GS.CONFIG.start_budget + GS.MAX_VISITOR_INCOME) * GS.PRICING.premium.money
	check(is_equal_approx(m.money, clampf(expected, 0.0, 100.0)), "premium scales the money meter: expected %.2f, got %.2f" % [expected, m.money])
	check(m.money > _meters(GS.create()).money and m.attendance < _meters(GS.create()).attendance, "premium: more money, fewer visitors")


func test_no_headline_venues_means_no_food_or_security_effect() -> void:
	var data := _data()
	data.venues[0].events = 12  # nobody reaches HEADLINE_MIN_EVENTS
	var state: Dictionary = GS.create()
	var m: Dictionary = GS.compute_meters(state, data)
	# 1 isolated venue H (20) + S (10), both ISOLATED_REACH; happiness = base only
	check(is_equal_approx(m.attendance, 100.0 * GS.ISOLATED_REACH), "no food factor or security penalty without headline venues, got %s" % m.attendance)
	check(is_equal_approx(m.happiness, GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT), "no food/security happiness penalty, got %s" % m.happiness)


func test_purchase_counts_come_from_the_decision_log() -> void:
	var state: Dictionary = GS.create()
	for i in 4:
		state.decisions.append({ "entity_id": "H", "entity_type": "venue", "decision_id": "foodtruck", "day": 1, "cost": 500.0 })
	var bought: Dictionary = GS.create()
	_buy(bought, "H", "foodtruck", 4)
	check(is_equal_approx(_meters(state).happiness, _meters(bought).happiness), "log-only purchases score like decide() purchases")
	state.decisions.append({ "entity_id": "nowhere", "entity_type": "venue", "decision_id": "security", "day": 1, "cost": 400.0 })
	check(is_equal_approx(_meters(state).happiness, _meters(bought).happiness), "purchases at unknown venues are ignored for effects")


func test_pricing_for_day_and_stock_status_helpers() -> void:
	var festival := GS.find_entity(_data(), "festival", "festival")
	var state: Dictionary = GS.create()
	check(GS.pricing_for_day(state, 1) == "standard", "no choice -> standard")
	GS.decide(state, festival, "fair")
	GS.next_day(state)
	check(GS.pricing_for_day(state, 1) == "fair" and GS.pricing_for_day(state, 2) == "standard", "pricing is remembered per day")
	_buy(state, "H", "foodtruck", 1)
	var stock := GS.stock_status(state, _entity("H"))
	check(stock == { "foodtruck": 1, "security": 0, "demand": 4, "baseline": GS.BASELINE_UNITS_PER_VENUE }, "stock status for H: %s" % stock)
	check(GS.stock_status(state, _entity("S")).is_empty(), "no stock status for non-headline venues")
