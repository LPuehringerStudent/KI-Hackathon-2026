---
title: "Öffentliche WLAN-Hotspots"
summary: "Standorte und historische Nutzungszahlen öffentlicher Linzer WLAN-Punkte"
provider: "Stadt Linz / data.linz.gv.at"
status: "recommended"
format: "Zwei kommagetrennte UTF-8-CSV-Dateien"
license: "CC BY 4.0"
data_vintage: "2022"
---

## Beschreibung

`Hotspot-Standorte.csv` enthält 134 WLAN-Standorte mit WGS84-Koordinaten, Adresse und dem 2022 gemeldeten Status. `Hotspot-Nutzung.csv` enthält 749 monatliche Nutzungszeilen für 107 Hotspot-Namen von Jänner bis Juli 2022.

## Download

- [Aufbereitete Standorte `Hotspot-Standorte.csv` herunterladen (ca. 52 KB)](/datasets/hotspots/Hotspot-Standorte.csv)
- [Aufbereitete Nutzung `Hotspot-Nutzung.csv` herunterladen (ca. 62 KB)](/datasets/hotspots/Hotspot-Nutzung.csv)

## Verwendungshinweise

Für Karten sind `lon` und `lat` aus `Hotspot-Standorte.csv` zu verwenden. `status_2022` enthält die Quellwerte `ok`, `neu`, `offline` oder `defekt` und ist keine Aussage über den Zustand im Jahr 2026. Ein leeres `ende_jahr` bedeutet, dass die Quelle kein Ende angegeben hat.

In `Hotspot-Nutzung.csv` bezeichnet jede Zeile genau einen Monat. Leere Werte in `anzahl_clients` sind unbekannt und dürfen nicht als null Clients interpretiert werden. `standort_id` verknüpft 106 der 107 Nutzungsnamen mit der Standortdatei. Nur `Rotes Kreuz` bleibt leer, weil dafür zwei mögliche Standorte existieren. Anwendungen sollten nicht selbst raten.

## Aktualisierung

```sh
python3 prepare_hotspots.py
```

## Quellen

- [data.gv.at Katalog der Standorte](https://www.data.gv.at/katalog/datasets/b2068d46-de7f-4a22-a563-4dea59b1e6f2)
- [data.gv.at Katalog der Nutzungsdaten](https://www.data.gv.at/katalog/datasets/d849807f-d313-45fb-a7b6-af3f726a1673)
- [Originale Standortdatei 2022](https://data.linz.gv.at/katalog/Freizeit/hotspot/Hotspot_Geodaten_2022.csv)
- [Originale Nutzungsdatei 2022](https://data.linz.gv.at/katalog/Freizeit/hotspot/Hotspot-Auswertung_2022-HJ1.csv)
