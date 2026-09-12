---
marp: true
title: Bürgermeister:in fürs Festival
paginate: true
---

# Bürgermeister:in fürs Festival

**Drei Tage. Eine Stadt. Viele Stimmen.**

Ein Spiel über das Ars Electronica Festival 2026 in Linz —
gebaut aus echten offenen Daten der Stadt.

KI-Hackathon 2026

---

## Die Idee

Der Festival-Planer zeigt Besucher:innen, **wohin** sie gehen sollen.
Unser Spiel macht dich verantwortlich für die **Stadt, in der sie ankommen**.

- Du bist Bürgermeister:in während der Festivalwoche.
- Die Stadt spricht mit dir: **Spielstätten, Bäume, Toiletten, Trinkbrunnen, Straßen** —
  jede Stimme kennt ihre echten Daten.
- Jede Entscheidung kostet Geld und verändert, wie es Linz geht.

---

## So spielt es sich

| Tag | Thema | Beispiel |
|---|---|---|
| 1 — Anreise | Mobilität | Shuttle zum Ars Electronica Center? |
| 2 — Höhepunkt | Sanitär & Wasser | Wohin mit der Toilette im Stadtpark? |
| 3 — Hitzetag | Schatten & Bäume | Darf die Platane am Mariendom bleiben? |

- Verhandeln im Chat (Mistral-Sprachmodell, offline mit vorbereiteten Stimmen)
- Drei Werte: **Besucher:innen · Geld · Zufriedenheit**
- Neu: Sicherheitsrisiko pro Bühne — ab Tag 2 gibt es Vorfälle, wo die Menge unbewacht ist
- Foodtrucks, Security-Teams, Sperrstunde, Ticketpreise
- Am Ende ein Titel — von **„Stadt in Schieflage"** bis **„Goldene:r Bürgermeister:in"**

---

## Echte Daten, ehrliches Modell

- **Festivalkalender:** 20 Spielstätten, Events inkl. Nebenräume (AEC: 244)
- **Stadt Linz Open Data:** 400 Bäume, 38 Trinkbrunnen, 41 WC-Anlagen, Straßennamen-Geschichte
- **Luftgüte Land OÖ:** Station Stadtpark, PM10 → Bonus oder Malus am Hitzetag
- **Karte:** isometrische Miniatur aus OpenStreetMap, 3D-modellierte Requisiten

Alle Annahmen sind benannte Konstanten. Die Balance ist **simuliert und getestet**:
keine Einzelentscheidung gewinnt das Spiel, und wer die Stadt am Festivaltag sich selbst überlässt,
sieht ab Tag 2 die Folgen — Vorfälle dort, wo die Menge zu groß für die Betreuung ist.

---

## Live-Demo & wie es weitergeht

**Demo:** zwei Shuttles → Vorfall an Tag 2 → Security & Toilette → Platane retten → Urteil

**Technik:** Godot 4.7 · Linux-Build · 160 automatisierte Checks · läuft offline

**Weiter gedacht:**
- mehr Tage, mehr Stimmen, andere Städte mit offenen Daten
- Werkzeug für Bürgerbeteiligung: Planungsfragen spielerisch verhandeln

**Danke — und viel Spaß beim Regieren!**
