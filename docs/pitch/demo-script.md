# Demo-Skript (3 Minuten, Deutsch)

Route B aus `docs/playtest-checklist.md` — alle Zahlen dort nachgerechnet.
Anzeige: **Besucher:innen / Geld / Zufriedenheit**. Luftgüte-Cache: PM10 6,7 (+10 am Hitzetag).

**Vorher (Pit Crew):** Binary starten (`./build/buergermeister.x86_64`) *oder* Editor + F5.
Proxy optional (`python3 mistral-proxy/server.py`) — ohne Proxy antworten die Offline-Stimmen,
das Spiel läuft trotzdem vollständig. Bildschirm auf 1600×900 oder größer.

| Zeit | Aktion | Sprechtext |
|---|---|---|
| 0:00 | Startmenü sichtbar | „Stellt euch vor, ihr seid Bürgermeister:in von Linz — und morgen beginnt das Ars Electronica Festival. Tausende kommen. Die Stadt muss das tragen." |
| 0:15 | **Festival starten** | „Das ist Linz als Miniatur, gebaut aus offenen Daten: jeder grüne Punkt ein echter Baum aus dem Baumkataster, jede Toilette, jeder Brunnen ist echt. Oben rechts unsere drei Werte." *(45 / 75 / 65)* |
| 0:35 | Chat zeigt das **Ars Electronica Center** | „Und die Stadt redet mit uns. Das AEC meldet sich — die Stimme kennt ihre echten Daten, zum Beispiel 244 Veranstaltungen in ihren Räumen." |
| 0:50 | **Shuttle-Haltestelle einrichten** | „Tag eins, Anreise. Ein Shuttle zum AEC." *(49 / 69 / 65)* |
| 1:00 | **OK Platz** anklicken → Shuttle | „Und einer zum OK Platz — dort hängen Ursulinenhof und OK Linz gleich mit dran. Mehr Besucher:innen, aber das Budget schrumpft." *(58 / 67 / 65, Budget 10.400 €)* |
| 1:15 | **Nächster Tag →** | „Tag zwei, Höhepunkt: Sanitär und Wasser." |
| 1:20 | Toilette **Stadtpark Huemerstraße** → **Verlegen** | „Diese Toilette steht dort, wo gerade niemand feiert. Wir verlegen sie — das Modell schickt sie zur größten Spielstätte ohne WC." *(58 / 64 / 67)* |
| 1:40 | **Nächster Tag →** | „Tag drei: Hitzetag. Die Luftgüte-Messstation im Stadtpark meldet saubere Luft — das hebt die Stimmung." *(58 / 64 / 77)* |
| 1:55 | Baum neben dem **Mariendom** anklicken | „Und jetzt spricht eine Platane am Mariendom. Ihre Krone spendet Schatten genau dort, wo die Leute stehen." |
| 2:10 | (optional eine Frage tippen, dann) **Stehen lassen** | „Wir lassen sie stehen. Fällen hätte 400 Euro gekostet — und zehn Punkte Zufriedenheit." *(58 / 64 / 78)* |
| 2:30 | **Abschluss** | „Gesamtnote 67 von 100 — das Urteil: **Solide Verwaltung**. Nicht golden — dafür hätten wir klüger mit dem Geld umgehen müssen." *(Restbudget 9.600 €)* |
| 2:45 | Urteil stehen lassen | „Echte Daten, ein ehrliches Modell, und eine Stadt, die zurückredet. Danke!" |

## Wenn etwas schiefgeht

- **Stimme hängt / Proxy weg:** weiterreden, Entscheidungs-Buttons nutzen — Status „Offline-Stimme" ist ok.
- **Binary startet nicht:** Editor öffnen, F5. Vorab prüfen: `./build/buergermeister.x86_64 --headless -- --smoke-test` → `SMOKE OK`.
- **Werte weichen ab (> ±1):** nicht improvisieren — Zahlen weglassen, Richtung erzählen („mehr Besucher:innen, weniger Geld").
- **Falscher Klick:** Bäume und Toiletten sind nach einer Entscheidung gesperrt; Spielstätten bleiben offen. Notfalls **Abschluss** → **Neues Festival**.

## Kurzfassung für Fragen

- **Warum KI?** Die Stimmen machen Daten erlebbar; Entscheidungen werden trotzdem nur über geprüfte IDs übernommen — das Modell kann nichts „erfinden".
- **Warum diese Zahlen?** Alle Annahmen sind benannte Konstanten; wir haben per Simulation tausende Entscheidungsfolgen auf den echten Daten durchgerechnet, damit kein einzelner Klick gewinnt und Nichtstun neutral bleibt.
- **Offline?** Ja — Karte, Daten und Ersatzstimmen liegen lokal.
