---
title: "Herkunftsländer der Gäste"
summary: "Ankünfte und Übernachtungen in Linz nach Herkunft und Quartal"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "Kommagetrennte UTF-8-CSV-Datei"
license: "CC BY 4.0"
data_vintage: "2024"
---

## Beschreibung

Die aufbereitete Datei enthält 232 Quartalswerte zu Ankünften und Übernachtungen nach Herkunftsland oder -region im Jahr 2024. Jede Zeile beschreibt genau eine Herkunft und ein Quartal. Die Werte sind aggregierte Tourismusdaten und enthalten keine einzelnen Unterkünfte oder Personen.

## Download

[Aufbereitete Datei `Herkunftslaender.csv` herunterladen (ca. 15 KB)](/datasets/herkunftslaender-gaeste/Herkunftslaender.csv)

## Verwendungshinweise

`quartal` hat die Werte 1 bis 4. `ankuenfte` und `uebernachtungen` sind nichtnegative ganze Zahlen. Für eindeutige Länder enthält `iso2` einen zweistelligen ISO-Ländercode; bei Summen und Ländergruppen bleibt das Feld leer. Mit `herkunft_typ` können Anwendungen zwischen `land`, `gruppe` und `summe` unterscheiden. Für Ländervergleiche sollte nach `herkunft_typ = land` gefiltert werden.

Die Bezeichnungen in `herkunft` bleiben unverändert aus der Quelle erhalten. Der Konverter prüft alle 58 Bezeichnungen gegen eine feste, geprüfte Liste, damit neue Quellwerte nicht stillschweigend als Gruppen erscheinen. Insbesondere Zeilen mit Fußnoten oder zusammengefassten Ländern dürfen nicht als einzelne Länder interpretiert werden: `China 2)` ist eine solche Gruppe und erhält deshalb keinen ISO-Code.

## Aktualisierung

```sh
python3 prepare_herkunftslaender_gaeste.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/e7b92bb8-75e4-41ac-8b78-b43e25734e0d)
- [CSV-Datei 2024](https://data.linz.gv.at/katalog/tourismus/herkunftsnationen/2024/thdg_2024.csv)
