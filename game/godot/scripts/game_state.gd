class_name GameState
extends RefCounted
## Pure game logic (no Nodes): game state and the three mayor meters.
## Contract: docs/superpowers/plans/2026-09-11-buergermeister-spiel-godot.md — Shared Interfaces.
##
## State:    { day: int, budget: float, decisions: Array, shuttles: Array, purchases: Dictionary,
##             planted_trees: Array, consulted: Array }
## Decision: { entity_id, entity_type, decision_id, day, cost }
## Shuttle:  { lat, lon }
## Purchases: { venue_id: { "foodtruck": n, "security": n } } — maintained by decide() for the UI;
##           scoring counts purchases from the decision log.
## Planted:  [{ id, lat, lon, crown_m, age }] — maintained by decide() for map_view (Track A renders
##           them); scoring derives the same trees from the decision log.
## Consulted: ["<type>:<id>", …] — entities the mayor opened a conversation with (verdict subtitle).
## Entity:   a Data record plus "type" ("venue" | "tree" | "fountain" | "toilet" | "street"),
##           as returned by find_entity() — the same type string map_view's entity_clicked emits —
##           or the synthesized pricing entity find_entity(data, "festival", "festival").

const CONFIG := { "start_budget": 14000.0, "visitor_spend": 35.0, "walk_radius": 300.0, "shuttle_radius": 250.0 }

const LAST_DAY := 3

const DAY_THEMES := {
	1: { "title": "Tag 1 — Anreise", "focus": "Mobilität", "hint": "Wo sollen Shuttle fahren?" },
	2: { "title": "Tag 2 — Höhepunkt", "focus": "Sanitär & Wasser", "hint": "Reichen Toiletten und Trinkbrunnen für den Andrang?" },
	3: { "title": "Tag 3 — Hitzetag", "focus": "Schatten & Bäume", "hint": "Welche Bäume spenden den Besucher:innen Schatten?" },
}

## Decision catalogue per entity type. ids are what dialogue.gd emits in [[ENTSCHEID:<id>]].
## "group": the latest decision per entity *and group* is in effect ("main" = the entity's own
## state, "pricing" is kept per day); "repeatable" decisions are counted purchases, never collapsed;
## "headline_only" decisions are offered only at venues with events >= HEADLINE_MIN_EVENTS;
## "requires" decisions (reverts) are offered only while that decision is in effect in their group;
## "max" caps repeatable decisions per entity. Every option trades something — no free no-ops.
const SERVICE_DECISIONS := [
	{ "id": "relocate", "label": "Verlegen", "cost": 800.0, "adds_shuttle": false, "group": "main" },
	# Closing saves operating costs (negative cost = refund) but costs coverage.
	{ "id": "close", "label": "Schließen", "cost": -300.0, "adds_shuttle": false, "group": "main" },
	{ "id": "reopen", "label": "Wieder öffnen", "cost": 100.0, "adds_shuttle": false, "group": "main", "requires": "close" },
]
const PLANT_DECISION := { "id": "plant", "label": "Baum pflanzen", "cost": 300.0, "adds_shuttle": false, "group": "planting",
	"repeatable": true, "max": 3 }
const DECISIONS := {
	"tree": [
		{ "id": "trim", "label": "Zurückschneiden", "cost": 150.0, "adds_shuttle": false, "group": "main" },
		{ "id": "cut", "label": "Fällen", "cost": 400.0, "adds_shuttle": false, "group": "main" },
	],
	"fountain": SERVICE_DECISIONS,
	"toilet": SERVICE_DECISIONS,
	"venue": [
		{ "id": "shuttle", "label": "Shuttle-Haltestelle einrichten", "cost": 1800.0, "adds_shuttle": true, "group": "shuttle" },
		{ "id": "extend", "label": "Sperrstunde verlängern", "cost": 600.0, "adds_shuttle": false, "group": "curfew" },
		{ "id": "curfew", "label": "Sperrstunde einhalten", "cost": 0.0, "adds_shuttle": false, "group": "curfew", "requires": "extend" },
		{ "id": "foodtruck", "label": "Foodtruck bestellen", "cost": 500.0, "adds_shuttle": false, "group": "purchase",
			"repeatable": true, "headline_only": true, "max": 5 },
		{ "id": "security", "label": "Security-Team buchen", "cost": 400.0, "adds_shuttle": false, "group": "purchase",
			"repeatable": true, "headline_only": true, "max": 5 },
		PLANT_DECISION,
	],
	"street": [
		{ "id": "pedestrian", "label": "Für Fußgänger sperren", "cost": 300.0, "adds_shuttle": false, "group": "main" },
		{ "id": "open", "label": "Freigeben", "cost": 50.0, "adds_shuttle": false, "group": "main", "requires": "pedestrian" },
		PLANT_DECISION,
	],
	"festival": [
		{ "id": "fair", "label": "Faire Preise", "cost": 0.0, "adds_shuttle": false, "group": "pricing" },
		{ "id": "standard", "label": "Standardpreise", "cost": 0.0, "adds_shuttle": false, "group": "pricing" },
		{ "id": "premium", "label": "Premiumpreise", "cost": 0.0, "adds_shuttle": false, "group": "pricing" },
	],
}
const FESTIVAL_ENTITY := { "id": "festival", "name": "Festivalzentrale", "type": "festival" }

## Tuning constants — balanced against the real Innenstadt extract (20 venues, 400 trees,
## 38 fountains, 41 toilets) so every decision moves a meter without cliffs, and against
## main.gd's verdict thresholds (> 66 / < 50): an untouched city ends "Stadt im Gleichgewicht"
## on day 3 at any air quality, and "Volksnahe Stadtplanung" needs several mixed decisions
## (simulated with the mentor pack: 4 with clean air, 6 at neutral air — incl. a food truck).

## Visitor income at 100 % attendance and the reference spend of 35 € per visitor.
const MAX_VISITOR_INCOME := 12000.0
const REFERENCE_SPEND := 35.0
const EARTH_RADIUS_M := 6371000.0
## Lower bound for meters per degree of latitude (true value >= 110 574), so the _near_any box never
## rejects a pair that is actually within the radius.
const BOX_METERS_PER_DEG_LAT := 110000.0

## Happiness = base + weight × (0..1 component) per term, minus cut penalties.
const HAPPINESS_BASE := 25.0
const FOUNTAIN_WEIGHT := 25.0
const TOILET_WEIGHT := 25.0
const SHADE_WEIGHT := 20.0
const SHADE_RADIUS_M := 150.0
## Total crown diameter near venues that counts as full shade.
const SHADE_FULL_CROWN_M := 200.0
## A trimmed tree still gives this share of its shade.
const TRIM_SHADE_FACTOR := 0.5
## Every felled tree costs happiness; much more when it stood at a venue (last resort).
const CUT_PENALTY := 2.0
const CUT_NEAR_VENUE_PENALTY := 10.0
const CUT_PENALTY_RADIUS_M := 50.0
## Cutting / trimming a tree at a venue (within CUT_PENALTY_RADIUS_M) clears room for visitors:
## that venue's reach grows, capped per venue — the trade for the lost shade.
const CUT_CLEARING_REACH := 0.06
const TRIM_CLEARING_REACH := 0.02
const CLEARING_REACH_CAP := 0.12
## Planted trees: young crown for shade near venues plus visible greening anywhere (capped).
const PLANTED_CROWN_M := 6.0
const PLANT_GREENING_BONUS := 0.8
const PLANT_GREENING_CAP := 6.0
const PLANT_OFFSET_M := 25.0
## Every closed fountain/toilet is noticed, even where another one still covers the venue — so closing
## redundant services trades happiness for the refund instead of printing money. Below 1 so the
## worst single closure on the real extract (wc_m20, −6.1 coverage) stays under the 7.0 balance guard.
const CLOSED_SERVICE_PENALTY := 0.8
## A pedestrian zone draws visitors but diverts traffic: small happiness cost per street (capped).
const PEDESTRIAN_HAPPINESS_PENALTY := 1.0
const PEDESTRIAN_HAPPINESS_CAP := 4.0

## Attendance = event-weighted share of demand realised, by how well each venue is connected.
const SHUTTLE_REACH := 0.9
const CLUSTER_REACH := 0.62
const ISOLATED_REACH := 0.34
const VENUE_CLUSTER_RADIUS_M := 200.0
const PEDESTRIAN_REACH_BONUS := 0.15
const PEDESTRIAN_RADIUS_M := 250.0

## Hitzetag air quality (data.airquality, PM10 in µg/m³ from tools/fetch_airquality.py):
## <= AIR_CLEAN_PM10 gives +AIR_MODIFIER happiness, >= AIR_POLLUTED_PM10 gives -AIR_MODIFIER,
## linear in between. Only on AIR_QUALITY_DAY; missing or invalid readings count as 0.
const AIR_QUALITY_DAY := 3
const AIR_CLEAN_PM10 := 20.0
const AIR_POLLUTED_PM10 := 50.0
const AIR_MODIFIER := 10.0

## Bürgeranliegen: one petition per day, always aimed at the venue that currently fails the day's
## theme (picked from the untouched city, so the target never moves while you play). Fulfilling one
## — also later than its day — adds PETITION_REWARD happiness.
const PETITION_REWARD := 2.0
## Fulfilling a wish also unlocks a citizens' grant, so answering the city partly funds itself.
const PETITION_GRANT := 1000.0
## A venue counts as shaded once this much crown diameter stands within SHADE_RADIUS_M.
const PETITION_SHADE_TARGET_M := 12.0

## Verdict tiers on the final meters (0..100), checked in the order of verdict_title().
## Probe on the real extract: the best reachable weakest meter is ~68 (clean air), so a literal
## "all >= 80" gold tier would never show — gold is the best title plus a high average instead.
## With the Bürgeranliegen a good run averages low 70s, so gold moved 69 -> 72: the scripted demo
## fulfils two wishes (Volksnahe, avg ~71), and the third wish tips it into gold — one decision apart
## (see test_real_data_endings). "Every meter > 70" was tried and is unreachable: attendance and money
## trade off directly.
const VERDICT_HIGH := 66.0      # > : strong meter (existing endings)
const VERDICT_LOW := 50.0       # < : weak meter (existing endings)
const VERDICT_GOLD_AVERAGE := 72.0
const VERDICT_SOLID := 55.0     # >= on every meter
const VERDICT_CRISIS := 35.0    # < on any meter

## Mentor pack — food trucks & security at headline venues (events >= HEADLINE_MIN_EVENTS).
## Demand per venue = ceil(event_weight / PURCHASE_UNIT_EVENT_WEIGHT) units per kind, of which
## BASELINE_UNITS_PER_VENUE already exist (the city's usual vendors and stewards). The
## event-weighted shortfall share (0 = stocked, 1 = nothing at all) scales the effects.
const HEADLINE_MIN_EVENTS := 30
const PURCHASE_UNIT_EVENT_WEIGHT := 5.0
const BASELINE_UNITS_PER_VENUE := 2
const MAX_PURCHASES_PER_VENUE := 5  # food trucks / security; see "max" in the catalogue
const FOOD_ATTENDANCE_MIN := 0.85
const FOOD_ATTENDANCE_MAX := 1.05
const FOOD_HAPPINESS_CAP := 15.0
const SECURITY_HAPPINESS_CAP := 16.0
const SECURITY_ATTENDANCE_CAP := 10.0
## Curfew extension per venue: reach bonus for that venue, happiness penalty per venue (capped).
const CURFEW_REACH_BONUS := 0.25
const CURFEW_HAPPINESS_PENALTY := 3.0
const CURFEW_HAPPINESS_CAP := 12.0
## Pricing per day (unset day = standard), averaged over days 1..current: attendance x(1 + attendance),
## money meter x money. (Scaling only visitor income made premium strictly worse: 0.88 x 1.15 ~ 1.01.)
const PRICING := {
	"fair": { "attendance": 0.10, "money": 0.9 },
	"standard": { "attendance": 0.0, "money": 1.0 },
	"premium": { "attendance": -0.12, "money": 1.15 },
}


static func create() -> Dictionary:
	return { "day": 1, "budget": CONFIG.start_budget, "decisions": [], "shuttles": [], "purchases": {},
		"planted_trees": [], "consulted": [] }


## Copy of the Data record `id` in data["<type>s"] with "type" added, or {} if not found.
## Ids compare by string form, so a numeric JSON id 42 is found as "42".
static func find_entity(data: Dictionary, id: String, type: String) -> Dictionary:
	if type == "festival":
		return FESTIVAL_ENTITY.duplicate() if id == FESTIVAL_ENTITY.id else {}
	if not DECISIONS.has(type):
		return {}
	var records: Variant = data.get(type + "s")
	if not (records is Array):
		return {}
	for record: Variant in records:
		if record is Dictionary and record.has("id") and str(record.id) == id:
			var entity: Dictionary = record.duplicate(true)
			entity["type"] = type
			return entity
	return {}


## [{ id, label, cost, adds_shuttle, group, ... }] for the entity's type; [] for unknown or missing type.
## Every type is always available — the day focus only changes the hint. Headline-only purchases
## appear only for venues with events >= HEADLINE_MIN_EVENTS; "requires" reverts (reopen, open,
## curfew) only when `state` is given and the required decision is in effect.
static func available_decisions(entity: Dictionary, state: Dictionary = {}) -> Array:
	var headline := _is_headline(entity)
	var latest := _latest_decisions(state) if not state.is_empty() else {}
	return DECISIONS.get(entity.get("type", ""), []).filter(func(d):
		if d.get("headline_only", false) and not headline:
			return false
		if d.has("requires"):
			return latest.get(_slot_key(entity.get("type", ""), entity.get("id", ""), d.group, state.get("day", 1)), "") == d.requires
		if d.group == "pricing" and not state.is_empty():
			return pricing_for_day(state, int(state.get("day", 1))) != d.id
		return true).duplicate(true)


## Records the decision and spends its cost. An entity's latest decision per group is the one in
## effect (e.g. "reopen" undoes "close"); repeatable purchases are counted instead. Every
## decision's cost is spent.
## Returns false (state unchanged) if the decision isn't available for the entity, is already
## in effect for it (pricing: today), would exceed MAX_PURCHASES_PER_VENUE, the entity is a felled
## tree, or state/entity are malformed (no id, or no position for a shuttle) — everything is
## validated before the state is touched.
static func decide(state: Dictionary, entity: Dictionary, decision_id: String) -> bool:
	if not _is_valid_state(state) or not entity.has("id"):
		return false
	var matches := available_decisions(entity, state).filter(func(d): return d.id == decision_id)
	if matches.is_empty():
		return false
	var decision: Dictionary = matches[0]
	if (decision.adds_shuttle or decision.id == "plant") and not _has_position(entity):
		return false
	if decision.get("repeatable", false):
		var limit: int = decision.get("max", MAX_PURCHASES_PER_VENUE)
		if _purchase_counts(state).get(str(entity.id), {}).get(decision_id, 0) >= limit:
			return false
	else:
		var latest := _latest_decisions(state)
		if latest.get(_slot_key(entity.type, entity.id, decision.group, state.day), "") == decision_id:
			return false
		if latest.get(_key(entity.type, entity.id), "") == "cut":
			return false
	state.decisions.append({
		"entity_id": entity.id,
		"entity_type": entity.type,
		"decision_id": decision_id,
		"day": state.day,
		"cost": decision.cost,
	})
	state.budget -= decision.cost
	if decision.adds_shuttle:
		state.shuttles.append({ "lat": entity.lat, "lon": entity.lon })
	if decision.group == "purchase":
		if not (state.get("purchases") is Dictionary):
			state["purchases"] = {}
		var counts: Dictionary = state.purchases.get(str(entity.id), {})
		counts[decision_id] = int(counts.get(decision_id, 0)) + 1
		state.purchases[str(entity.id)] = counts
	elif decision.id == "plant":
		if not (state.get("planted_trees") is Array):
			state["planted_trees"] = []
		var index := int(_purchase_counts(state).get(str(entity.id), {}).get("plant", 1)) - 1
		state.planted_trees.append(_planted_tree(entity, index))
	return true


## Remembers that the mayor talked to `entity` (for the verdict subtitle). No meter effect.
static func consult(state: Dictionary, entity: Dictionary) -> void:
	if not entity.has("id") or not entity.has("type"):
		return
	if not (state.get("consulted") is Array):
		state["consulted"] = []
	var key := _key(entity.type, entity.id)
	if key not in state.consulted:
		state.consulted.append(key)


## What-if for one decision: meter and budget deltas (rounded to 0.1) if `decision_id` were taken
## now, or {} when it isn't possible. Pure — `state` is not modified.
static func preview_decision(state: Dictionary, data: Dictionary, entity: Dictionary, decision_id: String) -> Dictionary:
	return _preview_against(state, data, entity, decision_id, compute_meters(state, data))


## Previews for every decision currently available for `entity`: { decision_id: deltas }.
static func preview_decisions(state: Dictionary, data: Dictionary, entity: Dictionary) -> Dictionary:
	var before := compute_meters(state, data)
	var previews := {}
	for decision: Dictionary in available_decisions(entity, state):
		previews[decision.id] = _preview_against(state, data, entity, decision.id, before)
	return previews


static func _preview_against(state: Dictionary, data: Dictionary, entity: Dictionary, decision_id: String, before: Dictionary) -> Dictionary:
	if not _is_valid_state(state):
		return {}
	var simulated := state.duplicate(true)
	if not decide(simulated, entity, decision_id):
		return {}
	var after := compute_meters(simulated, data)
	return {
		"attendance": snappedf(after.attendance - before.attendance, 0.1),
		"money": snappedf(after.money - before.money, 0.1),
		"happiness": snappedf(after.happiness - before.happiness, 0.1),
		"budget": snappedf(float(simulated.budget) - float(state.budget), 0.1),
	}


## Chip line for a preview, e.g. "≈ +2.4 Zuf · −800 €". Attendance / money meter only when
## |delta| >= 0.5 (money meter only for decisions without a budget change, like pricing).
static func preview_text(deltas: Dictionary) -> String:
	if deltas.is_empty():
		return ""
	var parts: Array[String] = []
	if absf(float(deltas.get("happiness", 0.0))) >= 0.05:
		parts.append("%s Zuf" % _signed(float(deltas.happiness), 1))
	if absf(float(deltas.get("attendance", 0.0))) >= 0.5:
		parts.append("%s Bes" % _signed(float(deltas.attendance), 1))
	var budget := float(deltas.get("budget", 0.0))
	if is_zero_approx(budget) and absf(float(deltas.get("money", 0.0))) >= 0.5:
		parts.append("%s Geld" % _signed(float(deltas.money), 1))
	if not is_zero_approx(budget):
		parts.append("%s €" % _signed_euros(budget))
	return "≈ " + (" · ".join(parts) if not parts.is_empty() else "keine Wirkung")


static func _signed(value: float, decimals: int) -> String:
	var text := ("%." + str(decimals) + "f") % absf(value)
	return ("−" if value < 0.0 else "+") + text


static func _signed_euros(value: float) -> String:
	var digits := str(roundi(absf(value)))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("−" if value < 0.0 else "+") + digits + grouped


## No-op for a state without a numeric day.
static func next_day(state: Dictionary) -> void:
	if _is_number(state.get("day")):
		state.day = mini(LAST_DAY, int(state.day) + 1)


## { title, focus, hint } — days outside 1..LAST_DAY clamp to the nearest day.
static func day_theme(day: int) -> Dictionary:
	return DAY_THEMES[clampi(day, 1, LAST_DAY)].duplicate()


## Records without an id or a finite lat/lon (and venues without a numeric event_weight) are
## ignored, as are malformed decision records — bad data degrades the score, never corrupts it.
static func compute_meters(state: Dictionary, data: Dictionary) -> Dictionary:
	var venues := _scorable_venues(data)
	var trees := _records(data, "trees")
	var latest := _latest_decisions(state)
	var fountains := _effective_services(_records(data, "fountains"), "fountain", state, latest, venues)
	var toilets := _effective_services(_records(data, "toilets"), "toilet", state, latest, venues)
	var pedestrian_streets := _records(data, "streets").filter(
		func(s): return latest.get(_key("street", s.id)) == "pedestrian")

	var happiness := HAPPINESS_BASE
	happiness += FOUNTAIN_WEIGHT * _coverage_score(venues, fountains, CONFIG.walk_radius)
	happiness += TOILET_WEIGHT * _coverage_score(venues, toilets, CONFIG.walk_radius)
	var closed_services := 0
	for type: String in ["fountain", "toilet"]:
		closed_services += _records(data, type + "s").filter(func(r): return latest.get(_key(type, r.id)) == "close").size()
	happiness -= CLOSED_SERVICE_PENALTY * closed_services
	var planted := _planted_trees(state, data)
	happiness += SHADE_WEIGHT * _shade_score(venues, trees, latest, planted)
	happiness -= _cut_penalty(venues, trees, latest)
	happiness += minf(PLANT_GREENING_CAP, PLANT_GREENING_BONUS * planted.size())
	happiness -= minf(PEDESTRIAN_HAPPINESS_CAP, PEDESTRIAN_HAPPINESS_PENALTY * pedestrian_streets.size())
	happiness += air_quality_modifier(state, data)
	var fulfilled_petitions: int = petitions_until(state, data, int(state.get("day", 1)) if _is_number(state.get("day")) else 1).filter(
		func(p): return p.fulfilled).size()
	happiness += PETITION_REWARD * fulfilled_petitions

	var counts := _purchase_counts(state)
	var food_short := _stock_shortfall(venues, counts, "foodtruck")
	var security_short := _stock_shortfall(venues, counts, "security")
	happiness -= FOOD_HAPPINESS_CAP * maxf(food_short, 0.0)
	happiness -= SECURITY_HAPPINESS_CAP * maxf(security_short, 0.0)
	happiness -= _curfew_penalty(venues, latest)

	var food_factor := 1.0 if food_short < 0.0 else lerpf(FOOD_ATTENDANCE_MAX, FOOD_ATTENDANCE_MIN, food_short)
	var pricing := _pricing_factors(state, latest)
	var attendance := 100.0 * _reachability(state, venues, pedestrian_streets, latest, trees) * food_factor
	attendance -= SECURITY_ATTENDANCE_CAP * maxf(security_short, 0.0)
	attendance = clampf(attendance * pricing.attendance, 0.0, 100.0)

	return {
		"attendance": attendance,
		"money": clampf(_money_score(state, attendance, PETITION_GRANT * fulfilled_petitions) * pricing.money, 0.0, 100.0),
		"happiness": clampf(happiness, 0.0, 100.0),
	}


## The day's petition: { day, kind, title, ask, venue_id, venue_name, fulfilled } — {} when the data
## has no venue that fails this day's ask.
static func petition_for_day(state: Dictionary, data: Dictionary, day: int) -> Dictionary:
	var venues := _scorable_venues(data)
	var kind: String = ["mobility", "sanitation", "shade"][clampi(day, 1, LAST_DAY) - 1]
	var target := {}
	for venue: Dictionary in venues:
		if _petition_open_at(venue, venues, data, kind) and (target.is_empty() or float(venue.event_weight) > float(target.event_weight)):
			target = venue
	if target.is_empty():
		return {}
	var name := str(target.get("name", "diese Spielstätte"))
	# Case-neutral phrasing: venue names carry every gender ("das AEC", "die Kunstuniversität").
	var texts := {
		"mobility": ["%s: Wie kommen die Gäste her?" % name, "Eine Shuttle-Haltestelle in %d m Umkreis" % int(CONFIG.shuttle_radius)],
		"sanitation": ["%s: keine Toilette in Gehweite." % name, "Eine offene Toilette in %d m Umkreis" % int(CONFIG.walk_radius)],
		"shade": ["%s: kein Schatten für den Hitzetag." % name, "Mindestens %d m Krone in %d m Umkreis" % [int(PETITION_SHADE_TARGET_M), int(SHADE_RADIUS_M)]],
	}
	return {
		"day": clampi(day, 1, LAST_DAY), "kind": kind, "title": texts[kind][0], "ask": texts[kind][1],
		"venue_id": str(target.id), "venue_name": name,
		"fulfilled": _petition_fulfilled(target, venues, state, data, kind),
	}


## All petitions up to and including `day`, most recent first — for the day bar and the verdict.
static func petitions_until(state: Dictionary, data: Dictionary, day: int) -> Array:
	var list: Array = []
	for d in range(1, clampi(day, 1, LAST_DAY) + 1):
		var petition := petition_for_day(state, data, d)
		if not petition.is_empty():
			list.append(petition)
	list.reverse()
	return list


## True while the venue still fails the day's ask in the untouched city (petition selection).
static func _petition_open_at(venue: Dictionary, venues: Array, data: Dictionary, kind: String) -> bool:
	match kind:
		"mobility":
			return not _near_any(venue, venues, VENUE_CLUSTER_RADIUS_M)
		"sanitation":
			return not _near_any(venue, _records(data, "toilets"), CONFIG.walk_radius)
		"shade":
			return _crown_near(venue, _records(data, "trees"), {}, []) < PETITION_SHADE_TARGET_M
	return false


static func _petition_fulfilled(venue: Dictionary, venues: Array, state: Dictionary, data: Dictionary, kind: String) -> bool:
	var latest := _latest_decisions(state)
	match kind:
		"mobility":
			return _near_any(venue, _positions(state.get("shuttles")), CONFIG.shuttle_radius)
		"sanitation":
			var toilets := _effective_services(_records(data, "toilets"), "toilet", state, latest, venues)
			return _near_any(venue, toilets, CONFIG.walk_radius)
		"shade":
			return _crown_near(venue, _records(data, "trees"), latest, _planted_trees(state, data)) >= PETITION_SHADE_TARGET_M
	return false


## Crown diameter standing within SHADE_RADIUS_M of one venue (felled 0, trimmed halved, planted counted).
static func _crown_near(venue: Dictionary, trees: Array, latest: Dictionary, planted: Array) -> float:
	var crown := 0.0
	for tree: Dictionary in trees:
		if not _is_number(tree.get("crown_m")) or _distance_m(venue.lat, venue.lon, tree.lat, tree.lon) > SHADE_RADIUS_M:
			continue
		var decision: String = latest.get(_key("tree", tree.id), "")
		if decision == "cut":
			continue
		crown += float(tree.crown_m) * (TRIM_SHADE_FACTOR if decision == "trim" else 1.0)
	for young: Dictionary in planted:
		if _distance_m(venue.lat, venue.lon, young.lat, young.lon) <= SHADE_RADIUS_M:
			crown += float(young.crown_m)
	return crown


static func _scorable_venues(data: Dictionary) -> Array:
	return _records(data, "venues").filter(
		func(v): return _is_number(v.get("event_weight")) and float(v.event_weight) >= 0.0)


## German ending title for final meters { attendance, money, happiness } (missing meters count as 0).
static func verdict_title(meters: Dictionary) -> String:
	var attendance := float(meters.get("attendance", 0.0))
	var money := float(meters.get("money", 0.0))
	var happiness := float(meters.get("happiness", 0.0))
	var weakest := minf(attendance, minf(money, happiness))
	if weakest > VERDICT_HIGH and (attendance + money + happiness) / 3.0 >= VERDICT_GOLD_AVERAGE:
		return "Goldene:r Bürgermeister:in"
	if weakest > VERDICT_HIGH:
		return "Volksnahe Stadtplanung"
	if money > VERDICT_HIGH and happiness < VERDICT_LOW:
		return "Effizienz-Tyrann:in"
	if happiness > VERDICT_HIGH and money < VERDICT_LOW:
		return "Beliebt, aber pleite"
	if attendance > VERDICT_HIGH:
		return "Gastgeber:in der Stadt"
	if weakest < VERDICT_CRISIS:
		return "Stadt in Schieflage"
	if weakest >= VERDICT_SOLID:
		return "Solide Verwaltung"
	return "Stadt im Gleichgewicht"


## German tree names by genus: [name, article] for the verdict subtitle.
const TREE_NAMES := {
	"Platanus": ["Platane", "Die"], "Fagus": ["Buche", "Die"], "Tilia": ["Linde", "Die"],
	"Quercus": ["Eiche", "Die"], "Acer": ["Ahorn", "Der"], "Fraxinus": ["Esche", "Die"],
	"Aesculus": ["Rosskastanie", "Die"], "Gleditsia": ["Gleditschie", "Die"], "Populus": ["Pappel", "Die"],
	"Sophora": ["Schnurbaum", "Der"], "Pterocarya": ["Flügelnuss", "Die"], "Carpinus": ["Hainbuche", "Die"],
	"Betula": ["Birke", "Die"], "Ailanthus": ["Götterbaum", "Der"], "Paulownia": ["Blauglockenbaum", "Der"],
	"Prunus": ["Kirsche", "Die"], "Salix": ["Weide", "Die"], "Juglans": ["Walnuss", "Die"],
	"Pinus": ["Kiefer", "Die"], "Robinia": ["Robinie", "Die"], "Taxodium": ["Sumpfzypresse", "Die"],
	"Ginkgo": ["Ginkgo", "Der"], "Catalpa": ["Trompetenbaum", "Der"], "Castanea": ["Edelkastanie", "Die"],
	"Parrotia": ["Eisenholzbaum", "Der"],
}
const SUBTITLE_MAX_LINES := 3
const SUBTITLE_NEAR_VENUE_M := 300.0


## Up to SUBTITLE_MAX_LINES German sentences telling the story of this festival's decisions, most
## memorable first (trees, planting, purchases, shuttles, Hitzetag pricing, services), one per line.
static func verdict_subtitle(game: Dictionary, data: Dictionary) -> String:
	var latest := _latest_decisions(game)
	var lines: Array[String] = []
	var cut: Array = []
	var trimmed: Array = []
	for tree: Dictionary in _records(data, "trees"):
		match latest.get(_key("tree", tree.id), ""):
			"cut": cut.append(tree)
			"trim": trimmed.append(tree)
	if cut.size() == 1:
		lines.append("%s wurde gefällt." % _tree_phrase(cut[0], data))
	elif cut.size() > 1:
		lines.append("%d Bäume wurden gefällt." % cut.size())
	else:
		var spared := _last_consulted_tree(game, data, latest)
		if not spared.is_empty():
			var fate := "wurde nur zurückgeschnitten" if latest.get(_key("tree", spared.id), "") == "trim" else "durfte bleiben"
			lines.append("%s %s." % [_tree_phrase(spared, data), fate])
		elif trimmed.size() > 0:
			lines.append("%d Bäume wurden zurückgeschnitten." % trimmed.size() if trimmed.size() > 1 else "%s wurde zurückgeschnitten." % _tree_phrase(trimmed[0], data))
	var planted := _planted_trees(game, data).size()
	if planted > 0:
		lines.append("Ein neuer Baum wurde gepflanzt." if planted == 1 else "%d neue Bäume wurden gepflanzt." % planted)
	var purchase_line := _purchase_sentence(game, data)
	if not purchase_line.is_empty():
		lines.append(purchase_line)
	var shuttle_venues: Array = []
	for venue: Dictionary in _records(data, "venues"):
		if latest.get(_slot_key("venue", venue.id, "shuttle", 0), "") == "shuttle":
			shuttle_venues.append(str(venue.get("name", "")))
	if shuttle_venues.size() == 1:
		lines.append("Ein Shuttle fuhr zum %s." % shuttle_venues[0])
	elif shuttle_venues.size() > 1:
		lines.append("Shuttles fuhren zu %d Spielstätten." % shuttle_venues.size())
	var hitzetag_pricing := pricing_for_day(game, AIR_QUALITY_DAY)
	if hitzetag_pricing == "premium":
		lines.append("Am Hitzetag galten Premiumpreise.")
	elif hitzetag_pricing == "fair":
		lines.append("Am Hitzetag galten faire Preise.")
	var relocated := 0
	var closed := 0
	for type: String in ["fountain", "toilet"]:
		for service: Dictionary in _records(data, type + "s"):
			match latest.get(_key(type, service.id), ""):
				"relocate": relocated += 1
				"close": closed += 1
	if relocated > 0:
		lines.append("%d Toiletten und Brunnen wurden verlegt." % relocated if relocated > 1 else "Eine Toilette oder ein Brunnen wurde verlegt.")
	if closed > 0:
		lines.append("%d Toiletten und Brunnen wurden geschlossen." % closed if closed > 1 else "Eine Toilette oder ein Brunnen wurde geschlossen.")
	if lines.is_empty():
		return "Die Stadt blieb, wie sie war."
	return "\n".join(lines.slice(0, SUBTITLE_MAX_LINES))


## "Die Platane nahe Mariendom" — German genus name plus the nearest venue within SUBTITLE_NEAR_VENUE_M.
static func _tree_phrase(tree: Dictionary, data: Dictionary) -> String:
	var genus := str(tree.get("species", "")).get_slice(" ", 0)
	var name: Array = TREE_NAMES.get(genus, ["Baum", "Der"])
	var phrase := "%s %s" % [name[1], name[0]]
	var nearest := ""
	var best := SUBTITLE_NEAR_VENUE_M
	for venue: Dictionary in _records(data, "venues"):
		var distance := _distance_m(tree.lat, tree.lon, venue.lat, venue.lon)
		if distance <= best:
			best = distance
			nearest = str(venue.get("name", ""))
	return phrase + (" nahe %s" % nearest if not nearest.is_empty() else "")


static func _last_consulted_tree(game: Dictionary, data: Dictionary, latest: Dictionary) -> Dictionary:
	var consulted: Variant = game.get("consulted")
	if not (consulted is Array):
		return {}
	for i in range(consulted.size() - 1, -1, -1):
		var key := str(consulted[i])
		if not key.begins_with("tree:"):
			continue
		var tree := find_entity(data, key.trim_prefix("tree:"), "tree")
		if _has_position(tree) and latest.get(key, "") != "cut":
			return tree
	return {}


## "2 Foodtrucks und 1 Security-Team am Ars Electronica Center" for the best-stocked venue.
static func _purchase_sentence(game: Dictionary, data: Dictionary) -> String:
	var counts := _purchase_counts(game)
	var best := {}
	var best_total := 0
	for venue: Dictionary in _records(data, "venues"):
		var per_venue: Dictionary = counts.get(str(venue.id), {})
		var total := int(per_venue.get("foodtruck", 0)) + int(per_venue.get("security", 0))
		if total > best_total:
			best_total = total
			best = venue
	if best.is_empty():
		return ""
	var per_best: Dictionary = counts.get(str(best.id), {})
	var parts: Array[String] = []
	var trucks := int(per_best.get("foodtruck", 0))
	var teams := int(per_best.get("security", 0))
	if trucks > 0:
		parts.append("1 Foodtruck" if trucks == 1 else "%d Foodtrucks" % trucks)
	if teams > 0:
		parts.append("1 Security-Team" if teams == 1 else "%d Security-Teams" % teams)
	return "%s am %s." % [" und ".join(parts), best.get("name", "")]


## Happiness modifier from the cached PM10 reading: +AIR_MODIFIER (clean) .. -AIR_MODIFIER (polluted)
## on AIR_QUALITY_DAY, 0 on other days or when data.airquality is missing or invalid.
static func air_quality_modifier(state: Dictionary, data: Dictionary) -> float:
	var air: Variant = data.get("airquality")
	if state.get("day") != AIR_QUALITY_DAY or not (air is Dictionary):
		return 0.0
	var pm10: Variant = air.get("pm10")
	if not (pm10 is float or pm10 is int) or is_nan(float(pm10)) or float(pm10) < 0.0:
		return 0.0
	var pollution := clampf(inverse_lerp(AIR_CLEAN_PM10, AIR_POLLUTED_PM10, float(pm10)), 0.0, 1.0)
	return lerpf(AIR_MODIFIER, -AIR_MODIFIER, pollution)


## Share (0..1) of total venue event_weight with an open service within radius.
static func _coverage_score(venues: Array, services: Array, radius: float) -> float:
	var total := 0.0
	var covered := 0.0
	for venue: Dictionary in venues:
		var weight := float(venue.event_weight)
		total += weight
		if _near_any(venue, services, radius):
			covered += weight
	return covered / total if total > 0.0 else 0.0


## Open services of one type at their effective positions. Closed ones are dropped; relocated ones
## move (in decision order) to the highest-weight venue left without that service in walk_radius,
## but only if that raises coverage — so a relocation never lowers it.
static func _effective_services(records: Array, type: String, state: Dictionary, latest: Dictionary, venues: Array) -> Array:
	var services: Array = records.filter(func(r): return latest.get(_key(type, r.id)) != "close")
	var moved := {}
	for decision: Dictionary in _decisions(state):
		var key := _key(decision.entity_type, decision.entity_id)
		if decision.entity_type != type or latest.get(key) != "relocate" or moved.has(key):
			continue
		moved[key] = true
		var index := services.find_custom(func(s): return str(s.id) == str(decision.entity_id))
		if index == -1:
			continue
		var others := services.duplicate()
		others.remove_at(index)
		var target := _heaviest_uncovered_venue(venues, others, CONFIG.walk_radius)
		if target.is_empty():
			continue
		var moved_services := services.duplicate()
		moved_services[index] = { "id": decision.entity_id, "lat": target.lat, "lon": target.lon }
		if _coverage_score(venues, moved_services, CONFIG.walk_radius) > _coverage_score(venues, services, CONFIG.walk_radius):
			services = moved_services
	return services


static func _heaviest_uncovered_venue(venues: Array, services: Array, radius: float) -> Dictionary:
	var best := {}
	for venue: Dictionary in venues:
		if not _near_any(venue, services, radius) and (best.is_empty() or venue.event_weight > best.event_weight):
			best = venue
	return best


## 0..1: crown diameter within SHADE_RADIUS_M of any venue (felled trees 0, trimmed
## TRIM_SHADE_FACTOR, planted trees PLANTED_CROWN_M), SHADE_FULL_CROWN_M = full.
static func _shade_score(venues: Array, trees: Array, latest: Dictionary, planted: Array = []) -> float:
	var crown := 0.0
	for young: Dictionary in planted:
		if _near_any(young, venues, SHADE_RADIUS_M):
			crown += float(young.crown_m)
	for tree: Dictionary in trees:
		var decision: String = latest.get(_key("tree", tree.id), "")
		if decision == "cut" or not _is_number(tree.get("crown_m")) or not _near_any(tree, venues, SHADE_RADIUS_M):
			continue
		crown += float(tree.crown_m) * (TRIM_SHADE_FACTOR if decision == "trim" else 1.0)
	return minf(1.0, crown / SHADE_FULL_CROWN_M)


static func _cut_penalty(venues: Array, trees: Array, latest: Dictionary) -> float:
	var penalty := 0.0
	for tree: Dictionary in trees:
		if latest.get(_key("tree", tree.id)) == "cut":
			penalty += CUT_PENALTY
			if _near_any(tree, venues, CUT_PENALTY_RADIUS_M):
				penalty += CUT_NEAR_VENUE_PENALTY
	return penalty


## 0..1: event-weighted reach factor. A shuttle within shuttle_radius gives SHUTTLE_REACH; otherwise
## CLUSTER_REACH with another venue within VENUE_CLUSTER_RADIUS_M, else ISOLATED_REACH — plus
## PEDESTRIAN_REACH_BONUS near a pedestrianised street and CURFEW_REACH_BONUS with extended hours.
static func _reachability(state: Dictionary, venues: Array, pedestrian_streets: Array, latest: Dictionary = {}, trees: Array = []) -> float:
	var total := 0.0
	var reached := 0.0
	var shuttles := _positions(state.get("shuttles"))
	var cleared: Array = trees.filter(func(t): return latest.get(_key("tree", t.id), "") in ["cut", "trim"])
	for venue: Dictionary in venues:
		var weight := float(venue.event_weight)
		var reach := ISOLATED_REACH
		if _near_any(venue, shuttles, CONFIG.shuttle_radius):
			reach = SHUTTLE_REACH
		elif _near_any(venue, venues, VENUE_CLUSTER_RADIUS_M):
			reach = CLUSTER_REACH
		if _near_any(venue, pedestrian_streets, PEDESTRIAN_RADIUS_M):
			reach += PEDESTRIAN_REACH_BONUS
		if latest.get(_slot_key("venue", venue.id, "curfew", 0)) == "extend":
			reach += CURFEW_REACH_BONUS
		var clearing := 0.0
		for tree: Dictionary in cleared:
			if _distance_m(venue.lat, venue.lon, tree.lat, tree.lon) <= CUT_PENALTY_RADIUS_M:
				clearing += CUT_CLEARING_REACH if latest.get(_key("tree", tree.id)) == "cut" else TRIM_CLEARING_REACH
		reach += minf(CLEARING_REACH_CAP, clearing)
		total += weight
		reached += weight * minf(1.0, reach)
	return reached / total if total > 0.0 else 0.0


## Net money as 0..100 (unclamped). Costs come from the decision log, not state.budget,
## so they are counted once even though decide() also deducts them from budget.
static func _money_score(state: Dictionary, attendance: float, grants := 0.0) -> float:
	var costs := 0.0
	for decision: Dictionary in _decisions(state):
		costs += float(decision.cost) if _is_number(decision.get("cost")) else 0.0
	var income: float = attendance / 100.0 * MAX_VISITOR_INCOME * CONFIG.visitor_spend / REFERENCE_SPEND
	var net: float = CONFIG.start_budget - costs + income + grants
	return 100.0 * net / (CONFIG.start_budget + MAX_VISITOR_INCOME)


## The decision in effect per entity slot (see _slot_key), later decisions win. Repeatable purchases
## have no slot.
static func _latest_decisions(state: Dictionary) -> Dictionary:
	var latest := {}
	for decision: Dictionary in _decisions(state):
		var entry := _catalogue_entry(decision.entity_type, decision.decision_id)
		if entry.get("repeatable", false):
			continue
		var slot := _slot_key(decision.entity_type, decision.entity_id, entry.get("group", "main"), decision.get("day", 1))
		latest[slot] = decision.decision_id
	return latest


## "<type>:<id>" for the main group, "<type>:<id>#<group>" otherwise; pricing is per day
## ("festival:festival#pricing@<day>").
static func _slot_key(entity_type: Variant, entity_id: Variant, group: Variant, day: Variant) -> String:
	var key := _key(entity_type, entity_id)
	if group == "main" or group == null:
		return key
	if group == "pricing":
		return "%s#pricing@%d" % [key, int(day) if _is_number(day) else 1]
	return key + "#" + str(group)


static func _catalogue_entry(entity_type: Variant, decision_id: Variant) -> Dictionary:
	for entry: Dictionary in DECISIONS.get(entity_type, []):
		if entry.id == decision_id:
			return entry
	return {}


## Planted trees derived from the decision log (positions from `data`): [{ id, lat, lon, crown_m, age }].
static func _planted_trees(state: Dictionary, data: Dictionary) -> Array:
	var planted := []
	var per_entity := {}
	for decision: Dictionary in _decisions(state):
		if decision.decision_id != "plant" or not _catalogue_entry(decision.entity_type, "plant").get("repeatable", false):
			continue
		var entity := find_entity(data, str(decision.entity_id), str(decision.entity_type))
		if not _has_position(entity):
			continue
		var key := _key(decision.entity_type, decision.entity_id)
		var index: int = per_entity.get(key, 0)
		if index >= int(PLANT_DECISION.max):
			continue
		per_entity[key] = index + 1
		planted.append(_planted_tree(entity, index))
	return planted


## Deterministic spot for the index-th tree planted at an entity: PLANT_OFFSET_M away, 120° apart.
static func _planted_tree(entity: Dictionary, index: int) -> Dictionary:
	var angle := deg_to_rad(30.0 + 120.0 * index)
	var meters_per_deg_lat := EARTH_RADIUS_M * PI / 180.0
	var lat := float(entity.lat) + PLANT_OFFSET_M * cos(angle) / meters_per_deg_lat
	var lon := float(entity.lon) + PLANT_OFFSET_M * sin(angle) / (meters_per_deg_lat * cos(deg_to_rad(float(entity.lat))))
	return { "id": "planted:%s:%s:%d" % [entity.get("type", ""), entity.get("id", ""), index], "lat": lat, "lon": lon,
		"crown_m": PLANTED_CROWN_M, "age": 0 }


static func _is_headline(entity: Dictionary) -> bool:
	return entity.get("type", "venue") == "venue" and _is_number(entity.get("events")) and float(entity.events) >= HEADLINE_MIN_EVENTS


## { venue_id: { decision_id: n } } for repeatable purchases in the decision log.
static func _purchase_counts(state: Dictionary) -> Dictionary:
	var counts := {}
	for decision: Dictionary in _decisions(state):
		if not _catalogue_entry(decision.entity_type, decision.decision_id).get("repeatable", false):
			continue
		var per_venue: Dictionary = counts.get(str(decision.entity_id), {})
		per_venue[decision.decision_id] = int(per_venue.get(decision.decision_id, 0)) + 1
		counts[str(decision.entity_id)] = per_venue
	return counts


## Event-weighted share (0..1) of unmet demand for `kind` over headline venues; -1 when no venue
## has demand (then food/security have no effect at all).
static func _stock_shortfall(venues: Array, counts: Dictionary, kind: String) -> float:
	var demand_total := 0.0
	var missing := 0.0
	for venue: Dictionary in venues:
		if not _is_headline(venue):
			continue
		var weight := float(venue.event_weight)
		var demand := ceilf(weight / PURCHASE_UNIT_EVENT_WEIGHT)
		var have := minf(demand, BASELINE_UNITS_PER_VENUE + float(counts.get(str(venue.id), {}).get(kind, 0)))
		demand_total += demand * weight
		missing += (demand - have) * weight
	return missing / demand_total if demand_total > 0.0 else -1.0


static func _curfew_penalty(venues: Array, latest: Dictionary) -> float:
	var extended := venues.filter(func(v): return latest.get(_slot_key("venue", v.id, "curfew", 0)) == "extend").size()
	return minf(CURFEW_HAPPINESS_CAP, CURFEW_HAPPINESS_PENALTY * extended)


## The pricing decision id in effect on `day` ("standard" when none was taken that day).
static func pricing_for_day(state: Dictionary, day: int) -> String:
	return _latest_decisions(state).get(_slot_key("festival", FESTIVAL_ENTITY.id, "pricing", day), "standard")


## { "foodtruck": n, "security": n, "demand": units, "baseline": units } for a venue, or {} when it
## isn't a headline venue — for UI status lines.
static func stock_status(state: Dictionary, venue: Dictionary) -> Dictionary:
	if not _is_headline(venue) or not _is_number(venue.get("event_weight")):
		return {}
	var counts: Dictionary = _purchase_counts(state).get(str(venue.get("id", "")), {})
	return {
		"foodtruck": int(counts.get("foodtruck", 0)),
		"security": int(counts.get("security", 0)),
		"demand": int(ceilf(float(venue.event_weight) / PURCHASE_UNIT_EVENT_WEIGHT)),
		"baseline": BASELINE_UNITS_PER_VENUE,
	}


## Mean pricing factors over days 1..state.day ({ attendance: multiplier, money: multiplier }).
static func _pricing_factors(state: Dictionary, latest: Dictionary) -> Dictionary:
	var days := clampi(int(state.day) if _is_number(state.get("day")) else 1, 1, LAST_DAY)
	var attendance := 0.0
	var money := 0.0
	for day in range(1, days + 1):
		var choice: String = latest.get(_slot_key("festival", FESTIVAL_ENTITY.id, "pricing", day), "standard")
		var factors: Dictionary = PRICING.get(choice, PRICING.standard)
		attendance += 1.0 + factors.attendance
		money += factors.money
	return { "attendance": attendance / days, "money": money / days }


## "<type>:<id>" — ids by string form, so numeric JSON ids and their strings match.
static func _key(entity_type: Variant, entity_id: Variant) -> String:
	return str(entity_type) + ":" + str(entity_id)


## Well-formed decision records of the state (dicts with entity_type, entity_id and decision_id).
static func _decisions(state: Dictionary) -> Array:
	var decisions: Variant = state.get("decisions")
	if not (decisions is Array):
		return []
	return decisions.filter(func(d): return d is Dictionary and d.has("entity_type") and d.has("entity_id") and d.has("decision_id"))


## Scorable records of one data collection: dicts with an id and a finite lat/lon.
static func _records(data: Dictionary, key: String) -> Array:
	return _positions(data.get(key)).filter(func(r): return r.has("id"))


## Dicts with a finite lat/lon from a value that should be an Array (anything else -> []).
static func _positions(value: Variant) -> Array:
	if not (value is Array):
		return []
	return value.filter(func(r): return r is Dictionary and _has_position(r))


static func _has_position(record: Dictionary) -> bool:
	return _is_number(record.get("lat")) and _is_number(record.get("lon"))


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_valid_state(state: Dictionary) -> bool:
	return state.get("decisions") is Array and state.get("shuttles") is Array \
		and _is_number(state.get("day")) and _is_number(state.get("budget"))


## True if any of `others` (dicts with lat/lon) is within radius of point, ignoring point itself.
## A conservative lat/lon box rejects far pairs before the haversine (previews simulate compute_meters
## several times per click, and most tree–venue pairs are far apart).
static func _near_any(point: Dictionary, others: Array, radius: float) -> bool:
	var lat := float(point.lat)
	var lon := float(point.lon)
	var max_d_lat := radius / BOX_METERS_PER_DEG_LAT
	var max_d_lon := radius / (BOX_METERS_PER_DEG_LAT * maxf(0.01, cos(deg_to_rad(absf(lat) + 1.0))))
	for other: Dictionary in others:
		if absf(float(other.lat) - lat) > max_d_lat or absf(float(other.lon) - lon) > max_d_lon:
			continue
		if not is_same(other, point) and _distance_m(lat, lon, other.lat, other.lon) <= radius:
			return true
	return false


## Haversine distance in meters between two WGS84 points.
static func _distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var d_lat := deg_to_rad(lat2 - lat1)
	var d_lon := deg_to_rad(lon2 - lon1)
	var a := sin(d_lat / 2.0) ** 2 + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(d_lon / 2.0) ** 2
	return 2.0 * EARTH_RADIUS_M * asin(minf(1.0, sqrt(a)))
