# Demo-Skript (3 Minuten, Deutsch)

Demo-Route aus `docs/playtest-checklist.md` §2 (Bürgeranliegen-Route) — alle Zahlen dort nachgerechnet und von `test_real_data_endings` geprüft.
Anzeige: **Besucher:innen / Geld / Zufriedenheit**. Luftgüte-Cache: PM10 6,7 (+10 am Hitzetag).
Ab Tag 2 gibt es **Sicherheitsvorfälle**, wo die Menge unbewacht ist — der Einbruch am Tag-2-Wechsel ist der dramaturgische Höhepunkt, kein Fehler.

**Vorher (Pit Crew):** Binary starten (`./build/buergermeister.x86_64`) *oder* Editor + F5.
Proxy optional (`python3 mistral-proxy/server.py`) — ohne Proxy antworten die Offline-Stimmen,
das Spiel läuft trotzdem vollständig. Bildschirm auf 1600×900 oder größer.

| Zeit | Aktion | Sprechtext |
|---|---|---|
| 0:00 | Startmenü | „Stellt euch vor, ihr seid Bürgermeister:in von Linz — und morgen beginnt das Ars Electronica Festival. Tausende kommen. Die Stadt muss das tragen." |
| 0:15 | **Festival starten** | „Linz als Miniatur aus offenen Daten. Drei Werte oben — und jeden Tag meldet sich die Stadt mit einem Anliegen." *(50 / 77 / 68)* |
| 0:30 | Anliegen vorlesen | „Tag eins: *Lentos Kunstmuseum — wie kommen die Gäste her?* Das Lentos hängt an keiner anderen Spielstätte." |
| 0:40 | **Lentos** → *Shuttle* | „Also ein Shuttle. Der Button sagt vorher, was es bringt: vier Besucherpunkte, 1.800 Euro — und zwei Punkte Zufriedenheit, weil wir zugehört haben. Das Anliegen wird grün." *(54 / 76 / 70)* |
| 0:55 | **OK Platz** → *Shuttle*, **Hauptplatz** → *Fußgänger*, **Faire Preise** | „Noch ein Shuttle für den OK-Platz-Cluster, der Hauptplatz wird Fußgängerzone, faire Preise für alle." *(73 / 69 / 69)* |
| 1:15 | **Nächster Tag** — Statuszeile vorlesen | „Und jetzt kommt das Festival wirklich an: *Vorfall am Ars Electronica Center — zu wenig Security für die Menge.* Zehn Punkte Zufriedenheit weg, über die Karte leuchtet die Sicherheitsebene rot." *(64 / 69 / 59)* |
| 1:30 | **Faire Preise**, Toilette **Stadtpark Huemerstraße** → *Verlegen* | „Tag zwei bittet außerdem um eine Toilette beim C. Bechstein Centrum. Diese hier steht, wo niemand feiert — wir verlegen sie. Anliegen zwei erfüllt, plus Förderung." *(67 / 67 / 63)* |
| 1:45 | Toilette **Promenade** → *Schließen* | „Eine doppelt versorgte sperren wir: 300 Euro zurück — die brauchen wir gleich." *(67 / 68 / 63)* |
| 1:55 | **AEC** und **OK Platz** → *Security-Team buchen* | „Zwei Teams für die zwei größten Bühnen, je 400 Euro. Die Vorschau rechnet vor, was ein Vorfall kostet — die Teams holen es zurück." *(68 / 66 / 65)* |
| 2:10 | **Nächster Tag**, **Faire Preise** | „Tag drei, Hitzetag: saubere Luft laut Messstation — und die Stadt bittet um Schatten fürs Ars Electronica Center." *(68 / 66 / 75)* |
| 2:20 | Baum am **Mariendom** anklicken | „Erst spricht die Platane am Mariendom. Fällen würde Platz schaffen, kostet aber fast vierzehn Punkte. Wir lassen sie stehen." |
| 2:35 | **AEC** → *Baum pflanzen* (zweimal) | „Stattdessen pflanzen wir. Ein Baum reicht noch nicht — die Vorschau zeigt: der zweite bringt drei Punkte, weil er das Anliegen erfüllt." *(68 / 67 / 80)* |
| 2:45 | **Abschluss** | „Gesamtnote 72, **Volksnahe Stadtplanung**, drei von drei Anliegen erfüllt — und das Spiel erzählt es: *Die Platane nahe Mariendom durfte bleiben. Zwei Security-Teams an zwei Spielstätten.* Für Gold hätte die Stadt noch länger feiern dürfen." |
| 2:55 | Urteil stehen lassen | „Echte Daten, ein ehrliches Modell, und eine Stadt, die zurückredet. Danke!" |

Showcase für Fragen (20 s): am AEC **Sperrstunde verlängern** → **71 / 67 / 79**,
**Goldene:r Bürgermeister:in**. Pointe: Die längere Nacht lohnt sich *nur*, weil die Security steht —
am kleinen Powerplayground ist dieselbe Entscheidung ein Minusgeschäft.

## Wenn etwas schiefgeht

- **Stimme hängt / Proxy weg:** weiterreden, Entscheidungs-Buttons nutzen — Status „Offline-Stimme" ist ok.
- **Binary startet nicht:** Editor öffnen, F5. Vorab prüfen: `./build/buergermeister.x86_64 --headless -- --smoke-test` → `SMOKE OK`.
- **Werte weichen ab (> ±1):** nicht improvisieren — Zahlen weglassen, Richtung erzählen („mehr Besucher:innen, weniger Geld").
- **Falscher Klick:** Bäume sperren nach Zurückschneiden/Fällen, Toiletten nach dem Verlegen; geschlossene lassen sich *wieder öffnen*. Die Vorschau auf jedem Button zeigt vorher, was passiert. Notfalls **Abschluss** → **Neues Festival**.
- **Preise vergessen:** Jeden Tag zuerst **Faire Preise** drücken — der Tag beginnt auf Standard.

## Kurzfassung für Fragen

- **Warum KI?** Die Stimmen machen Daten erlebbar; Entscheidungen werden trotzdem nur über geprüfte IDs übernommen — das Modell kann nichts „erfinden".
- **Warum diese Zahlen?** Alle Annahmen sind benannte Konstanten; wir haben per Simulation tausende Entscheidungsfolgen auf den echten Daten durchgerechnet, damit kein einzelner Klick gewinnt — und damit Nichtstun ab Tag 2 spürbar weh tut, ohne die Stadt zu ruinieren.
- **Offline?** Ja — Karte, Daten und Ersatzstimmen liegen lokal.
