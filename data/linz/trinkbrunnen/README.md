---
title: "Trinkbrunnen"
summary: "Öffentliche Trinkwasserstellen und Zierbrunnen in Linz"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "Kommagetrennte UTF-8-CSV-Datei mit WGS84-Koordinaten"
license: "CC BY 4.0"
data_vintage: "Quelldatei vom 4. Juli 2023"
---

## Beschreibung

`Trinkbrunnen.csv` enthält 132 Brunnen. Die Quelle unterscheidet unter anderem
Trinkwasserstellen (`TB`), trinkbare Zierbrunnen (`BoP`) und Zierbrunnen ohne
Trinkwasser (`BmP`). Sie enthält Standort, Brunnenart, Betriebsstatus,
Wasseranalyse und Betriebszeit. Für 84 Brunnen sind Koordinaten vorhanden.

## Download

[Aufbereitete Datei `Trinkbrunnen.csv` herunterladen (ca. 53 KB)](/datasets/trinkbrunnen/Trinkbrunnen.csv)

## Verwendungshinweise

`lon` und `lat` sind für Webkarten nach WGS84 umgerechnete
Brunnenkoordinaten. Die ursprünglichen Werte bleiben als `epsg31255_x` und
`epsg31255_y` erhalten. In der Quelle sind die Achsen irreführend benannt: Das
Feld mit dem Suffix `_y` enthält den Ostwert und jenes mit `_x` den Nordwert.
Der Konverter ordnet sie korrekt zu.

`in_betrieb`, `trinkwasser` und `wasseranalyse` enthalten `true`, `false` oder
ein leeres Feld für „keine Angabe“. Ein historisch positiver Wert garantiert
nicht, dass ein Brunnen 2026 tatsächlich in Betrieb oder trinkbar ist.

Die Konvertierung ist reproduzierbar:

```sh
python3 prepare_trinkbrunnen.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/ee7668cf-46bc-4246-a6fa-4adfdb52a513)
- [Aktuelle CSV-Datei](https://data.linz.gv.at/katalog/Freizeit/trinkbrunnen/Trinkbrunnen.csv)
