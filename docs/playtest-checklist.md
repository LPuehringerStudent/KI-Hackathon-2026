# Playtest checklist — Bürgermeister:in fürs Festival

Scripted run for the pit crew and the pitch rehearsal. Every expected value below was computed
with the real game logic (`GameState`) on the committed data — if a meter differs by more than
±1, stop and report it (screenshot + which step).

Meters are shown as **Besucher:innen / Geld / Zufriedenheit** (rounded, 0–100).
Values assume the committed air-quality cache (S184 Stadtpark, PM10 6.7 → **+10 happiness on
day 3**). Balance as of #83 (Bürgeranliegen, gold at average 72); both routes below are
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

- [ ] **Festival starten** → map + panels; the chat opens **Ars Electronica Center**.
- [ ] Meters **45 / 75 / 65**, **Budget: 14.000 €**, "Tag 1 — Anreise".
- [ ] Day panel shows today's wish: **○ Anliegen: Lentos Kunstmuseum: Wie kommen die Gäste her?** (Eine Shuttle-Haltestelle in 250 m Umkreis).
- [ ] Every chip shows its impact, e.g. at the AEC "Shuttle-Haltestelle einrichten ≈ +3.4 Bes · −1.800 €".

## 2. Demo route — answer the city (ends "Volksnahe Stadtplanung")

Each day press **Faire Preise** (the day bar resets to Standard). Hover a marker to read its name.

| # | Day | Click | Chip preview | Meters after | Budget | Wish |
|---|---|---|---|---|---|---|
| 1 | 1 | **Lentos Kunstmuseum** → *Shuttle-Haltestelle einrichten* | ≈ +2.0 Zuf · +4.0 Bes · −1.800 € | 49 / 74 / 67 | 12.200 € | **✓ Tag 1** |
| 2 | 1 | **OK Platz** → *Shuttle-Haltestelle einrichten* | ≈ +9.1 Bes · −1.800 € | 58 / 71 / 67 | 10.400 € | ✓ |
| 3 | 1 | street **Hauptplatz** → *Für Fußgänger sperren* | ≈ −1.0 Zuf · +2.8 Bes · −300 € | 61 / 71 / 66 | 10.100 € | ✓ |
| 4 | 1 | day bar **Faire Preise** | — | 67 / 66 / 66 | 10.100 € | ✓ |
| 5 | 2 | **Nächster Tag →**, **Faire Preise** — new wish: *C. Bechstein Centrum Linz: keine Toilette in Gehweite.* | — | 67 / 66 / 66 | 10.100 € | ○ |
| 6 | 2 | toilet **Stadtpark Huemerstraße** → *Verlegen* | ≈ +4.4 Zuf · −800 € | 67 / 67 / 70 | 9.300 € | **✓ Tag 2** |
| 7 | 2 | toilet **Promenade** → *Schließen* | ≈ −0.8 Zuf · +300 € | 67 / 68 / 69 | 9.600 € | ✓ |
| 8 | 3 | **Nächster Tag →**, **Faire Preise** (clean air +10 Zuf) — wish: *Ars Electronica Center: kein Schatten für den Hitzetag.* | — | 67 / 68 / 79 | 9.600 € | ○ |
| 9 | 3 | tree at the **Mariendom** (chat title "Platanus hispanica") — talk, **don't cut** | — | 67 / 68 / 79 | 9.600 € | ○ |
| 10 | 3 | **Ars Electronica Center** → *Baum pflanzen* | ≈ +1.4 Zuf · −300 € | 67 / 67 / 81 | 9.300 € | ○ (needs 2) |

- [ ] The wish line flips to **✓** the moment it is met, and the chat says "Anliegen erfüllt: …".
- [ ] A fulfilled wish pays **+2 Zufriedenheit and a 1.000 € Förderung** — visible in the chip preview of the deciding click.

## 3. Verdict (demo route)

- [ ] **Abschluss** → **Gesamtnote: 72 / 100**, title **Volksnahe Stadtplanung**, line **"2 von 3 Bürgeranliegen erfüllt"**.
- [ ] Subtitle: *"Die Platane nahe Mariendom durfte bleiben. / Ein neuer Baum wurde gepflanzt. / Shuttles fuhren zu 2 Spielstätten."*
- [ ] Final meters 67 / 67 / 81, "9 Entscheidungen / Restbudget: 9300 EUR".

## 4. Showcase: the third wish (ends "Goldene:r Bürgermeister:in")

- [ ] Same route, then **one more** *Baum pflanzen* at the AEC → chip shows **≈ +3.4 Zuf · −300 €** (1.4 shade/greening **+ 2 wish reward**), wish flips to ✓.
- [ ] Final **67 / 70 / 84**, **Gesamtnote 74**, **Goldene:r Bürgermeister:in**, "3 von 3 Bürgeranliegen erfüllt", "10 Entscheidungen / Restbudget: 9000 EUR".

## 5. Restart

- [ ] **Neues Festival** → day 1, 45 / 75 / 65, Budget 14.000 €, wish back to ○.

## 6. Optional checks

- [ ] Ignoring all three wishes with similar effort ends on **Solide Verwaltung** (63 / 68 / 73) — the wishes are worth roughly one tier.
- [ ] A wish fulfilled late still counts (plant on day 1, the day-3 wish shows ✓ once day 3 starts).
- [ ] Cutting the Mariendom plane tree: ≈ −13.7 Zuf · −400 €; subtitle reads "… wurde gefällt."
- [ ] Other endings: cut `baum_1b51840024c31e2584c5` + `baum_22b431ea60149d6bee10` on day 3 → **Effizienz-Tyrann:in**; one shuttle at splace + fair prices → **Solide Verwaltung**.

## Report template

```
Build: binary | editor     Voices: live | offline     Tester:
Step | expected | seen | screenshot
```

Anything that differs, crashes, or reads oddly in German → issue with label `playtest`, and tell Opus
(Track B) for meters/wishes/endings. **Balance feedback ("feels too easy / pointless / expensive") is the
input for the next tuning pass — write down how it felt, not just the numbers.**
