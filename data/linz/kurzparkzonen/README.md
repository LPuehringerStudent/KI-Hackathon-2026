---
title: "Kurzparkzonen"
summary: "Zeit- und Gebührenzonen für Kurzparken in Linz"
provider: "Stadt Linz / Bürger*innen-Angelegenheiten"
status: "optional"
format: "Fünf GeoJSON-Layer; Quelle: ESRI Shapefile"
license: "CC BY 4.0"
data_vintage: "21. Juni 2022"
---

## Beschreibung

Die fünf aufbereiteten Dateien enthalten insgesamt 305 Features. Sie sind von EPSG:31255 nach WGS84 (EPSG:4326) umprojiziert und können direkt in Webkarten verwendet werden:

- 11 Linien für 30-Minuten-Zonen;
- 29 Linien für 180-Minuten-Zonen;
- 7 Polygone und 254 Linien für 90-Minuten-Zonen;
- 4 Polygone oder Multipolygone für die Gebührenzonengrenzen.

## Download

- [30-Minuten-Zonen (ca. 4 KB)](/datasets/kurzparkzonen/Kurzparkzone_30min_20220621.json)
- [90-Minuten-Zonen als Flächen (ca. 84 KB)](/datasets/kurzparkzonen/Kurzparkzone_90min_Area_20220621.json)
- [90-Minuten-Zonen als Linien (ca. 85 KB)](/datasets/kurzparkzonen/Kurzparkzone_90min_Line_20220621.json)
- [180-Minuten-Zonen (ca. 18 KB)](/datasets/kurzparkzonen/Kurzparkzone_180min_20220621.json)
- [Gebührenzonengrenzen (ca. 60 KB)](/datasets/kurzparkzonen/Kurzparkzone_Grenze_20220621.json)

## Verwendungshinweise

`Parkdauer` enthält `30 min`, `90 min` oder `180 min`. `Zeiten` beschreibt die 2022 erfassten Geltungszeiten. Die Datei mit den Gebührenzonengrenzen enthält nur `GUID`.

`GUID` ist innerhalb jeder Datei eindeutig. Eine Kennung kommt jedoch sowohl im 90-Minuten-Flächenlayer als auch im Linienlayer vor. Anwendungen, die mehrere Layer zusammenführen, müssen deshalb den Dateinamen oder Layernamen gemeinsam mit `GUID` als Schlüssel verwenden.

Wegen des Datenstands dürfen die Dateien nicht als aktuelle oder verbindliche Park-, Gebühren- oder Rechtsauskunft verwendet werden. Beschilderung und aktuelle Informationen der Stadt Linz haben Vorrang.

## Quellen

- [data.gv.at Katalog](https://www.data.gv.at/katalog/datasets/bb992195-d827-48d4-a676-f3d680840a1c)
- [Originale Shapefiles im Download-Verzeichnis 2022](https://data.linz.gv.at/katalog/geodata/kurzparkzonen/2022/)
