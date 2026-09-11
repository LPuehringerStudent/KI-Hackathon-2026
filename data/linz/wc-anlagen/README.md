---
title: "Öffentliche WC-Anlagen"
summary: "Standorte und Ausstattungsmerkmale öffentlicher Toiletten in Linz"
provider: "Stadt Linz / Gebäudemanagement und Tiefbau"
status: "recommended"
format: "Kommagetrennte UTF-8-CSV-Datei mit WGS84-Koordinaten"
license: "CC BY 4.0"
data_vintage: "Datenstand 2023; Quelldatei vom 8. Juli 2024"
---

## Beschreibung

`WC-Anlagen.csv` enthält 68 öffentliche Toiletten: 41 feste Anlagen und 27
mobile WC-Kabinen. Erfasst sind Typ, Bezeichnung, Koordinaten,
Barrierefreiheits- und Eurokey-Angaben, Öffnungszeiten, Wickeltisch,
Wintersperre und Anmerkungen.

## Download

[Aufbereitete Datei `WC-Anlagen.csv` herunterladen (ca. 10 KB)](/datasets/wc-anlagen/WC-Anlagen.csv)

## Verwendungshinweise

Für Webkarten sind `lon` und `lat` zu verwenden. Die ursprünglichen
EPSG:31255-Werte bleiben erhalten. Eingebettete Zeilenumbrüche wurden zu
Leerzeichen normalisiert. `barrierefrei`, `eurokey` und `wickeltisch` enthalten
standardisierte Wahrheitswerte.

Öffnungszeiten, Zugänglichkeit, mobile Standorte und Ausstattung sind für 2026
nicht garantiert. Anwendungen sollten die Daten deshalb nicht als
verbindliche aktuelle Auskunft darstellen.

Die Konvertierung ist reproduzierbar:

```sh
python3 prepare_wc_anlagen.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/461b3bd7-346d-4401-91d6-8009538c54a1)
- [Aktuelle CSV-Datei](https://data.linz.gv.at/katalog/Freizeit/toiletten/WC_Anlagen.csv)
