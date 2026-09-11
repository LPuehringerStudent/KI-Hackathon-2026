---
title: "EFA Fahrplanauskunft"
summary: "Legacy-API für Haltestellen, Abfahrten und Routen"
provider: "Stadt Linz / LINZ AG LINIEN"
status: "essential"
format: "HTTP-API mit JSON oder XML"
license: "CC BY 4.0 mit ergänzenden LINZ-AG-Bedingungen"
data_vintage: "Live-API; zuletzt geprüft am 23. Juli 2026"
---

## Beschreibung

Die EFA-API der LINZ AG liefert Haltestellen, Abfahrten und
Reiseverbindungen. Sie ist eine nicht versionierte Legacy-Schnittstelle; ihre
Einstellung war bereits für 2024 angekündigt, obwohl sie bei der letzten
Prüfung am 23. Juli 2026 noch erreichbar war.

## Wichtige Einschränkung

Für den Hackathon wird kein EFA-Adapter, Proxy, Cache oder Fallback
bereitgestellt. Der Server lieferte bei der Prüfung keinen
`Access-Control-Allow-Origin`-Header. Direkte API-Aufrufe aus einer
Browser-Anwendung werden daher durch CORS blockiert.

Teilnehmende müssen für die Verwendung selbst einen Backend-Endpunkt,
Timeouts, Fehlerbehandlung, Caching und einen Fallback bereitstellen. Für
reine Frontend-Anwendungen ist dieser Datensatz ungeeignet.

## Dokumentation

Die [ausführliche EFA-API-Dokumentation](efa-fahrplanauskunft/api) enthält
getestete Requests für StopFinder, Abfahrten und Routen sowie Parameter,
Koordinatenformate, Antwortfelder, Echtzeit-Hinweise, bekannte Risiken und
alle aufgefundenen offiziellen und historischen Quellen.

## Quellen

- [Aktueller Katalogeintrag zu EFA, GTFS und NeTEx](https://www.data.gv.at/datasets/d3c0a223-516b-4049-9370-22881a0428d8?locale=de)
- [Offizielles Verzeichnis der Linzer EFA-Unterlagen](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/)
- [Nutzungsbedingungen des Linzer Datenportals](https://data.linz.gv.at/nutzungsbedingungen/)
