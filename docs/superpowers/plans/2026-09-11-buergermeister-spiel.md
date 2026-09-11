# Bürgermeister:in fürs Festival — Implementation Plan

> **SUPERSEDED 2026-09-11:** engine switched to Godot 4 desktop app. Use
> `2026-09-11-buergermeister-spiel-godot.md` instead. This file is kept for
> scoring-test reference only (Task 4's meter logic still describes the agreed formulas).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable browser game where the player is Linz's mayor during festival week, negotiating with speaking city entities, scored on attendance / money / happiness from real open data.

**Architecture:** Static browser app in `game/` (native ES modules, no build step), data preprocessed by `tools/extract_innenstadt.py` from `data/` into small JSON, LLM dialogue via `mistral-proxy` with canned fallback. Three parallel work tracks: Map&Data, Game Core, Dialogue&UI.

**Tech Stack:** Vanilla JS (ES modules), Leaflet 1.9 from CDN, Python 3 (extraction), `mistral-proxy` (existing), Node 18+ (`node --test` for unit tests).

**Spec:** `docs/superpowers/specs/2026-09-11-buergermeister-spiel-design.md`

## Global Constraints

- No build step, no npm dependencies — Leaflet from CDN (`https://unpkg.com/leaflet@1.9.4/dist/leaflet.css` / `leaflet.js`)
- ES modules only; serve with `python3 -m http.server 8000` from repo root, app at `http://localhost:8000/game/`
- All game data files live in `game/data/`, produced ONLY by `tools/extract_innenstadt.py` from `data/` snapshots
- LLM calls ONLY through `http://127.0.0.1:8377/v1/chat/completions` (mistral-proxy), model `mistralai/mistral-medium-3-5`, always `max_tokens`
- UI language: German (personas earnest, slightly poetic, factually grounded)
- Coordinate system: WGS84 lat/lon; distances via haversine
- Commit after every task; branch names `feature/<task-short-name>` per CONTRIBUTING.md

## Team Split

| Track | Owner | Tasks |
|-------|-------|-------|
| A — Map & Data | teammate 1 | 1 (data), 2 (map) |
| B — Game Core | teammate 2 | 3 (scoring), 4 (day machine) |
| C — Dialogue & UI | teammate 3 | 5 (proxy client), 6 (dialogue), 7 (UI), 8 (wiring) |

Task 0 (scaffold) is done by C first; tracks then run in parallel, syncing through the interfaces below.

## Shared Interfaces (contracts — do not change signatures)

```js
// data.js
export async function loadAll(basePath = 'data/') →
  { venues: Venue[], trees: Tree[], fountains: Fountain[], toilets: Toilet[], streets: Street[], meta: object }

// Venue:  { id, name, lat, lon, events, eventWeight }
// Tree:   { id, lat, lon, species, heightM, crownM, ageEstimate }
// Fountain/Toilet: { id, name, lat, lon }
// Street: { id, name, history, lat, lon }

// score.js
export const CONFIG = { START_BUDGET: 50000, VISITOR_SPEND: 35, WALK_RADIUS: 300, SHUTTLE_RADIUS: 250 }
export function createGameState(config = CONFIG) → GameState
export function computeMeters(state, data) → { attendance, money, happiness }  // each 0..100
// GameState: { day: 1..3, budget: number, decisions: [{entityId, entityType, decisionId, day, cost}], shuttles: [{id, lat, lon}] }

// map.js
export function initMap(elementId, data, onEntityClick) → MapController
// MapController: { setEntityState(id, state), focusEntity(id) }  state: 'neutral'|'affected'|'resolved'

// voices.js
export async function ask(messages, maxTokens = 400) → string   // throws Error('PROXY_DOWN') if proxy unreachable

// game.js
export function createGame(data, onChange) → Game
// Game: { state, dayTheme(), clickEntity(id, type), decide(decisionId), nextDay(), availableDecisions(entity) }

// dialogue.js
export function startDialogue(entity, data) → Dialogue
export async function sendUserMessage(game, dlg, text) → { reply: string, intent: object|null }
// intent: { type: 'decide', decisionId } | { type: 'nextDay' } | null
```

---

### Task 0: Game scaffold

**Files:**
- Create: `game/index.html`, `game/style.css`, `game/js/main.js`
- Create (empty stubs, valid ES modules): `game/js/data.js`, `game/js/map.js`, `game/js/score.js`, `game/js/game.js`, `game/js/voices.js`, `game/js/dialogue.js`, `game/js/ui.js`

**Interfaces:** Produces the file layout every later task fills.

- [ ] **Step 1:** Write `game/index.html`: HTML5 boilerplate, `<html lang="de">`, Leaflet 1.9.4 CSS+JS from unpkg (js loaded with `defer`), `<div id="map">`, `<aside id="panel">` containing `<div id="meters">`, `<div id="day-display">`, `<div id="chat">`, `<script type="module" src="js/main.js">`
- [ ] **Step 2:** Write `game/style.css`: full-viewport layout (`#map` 100vh; `#panel` fixed right, 380px, white background, z-index above map), minimal dark theme. No other styling yet.
- [ ] **Step 3:** Write each stub with exactly one line: `export {};` (except `main.js`: `console.log('Buergermeister scaffold loaded');`)
- [ ] **Step 4:** Run `python3 -m http.server 8000` from repo root, open `http://localhost:8000/game/`, confirm empty map container + panel render and console message shows. Stop server.
- [ ] **Step 5:** Commit `feat: game scaffold` (branch `feature/game-scaffold` → PR → merge)

### Task 1: Data extraction (Track A)

**Files:**
- Create: `tools/extract_innenstadt.py`, `game/data/venues.json`, `game/data/trees.json`, `game/data/fountains.json`, `game/data/toilets.json`, `game/data/streets.json`, `game/data/meta.json`

**Interfaces:**
- Consumes: `data/festival/notion_export.json` (locations+projects+calendar), `data/linz/baumkataster/Baumkataster.csv`, `data/linz/trinkbrunnen/Trinkbrunnen.csv`, `data/linz/wc-anlagen/WC-Anlagen.csv`, `data/linz/strassennamen/Strassennamen-aktuell.csv` (check actual column names in each README first!)
- Produces: JSON files with the exact shapes in Shared Interfaces above.

- [ ] **Step 1:** Read the READMEs of the four Linz datasets to learn column names; write `tools/extract_innenstadt.py` skeleton with constants `BOUNDS = (48.284, 48.318, 14.270, 14.320)` (Innenstadt: approx river→Tabakfabrik) and `out()` helper writing UTF-8 JSON.
- [ ] **Step 2:** Extract venues: from festival export, take locations with valid lat/lon inside BOUNDS; count linked calendar entries as `events`; `eventWeight = events` capped at 20. Fields: `id` (canonical_id), `name` (German title), `lat`, `lon`.
- [ ] **Step 3:** Extract trees/fountains/toilets: filter CSV rows to BOUNDS; tree `ageEstimate = None` if trunk circumference missing (do NOT invent ages — persona prompt handles None). Keep at most 400 trees (largest crown first) to keep the map fast.
- [ ] **Step 4:** Extract streets: from Strassennamen-aktuell, rows with non-empty history text inside Innenstadt (use provided lat/lon or geocode column if present, else skip row); cap 60 streets.
- [ ] **Step 5:** Write `meta.json` with bounds, extractedAt timestamp, source list.
- [ ] **Step 6:** Run script; sanity-print counts (expect: venues 5–15, trees ≈400, fountains 5–20, toilets 5–20, streets ≈60). Commit `feat: extract innenstadt datasets` as PR.

### Task 2: data.js loader (Track A)

**Files:** Modify: `game/js/data.js`

**Interfaces:** Produces `loadAll()` per contract.

- [ ] **Step 1:** Implement `loadAll(basePath)`: `Promise.all` fetches of the six JSON files, returns object keyed as in contract. Throw with filename on HTTP error.
- [ ] **Step 2:** Verify manually: temporarily add to `main.js` — `import { loadAll } from './data.js'; loadAll('data/').then(d => console.log(Object.keys(d), d.venues.length))` — run server, console shows keys + venue count, then revert main.js.
- [ ] **Step 3:** Commit as PR `feat: data loader`.

### Task 3: map.js (Track A)

**Files:** Modify: `game/js/map.js`

**Interfaces:**
- Consumes: `loadAll()` output.
- Produces: `initMap(elementId, data, onEntityClick)` per contract; `onEntityClick(id, type)` where type ∈ `'venue'|'tree'|'fountain'|'toilet'|'street'`.

- [ ] **Step 1:** Implement `initMap`: L.map on elementId, OSM tile layer (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`, attribution, maxZoom 19), `map.fitBounds([[48.284,14.270],[48.318,14.320]])`.
- [ ] **Step 2:** Add layer groups per entity type with colored circleMarkers: venue=red (radius by eventWeight 6–14), tree=green r=4, fountain=blue r=5, toilet=purple r=5, street=gray r=4. Store `entityId`+type in each marker; bind click → `onEntityClick(id, type)`.
- [ ] **Step 3:** Implement `setEntityState(id, state)`: 'affected' → orange ring (add second circleMarker or setStyle with weight 3 color orange), 'resolved' → desaturate opacity 0.4, 'neutral' → default. Keep an internal `layers[id]` map.
- [ ] **Step 4:** Implement `focusEntity(id)`: `map.setView(marker.getLatLng(), 17)` with popup open.
- [ ] **Step 5:** Manual check: wire in `main.js` — `initMap('map', await loadAll('data/'), (id,t)=>console.log(id,t))`; confirm all layers render and clicks log. Revert main.js, commit PR `feat: leaflet map with entity layers`.

### Task 4: score.js — the three meters (Track B)

**Files:** Create: `game/js/score.js`, `test/score.test.js`

**Interfaces:** Produces `CONFIG`, `createGameState`, `computeMeters` per contract.

- [ ] **Step 1:** Write `test/score.test.js` using `node:test` + `assert`: import `../game/js/score.js` (pure module, no DOM). Tests:
```js
import test from 'node:test';
import assert from 'node:assert';
import { createGameState, computeMeters, CONFIG } from '../game/js/score.js';

const DATA = {
  venues: [{ id: 'v1', name: 'AEC', lat: 48.306, lon: 14.284, events: 10, eventWeight: 10 }],
  trees: [{ id: 't1', lat: 48.307, lon: 14.285, species: 'Linde', heightM: 20, crownM: 12, ageEstimate: 100 }],
  fountains: [{ id: 'f1', name: 'Brunnen', lat: 48.3061, lon: 14.2841 }],
  toilets: [{ id: 'w1', name: 'WC', lat: 48.3062, lon: 14.2842 }],
  streets: [],
};

test('day 1: nothing decided gives low but non-zero meters', () => {
  const s = createGameState();
  const m = computeMeters(s, DATA);
  for (const k of ['attendance', 'money', 'happiness']) {
    assert.ok(m[k] >= 0 && m[k] <= 100, `${k} in range`);
  }
  assert.ok(m.money > 50, 'unspent budget counts as money');
});

test('cutting the only tree lowers happiness', () => {
  const s = createGameState();
  const before = computeMeters(s, DATA).happiness;
  s.decisions.push({ entityId: 't1', entityType: 'tree', decisionId: 'cut', day: 3, cost: 200 });
  const after = computeMeters(s, DATA).happiness;
  assert.ok(after < before);
});
```
- [ ] **Step 2:** Run `node --test test/score.test.js` → FAIL (module empty).
- [ ] **Step 3:** Implement `score.js` (pure, no DOM):
  - `CONFIG = { START_BUDGET: 50000, VISITOR_SPEND: 35, WALK_RADIUS: 300, SHUTTLE_RADIUS: 250 }`
  - `createGameState()` → `{ day: 1, budget: CONFIG.START_BUDGET, decisions: [], shuttles: [] }`
  - `computeMeters(state, data)`:
    - happiness (0–100): base 50; +20 if ≥70% of venue-event-weight is within WALK_RADIUS of an OPEN fountain; +20 same for toilets; +15 if >80% of trees uncut; shade bonus +15: sum of crownM of uncut trees within 150m of any venue ≥ some threshold (e.g. 200m total crown → scaled); −10 if any tree cut within 50m of a venue. Clamp 0–100. (Open fountain/toilet = not subject to a `close` decision.)
    - attendance (0–100): per venue, reachable = venue has shuttle in SHUTTLE_RADIUS OR a transit-friendly default (venue within 200m of another venue counts); base attendance 40; + up to 60 proportional to eventWeight-covered venues being reachable. Clamp.
    - money (0–100): `net = state.budget − costs(decisions) + attendance_fraction × 20000 × VISITOR_SPEND/35` scaled: `100 × net / (START_BUDGET + 20000)`.
  - Keep all sub-scores in named helper functions (`coverageScore`, `shadeScore`, `reachabilityScore`, `moneyScore`) so they can be unit-tested and tweaked live during the demo prep.
- [ ] **Step 4:** Run `node --test test/score.test.js` → PASS. Add one more test: budget math (two decisions with costs reduce money meter). Run → PASS.
- [ ] **Step 5:** Commit PR `feat: three-meter scoring`.

### Task 5: game.js — day machine & decisions (Track B)

**Files:** Modify: `game/js/game.js`

**Interfaces:**
- Consumes: `score.js` (state + meters), `data.js` shapes.
- Produces: `createGame(data, onChange)` per contract.

- [ ] **Step 1:** Implement `createGame`: internal `state = createGameState()`; `onChange(state, meters)` fired after every mutation (meters via `computeMeters(state, data)`).
- [ ] **Step 2:** Implement day themes: `dayTheme()` returns `{ title, focus, decisionsHint }` from a const map: 1 → Anreise/Mobilität, 2 → Höhepunkt/Sanitär & Wasser, 3 → Hitzetag/Schatten & Bäume.
- [ ] **Step 3:** Implement decision catalogue `availableDecisions(entity)`: tree → `[{id:'keep',label:'Stehen lassen',cost:0},{id:'prune',label:'Zurückschnitten',cost:150},{id:'cut',label:'Fällen',cost:400}]`; fountain/toilet → `[{id:'keep',...},{id:'relocate',label:'Verlegen',cost:800},{id:'close',label:'Schließen',cost:0}]`; venue → `[{id:'shuttle',label:'Shuttle-Haltestelle einrichten',cost:1200, addsShuttle:true}]`; street → `[{id:'close',label:'Für Fußgänger sperren',cost:300},{id:'open',...}]`. Filter by day focus: day1 streets/venues only, day2 fountains/toilets, day3 trees (+ any type allowed, focus only changes weights/hints).
- [ ] **Step 4:** Implement `decide(decisionId)`: find pending entity (last clicked via `clickEntity(id,type)`), append `{entityId, entityType, decisionId, day, cost}` to `state.decisions`, subtract cost from `state.budget`, if `addsShuttle` push venue coords to `state.shuttles`, fire `onChange`. Idempotent: same entity+decision twice → no-op.
- [ ] **Step 5:** Implement `nextDay()`: `state.day = Math.min(3, day+1)`, fire `onChange`.
- [ ] **Step 6:** Manual check via `node -e` import: create game with DATA from task 4, click tree, decide('cut'), assert budget reduced and onChange fired. Commit PR `feat: day machine and decisions`.

### Task 6: voices.js — proxy client (Track C)

**Files:** Modify: `game/js/voices.js`

**Interfaces:** Produces `ask(messages, maxTokens)` per contract.

- [ ] **Step 1:** Implement `ask`: POST `http://127.0.0.1:8377/v1/chat/completions`, body `{messages, max_tokens: maxTokens}`, 8s `AbortController` timeout; on network error/timeout throw `Error('PROXY_DOWN')` (exact code — dialogue.js depends on it); on HTTP error include status in message.
- [ ] **Step 2:** Start `python3 mistral-proxy/server.py` (keys.json exists on this machine), then verify with `node -e` dynamic import calling `ask([{role:'user',content:'Sag OK'}],50)` prints "OK". Stop proxy.
- [ ] **Step 3:** Commit PR `feat: proxy client`.

### Task 7: dialogue.js — persona engine (Track C)

**Files:** Create: `game/data/fallback_voices.json`, Modify: `game/js/dialogue.js`

**Interfaces:**
- Consumes: `ask()` from voices.js; entity shapes from data.js; game state for context.
- Produces: `startDialogue`, `sendUserMessage` per contract.

- [ ] **Step 1:** Write persona builder: system prompt template (German): "Du bist {name}, ein {type} in Linz im Jahr 2026... Sprich in der ersten Person, ernsthaft, leicht poetisch, maximal 3 Sätze. Fakten: {facts}. Du verhandelst mit dem/der Bürgermeister:in über: {dayFocus}." Facts per type: tree → species, ageEstimate (or 'unbekannt'), crownM; street → history (first 300 chars); venue → name, events; fountain/toilet → name, day-2 role.
- [ ] **Step 2:** Implement `startDialogue(entity)`: returns `{entity, history: [{role:'system',content:persona}], turns: 0}` + opening line: call `ask(history)` once (maxTokens 150) to greet; on PROXY_DOWN → pick fallback line from `fallback_voices.json[entity.type]` (cyclic).
- [ ] **Step 3:** Implement `sendUserMessage(game, dlg, text)`: push user msg, `reply = ask(history)`; append; parse intent: if text or reply contains `[[ENTSCHEID:decisionId]]` marker strip it and return `{reply: cleaned, intent:{type:'decide',decisionId}}`; support `[[TAG_X]]`/`[[NAECHSTER_TAG]]` similarly. On PROXY_DOWN return fallback line + `intent: null`.
- [ ] **Step 4:** Generate `fallback_voices.json`: while proxy works, run a small script `tools/gen_fallback_voices.py` that calls the proxy for one generic persona per entity type (tree/street/venue/fountain/toilet), 4 variants each, save to `game/data/fallback_voices.json`. Commit the JSON (cheap, static).
- [ ] **Step 5:** Manual check in browser console: start proxy, open app, import dialogue.js, run a full exchange with a tree entity. Commit PR `feat: persona dialogue engine`.

### Task 8: ui.js + wiring (Track C, final integration)

**Files:** Modify: `game/js/ui.js`, `game/js/main.js`, `game/style.css`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1:** Implement `renderMeters(meters)`: three labeled bars (Besucher, Geld, Zufriedenheit) in `#meters`, width %, live update via game `onChange`.
- [ ] **Step 2:** Implement `renderDay(theme, day)`: title + focus line in `#day-display`, plus "Nächster Tag" button (calls `game.nextDay()`, hidden on day 3 → shows final verdict overlay with the three meters + mayor title quadrant, e.g. `attendance>66 && money>66 && happiness>66` → "Volksnahe:r Stadtplaner:in").
- [ ] **Step 3:** Implement chat panel: click entity (map callback) → `openChat(entity)`: header with entity name/type, message list, input box, decision buttons from `game.availableDecisions(entity)` as quick chips; chips append `[[ENTSCHEID:id]]` to the sent message; incoming intents call `game.decide(decisionId)` and `map.setEntityState(id,'resolved')`.
- [ ] **Step 4:** Wire `main.js`: `const data = await loadAll('data/'); const map = initMap('map', data, onEntity); const game = createGame(data, (s,m)=>{renderMeters(m); renderDay(game.dayTheme(), s.day);});` + glue to chat.
- [ ] **Step 5:** Full demo run: start proxy + http server, play day 1–3 in browser (shuttle at AEC, relocate a toilet, spare a tree), confirm meters move, verdict shows. Screenshot for the pitch deck.
- [ ] **Step 6:** Update root README quick-start with run instructions. Commit PR `feat: full game wiring`.

### Task 9 (stretch, only if ahead): live air quality + English toggle

**Files:** Modify: `tools/` (cache script), `game/js/score.js`, `game/js/ui.js`

- [ ] Cache `data/linz/luftguete-messwerte` API once into `game/data/airquality.json` (script in tools/), Day-3 happiness ±10 by PM10 level.
- [ ] `?lang=en` query param: entity names EN from festival dataset, UI strings dict.

---

## Self-review notes

- Spec coverage: concept/loop (T5,T8), 3 days (T5), dialogue personas (T7), three meters (T4), data sources (T1), architecture & modules (T0–T8), error handling/fallback voices (T6,T7), MVP scope (task set = MVP; stretch isolated in T9). Out-of-scope items intentionally absent.
- Type consistency: all cross-task references use the Shared Interfaces block verbatim (`ask`, `computeMeters`, `initMap`, decision shapes).
- Known simplifications (deliberate): street/venue day-1 decisions are coarse; attendance reachability defaults to venue clustering — good enough for honest demo numbers, all constants visible in UI.
