# Playtest checklist — Bürgermeister:in fürs Festival

Scripted run for the pit crew and the pitch rehearsal. Every expected value below was computed
with the real game logic (`GameState`) on the committed data — if a meter differs by more than
±1, stop and report it (screenshot + which step).

Meters are shown as **Besucher:innen / Geld / Zufriedenheit** (rounded, 0–100).
Values assume the committed air-quality cache (S184 Stadtpark, PM10 6.7 → **+10 happiness on
day 3**). Balance as of #64 (P1: previews, no "keep", planting) + #67 (gold at average 69); both routes below are
also played by `test_real_data_endings`, so if the suites are green the numbers hold.

**Do not re-run `tools/fetch_airquality.py` before the pitch** — the top endings need the cached clean-air reading.

## 0. Setup

| Mode | Command | Expect |
|---|---|---|
| Release binary | `cd game/godot && godot --headless --path . --export-release "Linux" build/buergermeister.x86_64` then `./build/buergermeister.x86_64` | window opens on the start menu |
| Binary self-check | `./build/buergermeister.x86_64 --headless -- --smoke-test` | `SMOKE OK venues=20 trees=400 fountains=38 toilets=41 streets=18 airquality=true markers=517 …`, exit 0 |
| Editor fallback | open `game/godot/project.godot` in Godot 4.7.2, press F5 | same start menu |
| Live voices (optional) | `python3 mistral-proxy/server.py`, check `curl -s http://127.0.0.1:8377/health` | without the proxy the chat says **"Offline-Stimme"** — the game still works fully |

## 1. Start menu

- [ ] Title "Bürgermeister:in fürs Festival", buttons **Festival starten**, **So funktioniert das Spiel**, **Beenden**.
- [ ] **Festival starten** → map + panels; the chat opens **Ars Electronica Center** automatically.
- [ ] Meters **45 / 75 / 65**, **Budget: 14.000 €**, "Tag 1 — Anreise", pricing row with **Standard** highlighted.
- [ ] Every decision chip shows its impact, e.g. AEC: "Shuttle-Haltestelle einrichten ≈ +3.4 Bes · −1.800 €".

## 2. Demo route (ends "Volksnahe Stadtplanung")

Hover a marker to read its name; street markers are grey. **Each day press "Faire Preise" first** — the day bar
resets to Standard on a new day and the meters dip until you do.

| # | Day | Click | Chip preview (approx.) | Meters after (Bes / Geld / Zuf) | Budget |
|---|---|---|---|---|---|
| 1 | 1 | **OK Platz** → *Shuttle-Haltestelle einrichten* | ≈ +9.1 Bes · −1.800 € | 54 / 72 / 65 | 12.200 € |
| 2 | 1 | street **Hauptplatz** → *Für Fußgänger sperren* | ≈ −1.0 Zuf · +2.8 Bes · −300 € | 57 / 72 / 64 | 11.900 € |
| 3 | 1 | day bar **Faire Preise** | — | 63 / 67 / 64 | 11.900 € |
| 4 | 2 | **Nächster Tag →**, then **Faire Preise** | — | 63 / 67 / 64 | 11.900 € |
| 5 | 2 | street **Mozartstraße** → *Für Fußgänger sperren* | ≈ −1.0 Zuf · +3.6 Bes · −300 € | 67 / 68 / 63 | 11.600 € |
| 6 | 2 | purple toilet **Promenade** → *Schließen* | ≈ −0.8 Zuf · +300 € | 67 / 69 / 62 | 11.900 € |
| 7 | 3 | **Nächster Tag →**, then **Faire Preise** (clean air +10 Zuf) | — | 67 / 69 / 72 | 11.900 € |
| 8 | 3 | green tree next to the **Mariendom** (chat title "Platanus hispanica") — talk, **don't cut** | chips: Zurückschneiden / Fällen | 67 / 69 / 72 | 11.900 € |
| 9 | 3 | **Ars Electronica Center** → *Sperrstunde verlängern* | ≈ −3.0 Zuf · +2.0 Bes · −600 € | 69 / 68 / 69 | 11.300 € |

- [ ] Toilet "Promenade" stays clickable after closing (a *Wieder öffnen / 100 €* chip appears); the tree locks only if you trim or cut it.
- [ ] Pressing a chip that is no longer possible shows "Diese Entscheidung ist nicht verfuegbar." and changes nothing.

## 3. Verdict (demo route)

- [ ] **Abschluss** → "Drei Tage Linz", **Gesamtnote: 68 / 100**, title **Volksnahe Stadtplanung**.
- [ ] Subtitle: *"Die Platane nahe Mariendom durfte bleiben. / Ein Shuttle fuhr zum OK Platz. / Am Hitzetag galten faire Preise."*
- [ ] Final meters 69 / 68 / 69, "8 Entscheidungen / Restbudget: 11300 EUR".
- [ ] After the verdict, map clicks, chips and the day bar change nothing.

## 4. Showcase variant (ends "Goldene:r Bürgermeister:in")

Same as §2, but on **day 2** after step 6 also:
- fountain **"Südbahnhof gegenüber RZK Gebäude"** → *Verlegen* (≈ +3.2 Zuf · −800 €) → 67 / 65 / 66, 10.800 €
- fountain **"Hauptplatz südliche Grüninsel"** → *Schließen* (≈ −0.8 Zuf · +300 €)
- (order with the toilet doesn't matter) → after all three: 67 / 67 / 64, 11.400 €

and on **day 3** skip step 9 (no curfew extension): 67 / 67 / 74 → **Gesamtnote 69 / 100**, **Goldene:r Bürgermeister:in**, "9 Entscheidungen / Restbudget: 11400 EUR".

## 5. Restart

- [ ] **Neues Festival** → start menu → **Festival starten** → day 1, 45 / 75 / 65, Budget 14.000 €, no decisions, Standard pricing.

## 6. Optional checks

- [ ] Planting: AEC → *Baum pflanzen* (≈ +1.4 Zuf · −300 €) three times; a fourth is refused; young trees appear next to the AEC.
- [ ] Headline purchases: AEC → *Foodtruck bestellen* ≈ +0.8 Zuf · +0.5 Bes · −500 €; status "Foodtrucks 3/4 · Security 2/4".
- [ ] Cutting the Mariendom plane tree instead: chip shows ≈ −13.7 Zuf · −400 € (attendance gain from the cleared space is below 0.5, so hidden); subtitle then reads "Die Platane nahe Mariendom wurde gefällt."
- [ ] Other endings (fast): cut the two trees `baum_1b51840024c31e2584c5` and `baum_22b431ea60149d6bee10` on day 3 → **Effizienz-Tyrann:in**; shuttle at splace + fair prices all three days → **Solide Verwaltung**.

## Report template

```
Build: binary | editor     Voices: live | offline     Tester:
Step | expected | seen | screenshot
```

Anything that differs, crashes, or reads oddly in German → issue with label `playtest`, and tell Opus (Track B)
for meters/endings. **Balance feedback ("feels too easy / pointless / expensive") is the input for the next
tuning pass — write down how it felt, not just the numbers.**
