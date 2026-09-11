---
title: "Straßennamen und deren Bedeutung"
summary: "Aktuelle und historische Linzer Straßennamen mit Benennungsgeschichte"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "Zwei kommagetrennte UTF-8-CSV-Dateien"
license: "CC BY 4.0"
data_vintage: "Quelldateien vom 7. März 2025"
---

## Beschreibung

`Strassennamen-aktuell.csv` enthält 1.211 aktuelle Straßennamen.
`Strassennamen-historisch.csv` enthält 364 historische Namen. Beide Dateien
umfassen Namen, Katastralgemeinde, Beschreibung und stabile IDs sowie teilweise
Wikidata- und Personendaten. Historische Einträge können zusätzlich einen
heutigen Straßennamen und Angaben zum Benennungszeitraum enthalten.

Geometrien und Koordinaten sind nicht enthalten.

## Download

- [Aktuelle Straßennamen `Strassennamen-aktuell.csv` herunterladen (ca. 476 KB)](/datasets/strassennamen/Strassennamen-aktuell.csv)
- [Historische Straßennamen `Strassennamen-historisch.csv` herunterladen (ca. 114 KB)](/datasets/strassennamen/Strassennamen-historisch.csv)

## Verwendungshinweise

`id` ist innerhalb der jeweiligen Datei eindeutig; `quell_id` bewahrt die
numerische ID der Stadt Linz. Personendaten und Wikidata-Felder sind nur für
einen Teil der Straßen vorhanden. `person_wikidata_id` enthält immer höchstens
eine ID und `person_wikidata_url` immer die dazugehörige kanonische Wikidata-URL.
Falls die Quelle weitere Personen-IDs nennt, stehen sie durch `|` getrennt in
`weitere_person_wikidata_ids`. Datumswerte wurden auf `YYYY-MM-DD`
vereinheitlicht. Freie historische Jahresangaben wie `um 1800` bleiben als Text
erhalten.

`benennung_code` übernimmt die Quellwerte `M`, `W`, `X` oder leer unverändert.
Der Code sollte nicht ohne zusätzliche Quelldokumentation als vollständige
Geschlechterklassifikation interpretiert werden. Adressverknüpfungen benötigen
weiterhin eine kontrollierte Namensnormalisierung und müssen historische
Umbenennungen berücksichtigen.

Die Konvertierung ist reproduzierbar:

```sh
python3 prepare_strassennamen.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/807645f0-2e80-4e24-b142-3673b108dde6)
- [Aktuelle Straßennamen](https://data.linz.gv.at/katalog/stadt/strassen/Strassennamen-aktuell.csv)
- [Historische Straßennamen](https://data.linz.gv.at/katalog/stadt/strassen/Strassennamen-historisch.csv)
- [Mapping Diversity](https://mappingdiversity.eu/)
