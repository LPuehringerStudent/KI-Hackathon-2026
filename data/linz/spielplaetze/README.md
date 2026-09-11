---
title: "Spielplätze und Sportanlagen"
summary: "Georeferenzierte Freizeitstandorte und Spielgeräte in Linz"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "CSV mit WGS84-WKT; optionales Shapefile in EPSG:31255"
license: "CC BY 4.0"
data_vintage: "CSV ca. 2017–2023; Gerätelayer 2023"
---

## Beschreibung

Die CSV enthält 158 Spielplätze und Sportanlagen mit Klasse, Name, Bezirk, Aktivitätsart, Adresse, URL und WGS84-Punkt. Der separate Gerätelayer ergänzt `GUID`, Spielplatz und Geräteart als Polygone. Beide Quellen sind öffentlich herunterladbar.

## Download

- [CSV der Spielplätze und Sportanlagen herunterladen](https://www.data.gv.at/katalog/datasets/b77d0b46-306c-46da-b26d-6e4dd718fde7)
- [Shapefile-Komponenten der Spielgeräte 2023 herunterladen](https://data.linz.gv.at/katalog/geodata/spielplaetze/2023/)

## Verwendungshinweise

Die CSV ist als Latin-1 beziehungsweise Windows-1252 zu dekodieren. Spielplätze und Sportanlagen müssen anhand ihrer Klasse getrennt werden. Der Gerätelayer liegt in EPSG:31255 vor und benötigt für Webkarten eine Konvertierung nach WGS84; für das vollständige Shapefile werden alle fünf Dateien aus dem Download-Verzeichnis benötigt.

Wegen des Datenstands dürfen Standorte und Ausstattung nicht als vollständig aktuell verstanden werden.

## Quellen

- [data.gv.at Katalog der Standorte](https://www.data.gv.at/katalog/datasets/b77d0b46-306c-46da-b26d-6e4dd718fde7)
- [data.gv.at Katalog der Spielgeräte 2023](https://www.data.gv.at/katalog/datasets/b5c88eba-dcd7-4e1f-85cb-640d3eeec359)
