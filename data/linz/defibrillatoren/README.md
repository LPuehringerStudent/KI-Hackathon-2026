---
title: "Defibrillatoren"
summary: "Veröffentlichte AED-Standorte in Linz; ausschließlich für Prototypen"
provider: "Stadt Linz / Österreichisches Rotes Kreuz OÖ"
status: "recommended"
format: "Kommagetrennte UTF-8-CSV-Datei"
license: "CC BY 4.0"
data_vintage: "Mai 2022"
---

## Beschreibung

Die aufbereitete Datei enthält 282 veröffentlichte AED-Einträge mit Gebäude oder Organisation, Adresse, Hersteller, Gerätebezeichnung, Standortbeschreibung und WGS84-Koordinaten.

## Download

[Aufbereitete Datei `Defibrillatoren.csv` herunterladen (ca. 45 KB)](/datasets/defibrillatoren/Defibrillatoren.csv)

## Verwendungshinweise

Fünf Einträge besitzen keine Quellkoordinaten; drei davon auch keine Adresse, Postleitzahl oder Stadt. Ein weiterer Eintrag nennt Wien und liegt mit `quell_lon = 16.338724` deutlich außerhalb von Linz, obwohl seine Postleitzahl `4030` lautet. Seine Quellwerte bleiben in `quell_lon` und `quell_lat` erhalten, während `lon` und `lat` leer bleiben. `koordinatenstatus` unterscheidet `plausibel`, `fehlt` und `ausserhalb_linz`. Mehrere Geräte können denselben Punkt besitzen. Für Verknüpfungen innerhalb dieser Datei ist `id` zu verwenden.

Wegen des Alters und fehlender Angaben zu Zugang, Betriebsbereitschaft und Öffnungszeiten darf die Datei ausschließlich für Prototypen und nicht als Notfallinformation eingesetzt werden.

## Aktualisierung

```sh
python3 prepare_defibrillatoren.py
```

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/866e3d0b-531b-42a0-a82a-3f36dd02b368)
- [Originale CSV-Datei](https://data.linz.gv.at/katalog/gesundheit/defis/2022/Defi_Standorte_Linz_2022-05.csv)
