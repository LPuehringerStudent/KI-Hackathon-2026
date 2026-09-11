---
title: "Radverkehr-Zählstellen"
summary: "Zählstellen und stündliche Radverkehrsmessungen in Linz"
provider: "Stadt Linz / data.linz.gv.at"
status: "optional"
format: "Semikolon-CSV und WGS84 GeoJSON"
license: "CC BY 4.0"
data_vintage: "2024–2025"
---

## Beschreibung

Die Dateien enthalten 15 Richtungszähler an acht Koordinatenpaaren und 263.160 stündliche Messzeilen. `Zaehlstelle` verknüpft Messwerte mit Standorten; 1.674 Zählwerte sind leer.

## Verwendungshinweise

`Zaehlstelle` ist der Schlüssel zwischen Messwerten und Standorten. Die 1.674 leeren Zählwerte sind als fehlende Messungen zu behandeln und dürfen nicht in Nullen umgewandelt werden. Die Dateien bilden einen historischen Datenstand ab und sind keine Live-Zählung.

## Quellen

- [Download-Verzeichnis](https://data.linz.gv.at/katalog/verkehr/radverkehr/)
- [Stündliche Messwerte](https://data.linz.gv.at/katalog/verkehr/radverkehr/StadtLinz_Radverkehr_Messwerte.csv)
- [Zählstellen als CSV](https://data.linz.gv.at/katalog/verkehr/radverkehr/StadtLinz_Radverkehr_Zaehlstellen.csv)
- [Zählstellen als GeoJSON](https://data.linz.gv.at/katalog/verkehr/radverkehr/StadtLinz_Radverkehr_Zaehlstellen.geojson)
