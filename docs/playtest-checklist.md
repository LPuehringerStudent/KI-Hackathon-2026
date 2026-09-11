# Playtest checklist — Bürgermeister:in fürs Festival

Scripted run for the pit crew and the pitch rehearsal. Every expected value below was computed
with the real game logic (`GameState`) on the committed data — if a meter differs by more than
±1, stop and report it (screenshot + which step).

Meters are shown as **Besucher:innen / Geld / Zufriedenheit** (rounded, 0–100).
Values assume the committed air-quality cache (S184 Stadtpark, PM10 6.7 → **+10 happiness on
day 3**). Balance as of #41 (mentor pack) + #46 (verdict tiers); UI as of #45 (live budget, Gesamtnote).

## 0. Setup

| Mode | Command | Expect |
|---|---|---|
| Release binary | `cd game/godot && godot --headless --path . --export-release "Linux" build/buergermeister.x86_64` then `./build/buergermeister.x86_64` | window opens on the start menu |
| Binary self-check | `./build/buergermeister.x86_64 --headless -- --smoke-test` | `SMOKE OK venues=20 trees=400 fountains=38 toilets=41 streets=18 airquality=true markers=517 …`, exit 0 |
| Editor fallback | open `game/godot/project.godot` in Godot 4.7.2, press F5 | same start menu |
| Live voices (optional) | `python3 mistral-proxy/server.py`, check `curl -s http://127.0.0.1:8377/health` | without the proxy the chat says **"Offline-Stimme"** — the game still works fully |

## 1. Start menu

- [ ] Title "Bürgermeister:in fürs Festival", buttons **Festival starten**, **So funktioniert das Spiel**, **Beenden**.
- [ ] "So funktioniert das Spiel" toggles the help text.
- [ ] **Festival starten** → map + panels appear; the chat opens **Ars Electronica Center** automatically.
- [ ] Meters: **45 / 75 / 65**, below them **Budget: 14.000 €**. Day bar: "Tag 1 — Anreise", "Mobilität", "Wo sollen Shuttle fahren?". Pricing row "Ticketpreise heute" with **Standard** highlighted.

## 2. Day 1 — shuttle at the Ars Electronica Center

- [ ] The AEC persona greets you (live voice, or a canned line with status "Offline-Stimme").
- [ ] Chips at AEC: Shuttle-Haltestelle einrichten / 1800 EUR, Sperrstunde verlängern / 600, Sperrstunde einhalten / 0, Foodtruck bestellen / 500, Security-Team buchen / 400.
- [ ] Press **Shuttle-Haltestelle einrichten** (or type "Richte bitte einen Shuttle ein." with live voices).
- [ ] Chat logs "Entscheidung — Shuttle-Haltestelle einrichten / 1800 EUR"; status "Foodtrucks 2/4 · Security 2/4".
- [ ] Meters: **49 / 69 / 65** (attendance +3.4, money −5.3), **Budget: 12.200 €**.
- [ ] A shuttle marker appears at the AEC; the AEC stays clickable (venues never lock).
- [ ] Pressing the shuttle chip again → status "Diese Entscheidung ist nicht verfuegbar.", meters unchanged.
- [ ] **Variant B (for the "Solide Verwaltung" ending):** click **OK Platz**, press the shuttle chip → **58 / 67 / 65**, **Budget: 10.400 €**.

## 3. Day 2 — relocate a toilet

- [ ] Press **Nächster Tag →** → "Tag 2 — Höhepunkt", "Sanitär & Wasser". Meters unchanged.
- [ ] Click the purple toilet marker **"Stadtpark Huemerstraße"** (hover: the tooltip shows the toilet's name).
- [ ] Press **Verlegen / 800 EUR**.
- [ ] Meters: **49 / 66 / 67**, Budget 11.400 € (variant B: **58 / 64 / 67**, 9.600 €) — happiness +2.4 because the toilet moves to the C. Bechstein Centrum, the biggest venue without one.
- [ ] Chat shows "Entscheidung festgehalten."; the toilet marker turns grey and is disabled (services lock after one decision).

## 4. Day 3 — the plane tree at the Mariendom

- [ ] Press **Nächster Tag →** → "Tag 3 — Hitzetag", "Schatten & Bäume".
- [ ] Happiness jumps by **+10** from clean air: **49 / 66 / 77** (variant B: **58 / 64 / 77**).
- [ ] Click the green tree marker right next to the **Mariendom** (≈50 m; tooltip `baum_53e4b829…`) — the chat title reads **"Platanus hispanica"**.
- [ ] **Keep:** press **Stehen lassen / 0 EUR** → **49 / 66 / 78** (listen bonus +1). Variant B: **58 / 64 / 78**.
- [ ] **Or cut (second run):** press **Fällen / 400 EUR** → **49 / 65 / 68** (−9.7: shade lost, tree at a venue). Variant B: **58 / 62 / 68**.

## 5. Verdict

- [ ] Press **Abschluss** → overlay "Drei Tage Linz", big **"Gesamtnote: N / 100"** (mean of the three meters), the title, the three final meters and "N Entscheidungen / Restbudget: … EUR".

| Run | Final meters | Gesamtnote | Title | Restbudget |
|---|---|---|---|---|
| A + keep | 49 / 66 / 78 | 64 | **Stadt im Gleichgewicht** | 11 400 EUR |
| A + cut | 49 / 65 / 68 | 60 | **Stadt im Gleichgewicht** | 11 000 EUR |
| B + keep | 58 / 64 / 78 | 67 | **Solide Verwaltung** | 9 600 EUR |
| B + cut | 58 / 62 / 68 | 63 (mean 62.51) | **Solide Verwaltung** | 9 200 EUR |

- [ ] After the verdict, clicks on the map, chips and the day bar change nothing.

## 6. Restart

- [ ] **Neues Festival** → start menu again → **Festival starten** → day 1, **45 / 75 / 65**, Budget 14.000 €, no decisions, pricing back on **Standard**.

## 7. Optional extras (mentor pack)

- [ ] Fresh game, AEC **Foodtruck bestellen** once → **46 / 73 / 66**, status "Foodtrucks 3/4 · Security 2/4", venue badge shows the unit counts.
- [ ] Fresh game, day bar **Premium** on day 1 → **40 / 83 / 65**; **Standard** again restores 45 / 75 / 65.
- [ ] A 6th food truck at the same venue is refused (max 5 per venue).

## Report template

```
Build: binary | editor     Voices: live | offline     Tester:
Step | expected | seen | screenshot
```

Anything that differs, crashes, or reads oddly in German → issue with label `playtest`, and tell Opus
(Track B) for meters/endings. **Balance feedback ("feels too easy / pointless / expensive") is the
input for the next tuning pass — please write down how it felt, not just the numbers.**
