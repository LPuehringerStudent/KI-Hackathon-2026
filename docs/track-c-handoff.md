# Track C Handoff

Current integration status: the playable offline flow passes, but the corrected
Track A extract exposes one Track B balance guard failure (wc_m20, -6.1 happiness
against a five-point limit). Reported on PR #20; do not merge until resolved.

## Ownership and source of truth

Track C owns scaffold #1, HTTP client #8, dialogue #9, panels #10, and integration
and build #11. Track A owns extraction, baking, data loading, and map behavior.
Track B owns scoring and day/decision logic. No Track A or B gameplay source was
rewritten for this implementation.

The Godot v2 implementation plan and its Shared Interfaces govern the integration.
The earlier browser plan is superseded. The revised design still contains older
browser wording and JSON-intent prose; this implementation follows the Godot
plan's desktop target and bracket markers. UI language is German.

## Repository exploration

Inspected AGENTS.md, CONTRIBUTING.md, README, the PR template, both architecture
documents, the proxy README and server, the Godot scaffold, team implementation
branches, relevant dataset READMEs, extracted metadata, and map rendering source.
Checked live GitHub issues #1-12 and PRs #13-20 before integration.

At discovery, the checkout was `feature/godot-scaffold` at `17381da`, with a clean
working tree. It contained one Control scene and one placeholder script. The
scene had a full-size RootSplit, MapSlot, and 380px PanelSlot with three labels.
The project referenced an absent icon.svg. There were no autoloads or local tests.
Scaffold PR #13 was open. All Track C issues remained open.

Upstream CONTRIBUTING now points at project board #11, replacing the older #10
link in AGENTS.md. Main was fetched, not modified or directly committed to.

### Integrated dependencies

| Branch | Commit | Existing PR | Content |
| --- | --- | --- | --- |
| feature/map-view | 92f0b15 | #19 | Export-safe map and metadata projection |
| feature/data-loader | 023046f | #18 | Data singleton, inherited via map branch |
| feature/extract-innenstadt | 8871fb6 | #14 | Corrected parent-venue event rollup and street positions |
| feature/bake-map | c7e192c | #16 | Baked PNG, texture import, projection constants |
| feature/meter-tuning | 6daeb46 | #20 | Scoring, decisions, and tests inherited from #15/#17 |

These are integration dependencies, not a claim that their upstream PRs have
received review approval. They were merged only on a feature branch. Review and
merge ordering still belong to the team.

The map branch carried an independently created scaffold. Resolved its add/add
conflicts by keeping Track C's RootSplit layout and registering Track A's Data
autoload. Removed the missing icon reference. Preserved the two independently
created test runners: Track B's suite runner remains run_tests.gd; Track A's
checks are available as run_data_tests.gd.

### Data observations

- Current game extract: 20 venues, 400 trees, 38 fountains, 41 toilets, 18 streets;
  517 markers in total. The initial snapshot had 15 venues and 512 markers.
- Raw street CSV has no coordinates. Track A's extract includes explicitly
  documented curated approximate positions; Track C does not fabricate positions.
- Tree age is an estimate from Track A, not a measured age. Persona prompts label
  it estimated and preserve unknown values.
- Service records are historical snapshots, not present-day operating guarantees.
- Map uses OSM geometry; on-screen attribution includes OSM, City of Linz, and
  festival data. See the source READMEs for licenses and vintage.
- Track B's tested tuning branch uses a 15000 EUR starting budget,
  whereas the original plan listed 50000. UI reads GameState rather than applying
  a competing constant. This upstream contract discrepancy needs team awareness.

## Track C implementation

### HTTP client (#8)

Voices is a Node autoload. `ask(messages, max_tokens := 400)` retains the shared
signature. Requests go to the fixed localhost proxy endpoint with the specified
Mistral model, bounded tokens, a 256 KiB response limit, and an eight-second
timeout. Calls serialize using a signal; successful completion clears last_error.
HTTP errors, transport errors, timeout, invalid JSON, unexpected response shapes,
and blank content return an empty string with PROXY_DOWN.

The next queued request starts deferred, so the current caller can inspect
last_error before the next request changes it. Tests use an overridden endpoint
in a test-only subclass and a local Python HTTP fixture, never real API keys.

### Dialogue (#9)

The shared start_dialogue and send_user_message signatures remain unchanged.
The entity is copied into a conversation with system/user/assistant history.
Opening context receives the current day from main; each later message refreshes
the day focus. Prompts contain only selected entity facts and that entity's
GameState decision catalogue. Street history is limited to 300 characters; user
messages to 2000. History remains bounded to the system prompt and nine pairs.

Only a single valid [[ENTSCHEID:id]] or [[NAECHSTER_TAG]] becomes an intent.
Unknown IDs, foreign entity decisions, multiple markers, and incomplete markers
do not mutate state. Markers are removed from displayed replies. Opening messages
never execute intents. Main applies accepted intents through GameState.

Four local fallback lines exist for each of five entity types. They rotate on
failure, never create an intent, and do not invent entity-specific measurements.
These initial lines were authored locally. A later proxy generation attempt returned
invalid JSON, so no unvalidated Mistral output was accepted.

tools/gen_fallback_voices.py health-checks the proxy, requests four lines per type
with max_tokens=500, validates all results, then writes the JSON only after every
type succeeds. Any failure preserves the existing fallback file. The generator
is the explicit fallback-data exception to the map/extraction-only data rule.

### Panels (#10)

Godot MCP created the meters, day, and chat scenes and their native child nodes.
The MCP script-attachment tool produced undeclared ExtResource references; these
were repaired with explicit declarations and verified by loading the scenes.

Panels expose set_meters, set_day, and open_entity. Three colored ProgressBars
show bounded numeric values. Chat uses a ScrollContainer, plain RichTextLabels,
LineEdit, send button, status, typing indicator, and a vertical decision list.
Long text wraps. The composer rejects blank input and blocks repeat submission
while waiting. Decision buttons remain usable during network waits and offline.
Once resolved, both composer and decisions are disabled for that entity.

### Wiring and build (#11)

Main loads Data and GameState, instances the existing map plus new panels, and
focuses Ars Electronica Center when available. Marker clicks choose typed records.
Selection, decision, day advance, and game completion invalidate pending dialogue
results. At most one voice request is active; rapid selection changes coalesce
into an opening for the latest unresolved entity.

Successful decisions refresh meters and map state. Nearby markers use Track B's
existing haversine helper within CONFIG.walk_radius; this is an additional
integration dependency beyond the minimum Shared Interfaces. Resolved entities
are disabled according to the map contract. Day three ends with a verdict and
restart button; completed games reject further mutations.

Verdicts, in precedence order: all meters >66 gives Volksnahe Stadtplanung;
money >66 and happiness <50 gives Effizienz-Tyrann:in; happiness >66 and money <50
gives Beliebt, aber pleite; attendance >66 gives Gastgeber:in der Stadt; otherwise
Stadt im Gleichgewicht.

The Linux x86_64 release embeds its pack. JSON is included and tests excluded.
The original map loader required the raw PNG; a packed-game run caught its omission
and Keep File initially fixed it. The final integration includes Track A's later
ResourceLoader-based fix and matching texture import instead. Projection constants
now also come from map_meta.json. No Track C map-script workaround remains.

## Tooling and Mistral status

Godot 4.7.2 standard Windows engine was downloaded from the official release into
tmp/godot/engine, with matching Linux/Windows templates installed locally. The
older preinstalled Godot 4.3 and inactive Windows python3 alias were not used.
Python 3.11 was found under the user's Local Programs directory.

Godot MCP filesystem operations work against this project. The live editor bridge
was unavailable in the existing MCP server because its engine path was not set.
No runtime or editor addon was added, respecting the no-addons constraint.
Engine import, tests, screenshots, and export were verified through the CLI.

Proxy health passes with locally configured keys. Direct Mistral and Godot autoload
smoke tests pass. The small fallback-generation task was delegated to Mistral, but
invalid JSON was rejected and the existing fallback file was preserved. Short
handoff and PR prose remain suitable proxy tasks. Architecture, parsing, code
integration, and debugging stayed on the main agent.

The proxy usage log contains credentials in its records. It is explicitly ignored
alongside keys.json and never used as prompt input or included in commits.

## Verification

Run the commands in README from the repository root. Tested with Godot
4.7.2.stable.official.ed1daf0bf on 2026-09-11.

| Check | Result |
| --- | --- |
| Headless import and main-scene launch | Exit 0 |
| Initial core and Track C suites | 40 tests passed on original extract |
| Current core and Track C suites | 39 passed, 1 Track B balance guard failed on corrected extract |
| Track A data/map checks | Passed; 517 markers |
| Actual HTTP fixture | Success, errors, timeout, malformed data, recovery, queue passed |
| Native panel checks | Meter bounds, final-day label, composer, decisions, plain text passed |
| Three-day integration | Native clicks, offline and simulated-online intents, stale replies, duplicate guards, verdict and restart passed |
| Desktop captures | 1600x900 and 1280x720 nonblank; measured panel overlaps 0 |
| Smaller window | Requested 1024x768; 16:9 canvas capture was 1024x576, overlaps 0 |
| Packed-game screenshot | Map and chat rendered from exported pack, overlaps 0 |
| Linux release | Export succeeded; executable started headlessly under WSL, exit 0 |

Screenshots are local artifacts under tmp/screenshots. The release is under
game/godot/build. Neither generated builds nor engine downloads are committed.

## Remaining human checks

- Resolve Track B's wc_m20 balance guard with the corrected extraction. Evidence:
  https://github.com/LPuehringerStudent/KI-Hackathon-2026/pull/20#issuecomment-5633110806
- Review the live Mistral exchange and regenerate fallback lines if desired. Direct
  and Godot smoke tests pass; generator output was rejected as invalid JSON.
- Check the release visually on the pitch laptop. WSL headless launch does not
  establish that machine's graphics, input, or screen layout.
- Review dependency PRs and the documented upstream budget/coordinate assumptions.
- Obtain one teammate approval before any merge to main. Task issues remain open
  until their corresponding review and acceptance steps are satisfied.
