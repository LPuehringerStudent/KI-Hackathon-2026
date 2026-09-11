---
title: "Boudicca.Events"
summary: "Öffentliche, quellenübergreifende Veranstaltungs-API mit Linz-Abdeckung"
provider: "Boudicca.Events Community"
status: "essential"
format: "REST-API, JSON, OpenAPI 3.1"
license: "Quellenabhängig; API-Software GPL-3.0"
data_vintage: "Laufender Dienst"
---

## Beschreibung

Die API liefert Veranstaltungen mit Pflichtfeldern für Name, Beginn und Collector sowie optionalen Angaben zu Ort, Koordinaten, Kategorien, Barrierefreiheit und Herkunft. Alle Werte werden als Strings in flexiblen Schlüsseln übertragen.

## Verwendungshinweise

Herkunft und Lizenz jedes Eintrags müssen erhalten bleiben. Duplikate, wechselnde Felder und Ausfälle des Live-Dienstes sind einzuplanen; für Hackathon-Anwendungen empfiehlt sich deshalb ein datierter Snapshot.

## Quellen

- [Projektbeschreibung](https://boudicca.events/about)
- [REST-API-Anleitung](https://github.com/boudicca-events/boudicca.events/blob/main/docs/REST.md)
- [Datenmodell](https://github.com/boudicca-events/boudicca.events/blob/main/docs/DATA_MODEL.md)
- [Abfragesprache](https://github.com/boudicca-events/boudicca.events/blob/main/docs/QUERY.md)
- [Semantische Konventionen](https://github.com/boudicca-events/boudicca.events/blob/main/docs/SEMANTIC_CONVENTIONS.md)
- [Live-API-Dokumentation](https://search.boudicca.events/swagger-ui/index.html)
