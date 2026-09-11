# Bürgermeister:in fürs Festival — Godot Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Playable Godot 4 desktop game: the player is Linz's mayor during festival week, negotiating with speaking city entities, scored on attendance / money / happiness from real open data.

**Architecture:** Godot 4.7 project in `game/godot/` (no web export needed per hackathon rules). Map = stylized PNG baked from geo datasets by Python; entities clickable markers; LLM dialogue via HTTPRequest to `mistral-proxy` with canned fallback. Three parallel tracks: Map&Data, Game Core, Dialogue&UI.

**Tech Stack:** Godot 4.7 (GDScript), Python 3 (data extraction + map baking), `mistral-proxy` (existing), headless Godot for tests.

**Spec:** `docs/superpowers/specs/2026-09-11-buergermeister-spiel-design.md` (engine-revised)

## Global Constraints

- Godot 4.7, GDScript only, no C#/addons; engine + export templates confirmed on pitch laptop
- All game data in `game/godot/data/`, produced ONLY by `tools/extract_innenstadt.py` and `tools/render_map.py` from `data/` snapshots
- LLM calls ONLY via `http_client.gd` → `http://127.0.0.1:8377/v1/chat/completions`, model `mistralai/mistral-medium-3-5`, always `max_tokens`
- UI language: German; personas earnest, slightly poetic, factually grounded
- WGS84 lat/lon; haversine distances
- Verify every task with `godot --headless --path game/godot --quit` (import/syntax check) — must exit 0
- Unit tests via `godot --headless -s res://tests/run_tests.gd`, must pass before commit
- Branch `feature/<task-short-name>` per task, PR + one approval, per CONTRIBUTING.md

## Team Split

| Track | Owner | Tasks |
|-------|-------|-------|
| A — Map & Data | teammate 1 | 1 (extract), 2 (bake map), 3 (data_loader), 4 (map_view) |
| B — Game Core | teammate 2 | 5 (scoring), 6 (day machine) |
| C — Dialogue & UI | teammate 3 (+ Godot-MCP agent) | 0 (scaffold), 7 (proxy client), 8 (dialogue), 9 (panels), 10 (wiring+build) |

Task 0 first, then A/B/C in parallel, integrating via the contracts below.

## Shared Interfaces (contracts — do not change signatures)

```gdscript
# data_loader.gd  (Node, autoload singleton "Data")
func load_all(path := "res://data/") -> Dictionary
# returns { venues: Array, trees: Array, fountains: Array, toilets: Array, streets: Array, meta: Dictionary }
# Venue:  { id: String, name: String, lat: float, lon: float, events: int, event_weight: int }
# Tree:   { id: String, lat: float, lon: float, species: String, height_m: float, crown_m: float, age_estimate: int }
# Fountain/Toilet: { id: String, name: String, lat: float, lon: float }
# Street: { id: String, name: String, history: String, lat: float, lon: float }

# game_state.gd  (RefCounted, pure logic — no Nodes)
const CONFIG := { "start_budget": 50000.0, "visitor_spend": 35.0, "walk_radius": 300.0, "shuttle_radius": 250.0 }
static func create() -> Dictionary          # { day: 1, budget: float, decisions: [], shuttles: [] }
static func compute_meters(state: Dictionary, data: Dictionary) -> Dictionary
                                             # { attendance: 0..100, money: 0..100, happiness: 0..100 }
static func available_decisions(entity: Dictionary) -> Array   # [{ id, label, cost, adds_shuttle }]
static func decide(state: Dictionary, entity: Dictionary, decision_id: String) -> bool
static func next_day(state: Dictionary) -> void
static func day_theme(day: int) -> Dictionary  # { title, focus, hint }

# map_view.gd  (Control)
signal entity_clicked(id: String, type: String)
func set_entity_state(id: String, state: String)   # "neutral" | "affected" | "resolved"
func focus_entity(id: String)
# map_meta.json (produced by render_map.py): { width, height, lat_min, lat_max, lon_min, lon_max }

# http_client.gd  (Node, autoload singleton "Voices")
func ask(messages: Array, max_tokens := 400) -> String   # async (await); on failure returns "" and sets last_error = "PROXY_DOWN"

# dialogue.gd  (Node)
func start_dialogue(entity: Dictionary, data: Dictionary) -> Dictionary  # { entity, history, opening }
func send_user_message(game: Dictionary, dlg: Dictionary, text: String) -> Dictionary
# -> { reply: String, intent: Dictionary|null }  intent: { type: "decide", decision_id } | { type: "next_day" }
```

---

### Task 0: Godot project scaffold (Track C)

**Files:**
- Create: `game/godot/project.godot`, `game/godot/scenes/main.tscn`, `game/godot/scripts/main.gd`

**Interfaces:** Produces project layout + `main` scene every later task plugs into.

- [ ] **Step 1:** `project.godot` (text): `config_version=5`, application/run/main_scene=`"res://scenes/main.tscn"`, window size 1600×900, renderer gl_compatibility (runs on any laptop GPU).
- [ ] **Step 2:** `main.tscn`: root `Control` (anchors full rect) with HSplitContainer: left `SubViewportContainer`-placeholder `Panel` named `MapSlot` (size_flags_horizontal expand+fill), right `VBoxContainer` named `PanelSlot` (custom min size 380 px) containing placeholder Labels `MetersSlot`, `DaySlot`, `ChatSlot`.
- [ ] **Step 3:** `main.gd`: empty `_ready()` with comment `# wiring lands in Task 10`.
- [ ] **Step 4:** Run `godot --headless --path game/godot --quit`; exit 0, no parse errors.
- [ ] **Step 5:** Commit `feat: godot scaffold` on `feature/godot-scaffold`, PR, merge.

### Task 1: Data extraction (Track A)

**Files:**
- Create: `tools/extract_innenstadt.py`, `game/godot/data/{venues,trees,fountains,toilets,streets,meta}.json`

**Interfaces:**
- Consumes: `data/festival/notion_export.json`, `data/linz/baumkataster/Baumkataster.csv`, `data/linz/trinkbrunnen/Trinkbrunnen.csv`, `data/linz/wc-anlagen/WC-Anlagen.csv`, `data/linz/strassennamen/Strassennamen-aktuell.csv` — **read each dataset's README in `data/linz/<set>/` for real column names first**
- Produces: JSON shapes per Shared Interfaces contract above.

- [ ] **Step 1:** Skeleton with `BOUNDS = (48.284, 48.318, 14.270, 14.320)` (lat_min, lat_max, lon_min, lon_max) and `out(name, rows)` writing UTF-8 JSON.
- [ ] **Step 2:** Venues: festival export locations with valid coordinates inside BOUNDS; `events` = count of linked calendar entries; `event_weight` = min(20, events); German name.
- [ ] **Step 3:** Trees/fountains/toilets filtered to BOUNDS; trees capped at 400 (largest `crown_m` first); `age_estimate` = null when the CSV has no circumference/age column (do NOT invent).
- [ ] **Step 4:** Streets: rows with non-empty history inside Innenstadt, representative point from the CSV if present else skip; cap 60.
- [ ] **Step 5:** `meta.json`: bounds, extracted_at, sources.
- [ ] **Step 6:** Run: expect venues 5–15, trees ≈400, fountains/toilets 5–20 each, streets ≈60; fix until counts plausible. Commit PR `feat: extract innenstadt datasets`.

### Task 2: Map baking (Track A)

**Files:** Create: `tools/render_map.py`, `game/godot/assets/innenstadt_map.png`, `game/godot/data/map_meta.json`

**Interfaces:** Produces PNG + meta per contract (`width, height, lat_min, lat_max, lon_min, lon_max`).

- [ ] **Step 1:** `render_map.py` using Pillow (std lib has no PNG writer — `pip install pillow` or vendor; if no network, use `matplotlib` if present): 2048×2048 canvas from BOUNDS.
- [ ] **Step 2:** Layer order: Danube/river polygon dark blue (approximate from orthophoto/known geography — acceptable stylization), park/green areas soft green, street network light gray lines (from streets dataset points only if no geometry — else omit roads), building blocks subtle gray (optional, from baulandreserven GeoJSON if easy).
- [ ] **Step 3:** Write `map_meta.json` with exact transform values; print them.
- [ ] **Step 4:** Verify: open PNG (ReadMediaFile), confirm Innenstadt recognizable (river along south-west, street pattern plausible); commit PR `feat: baked innenstadt map`.

### Task 3: data_loader.gd (Track A)

**Files:** Create: `game/godot/scripts/data_loader.gd`; register as autoload `Data` in `project.godot`.

- [ ] **Step 1:** Implement `load_all()` per contract: `FileAccess.open` each of the six JSONs, `JSON.parse_string`, return Dictionary; on missing file `push_error` with filename and return {}.
- [ ] **Step 2:** Verify headless: temporary `res://tests/run_tests.gd` (extends SceneTree) asserting `Data.load_all().venues.size() > 0` and tree records have `species`; run `godot --headless -s res://tests/run_tests.gd`; keep the test file (grow it later).
- [ ] **Step 3:** Commit PR `feat: data loader`.

### Task 4: map_view.gd (Track A)

**Files:** Create: `game/godot/scripts/map_view.gd`, `game/godot/scenes/map_view.tscn`; instance into `MapSlot` in `main.tscn`.

**Interfaces:** Produces `entity_clicked`, `set_entity_state`, `focus_entity` per contract.

- [ ] **Step 1:** Scene root `PanelContainer` → `ScrollContainer` (both h/v) → `TextureRect` with baked PNG, `stretch_mode` keep aspect.
- [ ] **Step 2:** `map_meta.json` load in `_ready()`; helper `latlon_to_pixel(lat, lon) -> Vector2`.
- [ ] **Step 3:** For each entity (all five arrays): `TextureButton` (9px colored dot textures generated in code via `Image.create` + `ImageTexture.create_from_image`) positioned at pixel coords, stored in `markers[id]`; pressed → `emit_signal("entity_clicked", id, type)`.
- [ ] **Step 4:** `set_entity_state`: 'affected' → modulate orange; 'resolved' → modulate gray + disabled; `focus_entity`: center ScrollContainer scroll on marker.
- [ ] **Step 5:** Verify headless import clean; manual: temp `main.gd` line connecting signal to `print` — run editor once, click markers, revert; commit PR `feat: clickable entity map`.

### Task 5: game_state.gd — three meters (Track B)

**Files:** Create: `game/godot/scripts/game_state.gd`, `game/godot/tests/run_tests.gd` (if not exists, else extend)

**Interfaces:** Produces `CONFIG`, `create`, `compute_meters` per contract.

- [ ] **Step 1:** Write tests first in `run_tests.gd` (SceneTree script, use `assert` + collect failures, `quit(1)` on fail): fixture data with one venue (lat 48.306, lon 14.284, events 10), one tree near it, one fountain, one toilet. Tests: (a) fresh state → all three meters within 0..100 and money > 50; (b) adding `{entityId:t1, entityType:"tree", decisionId:"cut", day:3, cost:200}` lowers happiness; (c) two cost-bearing decisions lower money meter.
- [ ] **Step 2:** Run `godot --headless -s res://tests/run_tests.gd` → FAIL (functions missing).
- [ ] **Step 3:** Implement `game_state.gd` as `class_name GameState extends RefCounted` (pure logic): CONFIG per contract; `create()` per contract; `compute_meters()`:
  - happiness: base 50; +20 if ≥70% of venue event_weight is within `walk_radius` of an open fountain; +20 same for open toilets; +15 if >80% trees uncut; +15 scaled by uncut-tree crown within 150 m of venues (200 m total crown = full); −10 per tree cut within 50 m of a venue; clamp 0..100. (Open = no `close` decision.)
  - attendance: base 40; per venue reachable (shuttle in `shuttle_radius` OR within 200 m of another venue) → + up to 60 proportional to covered event_weight; clamp.
  - money: `net = budget − costs + attendance_fraction × 20000 × visitor_spend/35`; `100 × net / (start_budget + 20000)`; clamp.
  - Named static helpers (`_coverage_score`, `_shade_score`, `_reachability`, `_money_score`) for live demo tweaking.
- [ ] **Step 4:** Run tests → PASS. Commit PR `feat: three-meter scoring`.

### Task 6: day machine & decisions (Track B)

**Files:** Modify: `game/godot/scripts/game_state.gd`

**Interfaces:** Produces `available_decisions`, `decide`, `next_day`, `day_theme` per contract.

- [ ] **Step 1:** `day_theme(day)`: 1 → `{title:"Tag 1 — Anreise", focus:"Mobilität", hint:"Wo sollen Shuttle fahren?"}`; 2 → `{title:"Tag 2 — Höhepunkt", focus:"Sanitär & Wasser", ...}`; 3 → `{title:"Tag 3 — Hitzetag", focus:"Schatten & Bäume", ...}`.
- [ ] **Step 2:** `available_decisions(entity)`: tree → keep(0)/Zurückschnitten(150)/Fällen(400); fountain|toilet → Stehen lassen/Verlegen(800)/Schließen(0); venue → Shuttle-Haltestelle einrichten(1200, adds_shuttle); street → Für Fußgänger sperren(300)/Freigeben(0). Day focus only filters the *hint*, all types always available.
- [ ] **Step 3:** `decide(state, entity, decision_id)`: find decision in `available_decisions`; if state already has same entity+decision → return false; append `{entity_id, entity_type, decision_id, day, cost}`; `budget -= cost`; if `adds_shuttle` append `{lat, lon}` to `state.shuttles`; return true.
- [ ] **Step 4:** `next_day(state)`: `state.day = mini(3, day+1)`.
- [ ] **Step 5:** Tests: decide twice → second returns false; shuttle decision adds to shuttles; budget math; run headless → PASS. Commit PR `feat: day machine and decisions`.

### Task 7: http_client.gd — proxy client (Track C)

**Files:** Create: `game/godot/scripts/http_client.gd`; autoload `Voices` in `project.godot`.

**Interfaces:** Produces `ask()` per contract (async — callers use `await`). GDScript has no exceptions: failure convention is `ask()` returns `""` and sets `Voices.last_error = "PROXY_DOWN"`; `dialogue.gd` must check `Voices.last_error` after every call.

- [ ] **Step 1:** Implement with `HTTPRequest` node created in code: POST JSON `{messages, max_tokens, model:"mistralai/mistral-medium-3-5"}` to `http://127.0.0.1:8377/v1/chat/completions`, await `request_completed`, 8 s timeout.
- [ ] **Step 2:** Parse `choices[0].message.content`; on connection error/timeout: `last_error = "PROXY_DOWN"`, return `""`.
- [ ] **Step 3:** Live check: start `python3 mistral-proxy/server.py`, temp test script `print(await Voices.ask([{role:"user",content:"Sag OK"}], 50))` → prints OK; stop proxy; same call returns "" with last_error set. Commit PR `feat: godot proxy client`.

### Task 8: dialogue.gd — persona engine (Track C)

**Files:** Create: `game/godot/scripts/dialogue.gd`, `tools/gen_fallback_voices.py`, `game/godot/data/fallback_voices.json`

**Interfaces:** Produces `start_dialogue`, `send_user_message` per contract.

- [ ] **Step 1:** Persona system prompt (German): "Du bist {name}, {type_de} in Linz, 2026. Erste Person, ernsthaft, leicht poetisch, höchstens 3 Sätze. Fakten: {facts}. Du verhandelst mit der Bürgermeisterin/dem Bürgermeister über: {focus}." Facts per type: tree → species, age (or 'unbekannt'), crown; street → history (300 chars); venue → name, events; fountain/toilet → name + day-2 role.
- [ ] **Step 2:** `start_dialogue`: build history, `opening = await Voices.ask(history, 150)`; if `last_error == "PROXY_DOWN"` → rotate line from `fallback_voices.json[type]`.
- [ ] **Step 3:** `send_user_message`: append user msg, await reply, parse markers: `[[ENTSCHEID:<id>]]` → intent `{type:"decide", decision_id}` (strip marker from shown reply); `[[NAECHSTER_TAG]]` → `{type:"next_day"}`; PROXY_DOWN → fallback line, intent null.
- [ ] **Step 4:** `tools/gen_fallback_voices.py`: while proxy runs, generate 4 variants per entity type via proxy, save `fallback_voices.json`; commit the JSON.
- [ ] **Step 5:** Headless smoke test of full exchange with proxy up; commit PR `feat: persona dialogue engine`.

### Task 9: UI panels (Track C)

**Files:** Create: `game/godot/scripts/{meters,day_bar,chat_panel}.gd` + scenes; wire into `PanelSlot` in `main.tscn`.

- [ ] **Step 1:** `meters`: three `ProgressBar` (0–100) with German labels (Besucher:innen, Geld, Zufriedenheit) + `set_meters(m: Dictionary)`.
- [ ] **Step 2:** `day_bar`: title/focus/hint Label trio from `day_theme`, "Nächster Tag →" Button; on day 3 button becomes "Abschluss" → verdict overlay (ColorRect + Labels showing three meters + mayor title: all >66 → "Volksnahe Stadtplanung", money>66 & happiness<50 → "Effizienz-Tyrann:in", etc.).
- [ ] **Step 3:** `chat_panel`: ScrollContainer message list (RichTextLabel bubbles), LineEdit + Send, decision chips (buttons from `available_decisions`) that send `[[ENTSCHEID:<id>]]`; shows typing indicator during await.
- [ ] **Step 4:** `open_entity(entity, decisions)` API; verify headless import clean. Commit PR `feat: ui panels`.

### Task 10: Wiring + final build (ALL, led by C)

**Files:** Modify: `game/godot/scripts/main.gd`, `main.tscn`, root README.

- [ ] **Step 1:** `main.gd`: load data → build game state (`GameState.create()`) → connect `map_view.entity_clicked` → open chat for entity → on intent `decide` call `GameState.decide` + `map_view.set_entity_state(id,"resolved")` + refresh meters (`compute_meters`); on `next_day` → `day_bar` update; on any state change refresh meters + map 'affected' highlight on entities near decided ones.
- [ ] **Step 2:** Full playthrough test with proxy running: day 1 shuttle at AEC, day 2 relocate a toilet, day 3 spare a tree → meters move visibly, verdict shows.
- [ ] **Step 3:** `export_presets.cfg` for Linux x86_64; `godot --headless --path game/godot --export-release "Linux" build/buergermeister.x86_64`; verify binary starts on the pitch laptop; screenshot main screen for the pitch.
- [ ] **Step 4:** README quick-start (run from editor / binary + start proxy). Commit PR `feat: full game wiring and build`.

### Task 11 (stretch, only if ahead): air quality + English

- [ ] `tools/fetch_airquality.py` caches one reading into `game/godot/data/airquality.json`; Day-3 happiness ±10 by PM level; `?lang=en` toggle via OS locale or settings key.

---

## Self-review notes

- Spec coverage: engine revision applied to scaffold/map/client/wiring (T0,2,4,7,10); scoring, personas, days, fallback, MVP boundaries unchanged from spec; stretch isolated (T11).
- Type consistency: contract block is the single source of truth; GDScript snake_case used throughout; `ask()` failure convention (empty string + `Voices.last_error`) documented where exceptions don't exist.
- Deliberate simplifications: no roads/buildings geometry guarantee in baked map (stylized is the aesthetic), reachability defaults to venue clustering, decision catalogue fixed per entity type.
