# Playtest checklist — Bürgermeister:in fürs Festival

Scripted run for the pit crew and the pitch rehearsal. Every expected value below was computed
with the real game logic (`GameState`) on the committed data — if a meter differs by more than
±1, stop and report it (screenshot + which step).

Meters are shown as **Besucher:innen / Geld / Zufriedenheit** (rounded, 0–100).
Values assume the committed air-quality cache (S184 Stadtpark, PM10 6.7 → **+10 happiness on
day 3**). Balance as of the security risk model (Round 8): from **day 2 on, every venue whose crowd
is understaffed causes an incident** — that is the pressure the route answers. Both routes below are
also played by `test_real_data_endings`, so if the suites are green the numbers hold.

**Do not re-run `tools/fetch_airquality.py` before the pitch** — the top endings need the cached clean-air reading.

## 0. Setup

| Mode | Command | Expect |
|---|---|---|
| Full gate (~1 min) | `tools/check.sh` | imports the assets, runs every suite and the smoke test, ends with `ALL GREEN` |
| Release binary | `tools/build_game.sh` then `game/godot/build/buergermeister.x86_64` | window opens on the start menu. Use the script, not a bare `--export-release`: it refreshes the asset import cache first, and a stale one drops the 3D props |
| Binary self-check | `./build/buergermeister.x86_64 --headless -- --smoke-test` | `SMOKE OK venues=20 … markers=517 map_texture=true meters=true models=true`, exit 0. `models=false` means the boats lost their .glb — re-run `tools/build_game.sh` |
| Editor fallback | open `game/godot/project.godot` in Godot 4.7.2, press F5 | same start menu |
| Live voices (optional) | `python3 mistral-proxy/server.py`, check `curl -s http://127.0.0.1:8377/health` | without the proxy the chat says **"Offline-Stimme"** — the game still works fully |

## 1. Start menu

- [ ] **Festival starten** → map + panels; the chat opens **Ars Electronica Center**.
- [ ] Meters **50 / 77 / 68**, **Budget: 14.000 €**, "Tag 1 — Anreise".
- [ ] Day panel shows today's wish: **○ Anliegen: Lentos Kunstmuseum: Wie kommen die Gäste her?** (Eine Shuttle-Haltestelle in 250 m Umkreis).
- [ ] Every chip shows its impact, e.g. at the AEC "Shuttle-Haltestelle einrichten ≈ +3.4 Bes · −1.800 €".

## 2. Demo route — answer the city (ends "Volksnahe Stadtplanung")

Each day press **Faire Preise** (the day bar resets to Standard). Hover a marker to read its name.

| # | Day | Click | Chip preview | Meters after | Budget | Wish |
|---|---|---|---|---|---|---|
| 1 | 1 | **Lentos Kunstmuseum** → *Shuttle-Haltestelle einrichten* | ≈ +2.0 Zuf · +4.0 Bes · −1.800 € | 54 / 76 / 70 | 12.200 € | **✓ Tag 1** |
| 2 | 1 | **OK Platz** → *Shuttle-Haltestelle einrichten* | ≈ +9.1 Bes · −1.800 € | 63 / 73 / 70 | 10.400 € | ✓ |
| 3 | 1 | street **Hauptplatz** → *Für Autos sperren* | ≈ −1.0 Zuf · +2.8 Bes · −300 € | 66 / 73 / 69 | 10.100 € | ✓ |
| 4 | 1 | day bar **Faire Preise** | ≈ +6.6 Bes · −4.6 Geld | 73 / 69 / 69 | 10.100 € | ✓ |
| 5 | 2 | **Nächster Tag →** — chat status **"⚠ Vorfall am Ars Electronica Center: zu wenig Security für die Menge."** | — | **64 / 69 / 59** | 10.100 € | ○ |
| 6 | 2 | **Faire Preise** — new wish: *C. Bechstein Centrum Linz: keine Toilette in Gehweite.* | ≈ +3.1 Bes · −2.3 Geld | 67 / 66 / 59 | 10.100 € | ○ |
| 7 | 2 | toilet **Stadtpark Huemerstraße** → *Verlegen* | ≈ +4.4 Zuf · −800 € | 67 / 67 / 63 | 9.300 € | **✓ Tag 2** |
| 8 | 2 | toilet **Promenade** → *Schließen* | ≈ −0.8 Zuf · +300 € | 67 / 68 / 63 | 9.600 € | ✓ |
| 9 | 2 | **Ars Electronica Center** → *Security-Team buchen* | ≈ +1.1 Zuf · +0.5 Bes · −400 € | 68 / 67 / 64 | 9.200 € | ✓ |
| 10 | 2 | **OK Platz** → *Security-Team buchen* | ≈ +1.1 Zuf · +0.5 Bes · −400 € | 68 / 66 / 65 | 8.800 € | ✓ |
| 11 | 3 | **Nächster Tag →** (clean air +10 Zuf) — wish: *Ars Electronica Center: kein Schatten für den Hitzetag.* | — | 66 / 67 / 75 | 8.800 € | ○ |
| 12 | 3 | **Faire Preise** | ≈ +2.1 Bes · −1.5 Geld | 68 / 66 / 75 | 8.800 € | ○ |
| 13 | 3 | tree at the **Mariendom** (chat title "Platanus hispanica") — talk, **don't cut** | — | 68 / 66 / 75 | 8.800 € | ○ |
| 14 | 3 | **Ars Electronica Center** → *Baum pflanzen* | ≈ +1.4 Zuf · −300 € | 68 / 65 / 76 | 8.500 € | ○ (needs 2) |
| 15 | 3 | **Ars Electronica Center** → *Baum pflanzen* (again) | ≈ +3.4 Zuf · −300 € | 68 / 67 / 80 | 8.200 € | **✓ Tag 3** |

- [ ] Step 5 is the drama beat: the day-2 crowds arrive unguarded, **Zufriedenheit drops ~10 and
      Besucher:innen ~9** — that is the risk model, not a bug. The two security teams (steps 9–10)
      buy a third of it back for 800 €; the map's Sicherheit layer turns the guarded venues down.
- [ ] The wish line flips to **✓** the moment it is met, and the chat says "Anliegen erfüllt: …".
- [ ] A fulfilled wish pays **+2 Zufriedenheit and a 1.000 € Förderung** — visible in the chip preview of the deciding click.

## 3. Verdict (demo route)

- [ ] **Abschluss** → **Gesamtnote: 72 / 100**, title **Volksnahe Stadtplanung**, line **"3 von 3 Bürgeranliegen erfüllt"**.
- [ ] Subtitle: *"Die Platane nahe Mariendom durfte bleiben. / 2 neue Bäume wurden gepflanzt. / 2 Security-Teams an 2 Spielstätten."*
- [ ] Final meters 68 / 67 / 80, "12 Entscheidungen / Restbudget: 8200 EUR".

## 4. Showcase: the curfew trade (ends "Goldene:r Bürgermeister:in")

- [ ] Same route, then **Ars Electronica Center → *Sperrstunde verlängern*** → chip shows **≈ −1.0 Zuf · +3.0 Bes · −400 €**.
      With both security teams in place the longer night pays: the extra reach outweighs the
      happiness hit only at a big, guarded venue (at **Powerplayground** the same chip is a net loss).
- [ ] Final **71 / 67 / 79**, **Gesamtnote 72**, **Goldene:r Bürgermeister:in**, "13 Entscheidungen / Restbudget: 7800 EUR".

## 5. Restart

- [ ] **Neues Festival** → day 1, 50 / 77 / 68, Budget 14.000 €, wish back to ○, no incident status line.

## 6. Optional checks

- [ ] Doing **nothing at all** ends on **Stadt im Gleichgewicht** (46 / 75 / 68) — the day-2 incidents cost
      the passive city ~10 Zufriedenheit, and only the clean-air day (+10) pulls it back to neutral.
- [ ] Buying security at a **small** venue (e.g. Powerplayground, "Erwartete Gäste: ~200") barely moves a meter —
      its crowd is below the incident threshold. That is intended: guard the big stages first.
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
