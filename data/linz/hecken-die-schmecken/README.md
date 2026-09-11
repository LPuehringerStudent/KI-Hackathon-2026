---
title: "Hecken die Schmecken"
summary: "Standorte essbarer Beerensträucher im Linzer Stadtgebiet"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "Kommagetrennte UTF-8-CSV-Datei"
license: "CC BY 4.0"
data_vintage: "2022"
---

## Beschreibung

Die aufbereitete Datei enthält 20 Standorte essbarer Beerensträucher mit Standortbezeichnung, Beschreibung und Straucharten.

## Download

[Aufbereitete Datei `Hecken-die-schmecken.csv` herunterladen (ca. 3 KB)](/datasets/hecken-die-schmecken/Hecken-die-schmecken.csv)

## Verwendungshinweise

Die Quelle enthält keine Koordinaten. Eine Kartendarstellung benötigt daher eine manuelle Geokodierung der deutschsprachigen Ortsangaben. Die Felder heißen `standort`, `beschreibung` und `art`; `id` wird ausschließlich aus der in dieser Quelle eindeutigen Standortbezeichnung gebildet und bleibt deshalb bei Korrekturen an Beschreibung oder Pflanzenart stabil. Pflanzenbestand und Zugänglichkeit sind für 2026 nicht bestätigt.

## Aktualisierung

```sh
python3 prepare_hecken_die_schmecken.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/d587eab4-6c96-4d48-978d-2d5d12c57f15)
- [CSV-Datei 2022](https://data.linz.gv.at/katalog/umwelt/hecken/Hecken%20die%20schmecken%202022.csv)
