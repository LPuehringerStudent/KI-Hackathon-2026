# Demo-Skript (3 Minuten, Deutsch)

Demo-Route aus `docs/playtest-checklist.md` §2 (Bürgeranliegen-Route) — alle Zahlen dort nachgerechnet und von `test_real_data_endings` geprüft.
Anzeige: **Besucher:innen / Geld / Zufriedenheit**. Luftgüte-Cache: PM10 6,7 (+10 am Hitzetag).

**Vorher (Pit Crew):** Binary starten (`./build/buergermeister.x86_64`) *oder* Editor + F5.
Proxy optional (`python3 mistral-proxy/server.py`) — ohne Proxy antworten die Offline-Stimmen,
das Spiel läuft trotzdem vollständig. Bildschirm auf 1600×900 oder größer.

| Zeit | Aktion | Sprechtext |
|---|---|---|
| 0:00 | Startmenü | „Stellt euch vor, ihr seid Bürgermeister:in von Linz — und morgen beginnt das Ars Electronica Festival. Tausende kommen. Die Stadt muss das tragen." |
| 0:15 | **Festival starten** | „Linz als Miniatur aus offenen Daten. Drei Werte oben — und jeden Tag meldet sich die Stadt mit einem Anliegen." *(45 / 75 / 65)* |
| 0:30 | Anliegen vorlesen | „Tag eins: *Lentos Kunstmuseum — wie kommen die Gäste her?* Das Lentos hängt an keiner anderen Spielstätte." |
| 0:40 | **Lentos** → *Shuttle* | „Also ein Shuttle. Der Button sagt vorher, was es bringt: vier Besucherpunkte, 1.800 Euro — und zwei Punkte Zufriedenheit, weil wir zugehört haben. Das Anliegen wird grün." *(49 / 74 / 67)* |
| 1:00 | **OK Platz** → *Shuttle*, **Hauptplatz** → *Fußgänger*, **Faire Preise** | „Noch ein Shuttle für den OK-Platz-Cluster, der Hauptplatz wird Fußgängerzone, faire Preise für alle." *(67 / 66 / 66)* |
| 1:20 | **Nächster Tag**, **Faire Preise** | „Tag zwei: *Beim C. Bechstein Centrum fehlt eine Toilette.*" |
| 1:30 | Toilette **Stadtpark Huemerstraße** → *Verlegen* | „Diese Toilette steht, wo niemand feiert — wir verlegen sie dorthin, wo sie fehlt. Anliegen zwei erfüllt, plus Förderung." *(67 / 67 / 70)* |
| 1:45 | Toilette **Promenade** → *Schließen* | „Und eine doppelt versorgte sperren wir: 300 Euro zurück." *(67 / 68 / 69)* |
| 2:00 | **Nächster Tag**, **Faire Preise** | „Tag drei, Hitzetag: saubere Luft laut Messstation — und die Stadt bittet um Schatten fürs Ars Electronica Center." *(67 / 68 / 79)* |
| 2:10 | Baum am **Mariendom** anklicken | „Erst spricht die Platane am Mariendom. Fällen würde Platz schaffen, kostet aber fast vierzehn Punkte. Wir lassen sie stehen." |
| 2:25 | **AEC** → *Baum pflanzen* | „Stattdessen pflanzen wir. Ein Baum reicht noch nicht — die Vorschau zeigt: der zweite bringt drei Punkte, weil er das Anliegen erfüllt." *(67 / 67 / 81)* |
| 2:40 | **Abschluss** | „Gesamtnote 72, **Volksnahe Stadtplanung**, zwei von drei Anliegen erfüllt — und das Spiel erzählt es: *Die Platane nahe Mariendom durfte bleiben.* Mit dem zweiten Baum wären wir golden gewesen." |
| 2:55 | Urteil stehen lassen | „Echte Daten, ein ehrliches Modell, und eine Stadt, die zurückredet. Danke!" |

Showcase für Fragen (20 s): den zweiten Baum am AEC pflanzen → **67 / 70 / 84**, Gesamtnote 74,
**Goldene:r Bürgermeister:in**, „3 von 3 Bürgeranliegen erfüllt".

## Wenn etwas schiefgeht

- **Stimme hängt / Proxy weg:** weiterreden, Entscheidungs-Buttons nutzen — Status „Offline-Stimme" ist ok.
- **Binary startet nicht:** Editor öffnen, F5. Vorab prüfen: `./build/buergermeister.x86_64 --headless -- --smoke-test` → `SMOKE OK`.
- **Werte weichen ab (> ±1):** nicht improvisieren — Zahlen weglassen, Richtung erzählen („mehr Besucher:innen, weniger Geld").
- **Falscher Klick:** Bäume sperren nach Zurückschneiden/Fällen, Toiletten nach dem Verlegen; geschlossene lassen sich *wieder öffnen*. Die Vorschau auf jedem Button zeigt vorher, was passiert. Notfalls **Abschluss** → **Neues Festival**.
- **Preise vergessen:** Jeden Tag zuerst **Faire Preise** drücken — der Tag beginnt auf Standard.

## Kurzfassung für Fragen

- **Warum KI?** Die Stimmen machen Daten erlebbar; Entscheidungen werden trotzdem nur über geprüfte IDs übernommen — das Modell kann nichts „erfinden".
- **Warum diese Zahlen?** Alle Annahmen sind benannte Konstanten; wir haben per Simulation tausende Entscheidungsfolgen auf den echten Daten durchgerechnet, damit kein einzelner Klick gewinnt und Nichtstun neutral bleibt.
- **Offline?** Ja — Karte, Daten und Ersatzstimmen liegen lokal.
