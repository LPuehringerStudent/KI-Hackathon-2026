---
title: "Baumkataster Linz"
summary: "Georeferenzierter Bestand der von der Stadt Linz betreuten Bäume"
provider: "Stadt Linz / data.linz.gv.at"
status: "essential"
format: "Kommagetrennte UTF-8-CSV-Datei"
license: "CC BY 4.0"
data_vintage: "Export vom 1. Juli 2026"
---

## Beschreibung

Die aufbereitete Datei umfasst 27.004 von der Stadt Linz betreute Bäume mit Gattung, Art, Sorte, deutschem Namen, Höhe, Kronendurchmesser, Stammumfang, Baumtyp und Koordinaten in EPSG:4326 sowie EPSG:31255.

## Download

[Aufbereitete Datei `Baumkataster.csv` herunterladen (ca. 3,5 MB)](/datasets/baumkataster/Baumkataster.csv)

## Verwendungshinweise

Für Karten sind `lon` und `lat` zu verwenden. Für Verknüpfungen innerhalb dieser Datei ist `id` zu verwenden, nicht `BaumNr`. Ein Datensatz besitzt keine `Flaeche`; dieses bereits in der Quelle leere Feld bleibt leer. Der Kronendurchmesser ist kein gemessener Schattenwert.

## Aktualisierung

```sh
python3 prepare_baumkataster.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/f660cf3f-afa9-4816-aafb-0098a36ca57d)
- [Download-Verzeichnis](https://data.linz.gv.at/katalog/umwelt/baumkataster/)
