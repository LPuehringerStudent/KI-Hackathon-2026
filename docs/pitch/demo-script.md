# Demo-Skript (3 Minuten, Deutsch)

Demo-Route aus `docs/playtest-checklist.md` §2 — alle Zahlen dort nachgerechnet und von `test_real_data_endings` geprüft.
Anzeige: **Besucher:innen / Geld / Zufriedenheit**. Luftgüte-Cache: PM10 6,7 (+10 am Hitzetag).

**Vorher (Pit Crew):** Binary starten (`./build/buergermeister.x86_64`) *oder* Editor + F5.
Proxy optional (`python3 mistral-proxy/server.py`) — ohne Proxy antworten die Offline-Stimmen,
das Spiel läuft trotzdem vollständig. Bildschirm auf 1600×900 oder größer.

| Zeit | Aktion | Sprechtext |
|---|---|---|
| 0:00 | Startmenü sichtbar | „Stellt euch vor, ihr seid Bürgermeister:in von Linz — und morgen beginnt das Ars Electronica Festival. Tausende kommen. Die Stadt muss das tragen." |
| 0:15 | **Festival starten** | „Linz als Miniatur, gebaut aus offenen Daten: jeder Baum, jede Toilette, jeder Brunnen ist echt. Oben rechts unsere drei Werte — und jede Entscheidung zeigt vorher, was sie kostet und bringt." *(45 / 75 / 65)* |
| 0:35 | **OK Platz** → *Shuttle* | „Tag eins, Anreise. Ein Shuttle zum OK Platz — Ursulinenhof und OK Linz hängen gleich mit dran: plus neun Besucher:innen, minus 1.800 Euro." *(54 / 72 / 65)* |
| 0:50 | Straße **Hauptplatz** → *Für Fußgänger sperren*, dann **Faire Preise** | „Der Hauptplatz wird Fußgängerzone. Und faire Ticketpreise: mehr Leute, dafür weniger Geld." *(63 / 67 / 64)* |
| 1:05 | **Nächster Tag →**, **Faire Preise** | „Tag zwei, Höhepunkt." |
| 1:10 | **Mozartstraße** → *Fußgänger*; Toilette **Promenade** → *Schließen* | „Noch eine Fußgängerzone — und diese Toilette ist doppelt versorgt, die schließen wir: 300 Euro zurück, ein bisschen Unmut." *(67 / 69 / 62)* |
| 1:35 | **Nächster Tag →**, **Faire Preise** | „Tag drei: Hitzetag. Die Messstation im Stadtpark meldet saubere Luft — das hebt die Stimmung." *(67 / 69 / 72)* |
| 1:50 | Baum neben dem **Mariendom** anklicken | „Und jetzt spricht eine Platane am Mariendom. Fällen würde etwas Platz schaffen — aber fast vierzehn Punkte Zufriedenheit kosten. Wir hören ihr zu und lassen sie stehen." |
| 2:15 | **Ars Electronica Center** → *Sperrstunde verlängern* | „Die Nacht ist kühler — das AEC bleibt länger offen. Mehr Publikum, etwas weniger Ruhe." *(69 / 68 / 69)* |
| 2:30 | **Abschluss** | „Gesamtnote 68 — **Volksnahe Stadtplanung**. Und das Spiel erzählt, was wir getan haben: *Die Platane nahe Mariendom durfte bleiben.* Golden wäre möglich gewesen: Brunnen klug verlegen, Sperrstunde lassen." |
| 2:50 | Urteil stehen lassen | „Echte Daten, ein ehrliches Modell, und eine Stadt, die zurückredet. Danke!" |

Showcase für Fragen (60 s extra, Checkliste §4): Brunnen *„Südbahnhof gegenüber RZK Gebäude"* verlegen,
*„Hauptplatz südliche Grüninsel"* schließen, keine Sperrstunde → **Goldene:r Bürgermeister:in**, Gesamtnote 69.

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
