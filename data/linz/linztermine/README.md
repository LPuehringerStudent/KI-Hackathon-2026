---
title: "Linztermine"
summary: "Veranstaltungen, Termine, Orte, Veranstalter und Kategorien in einem gemeinsamen Datensatz"
provider: "Stadt Linz / Linztermine.at"
status: "recommended"
format: "Eine UTF-8-JSON-Datei; Quelle: vier XML-APIs"
license: "CC BY 4.0"
data_vintage: "Live-Daten; Snapshot vom 3. August 2026"
---

## Beschreibung

`Linztermine.json` führt die vier aktiven Linztermine-Schnittstellen in einer Datei zusammen:

- Veranstaltungen und einzelne Termine;
- Orte und Unterorte;
- Veranstalter*innen;
- fünf Hauptkategorien und 21 untergeordnete Tags.

Der aktuelle Snapshot deckt den Zeitraum vom 5. bis 14. September 2026 ab. Er enthält 211 Veranstaltungen mit 732 einzelnen Terminen, 571 Orte und Unterorte, 1.625 Veranstalter*innen und 26 Kategorien oder Tags.

## Download

[Linztermine.json herunterladen (ca. 1 MB)](/datasets/linztermine/Linztermine.json)

## Verwendungshinweise

Ein Eintrag in `events` kann mehrere Einträge in `occurrences` besitzen. Für Kalenderansichten sind diese einzelnen Vorkommen zu verwenden. `location_id`, `organizer_id` und `tag_ids` verknüpfen Events mit den drei Registern.

Der Live-Eventfeed verweist im aktuellen Zeitfenster bei 87 von 211 Events auf Orts-IDs, die im Ortsregister fehlen. `location_name` bleibt deshalb immer direkt am Event erhalten und ist auch bei einer fehlenden Referenz nutzbar. Veranstalter- und Tag-Referenzen sind vollständig auflösbar.

Alle Datums- und Zeitwerte aus dem Feed werden als Linzer Ortszeit interpretiert (`Europe/Vienna`) und mit ihrem UTC-Offset ausgegeben. Im Festival-Zeitfenster lautet der Offset `+02:00`; die Werte sind daher nicht als UTC zu behandeln.

Die Felder `suitable_for_children` und `free_of_charge` können `true`, `false` oder `null` enthalten. `null` bedeutet, dass die Quelle keine Angabe liefert.

Veranstaltungen können sich mit dem Ars-Programm überschneiden und benötigen bei einer gemeinsamen Anzeige eine quellenbewusste Deduplizierung. Die Inhalte sind deutschsprachig und werden von Veranstalter*innen gepflegt. Ein Snapshot kurz vor dem Hackathon muss den jetzigen Stand ersetzen.

## Hackathon-Reifegrad

**Empfohlen.** Der zusammengeführte JSON-Snapshot ist ohne XML-Kenntnisse direkt nutzbar, thematisch stark und auf das Festival-Zeitfenster filterbar. Er ist nicht `essential`, weil der Live-Dienst keine Browser-CORS-Freigabe sendet, der Eventfeed eine falsche XML-Zeichenkodierung deklariert, Ortsreferenzen teilweise fehlen und die Daten bis September weiter geändert werden.

## Gefundene Schnittstellen

Die offizielle Schnittstellenübersicht listet genau vier aktive XML-Endpunkte:

- [`events_xml.php`](https://www.linztermine.at/schnittstelle/downloads/events_xml.php), steuerbar mit `lt_datefrom`, `lt_dateuntil`, `lt_location_id`, `lt_tag_id` und `lt_organizer_id`;
- [`locations_xml.php`](https://www.linztermine.at/schnittstelle/downloads/locations_xml.php);
- [`organizers_xml.php`](https://www.linztermine.at/schnittstelle/downloads/organizers_xml.php);
- [`tags_xml.php`](https://www.linztermine.at/schnittstelle/downloads/tags_xml.php).

Zusätzlich existieren `tags_xls.php` und `locations_xls.php`. Trotz ihrer Namen liefern sie HTML-Tabellen und keine zusätzlichen Daten. Der ältere Katalogeintrag „Linztermine – Kategorie“ besitzt keinen funktionierenden Live-Endpunkt mehr; Hauptkategorien sind bereits im Tag-Feed enthalten.

## Aktualisierung

Das mitgelieferte Python-Skript verwendet nur die Standardbibliothek:

```sh
python3 prepare_linztermine.py
```

Datumsgrenzen und lokale XML-Eingaben können als Argumente übergeben werden. Bei lokalen Eingaben ist für reproduzierbare Builds zusätzlich ein zeitzonenbehaftetes `--retrieved-at` erforderlich. Das Skript korrigiert die fehlerhafte Encoding-Deklaration des Eventfeeds, löst HTML-Zeichenreferenzen auf, prüft die vollständige XML-Struktur, validiert IDs und schreibt die Ausgabe atomar.

## Quellen

- [Offizielle Linztermine-Schnittstellenübersicht](https://www.linztermine.at/schnittstelle/downloads/)
- [Schnittstellenbeschreibung Veranstaltungen](https://data.linz.gv.at/katalog/Freizeit/Linztermine_Uebersicht_Veranstaltungen.txt)
- [Schnittstellenbeschreibung Orte](https://data.linz.gv.at/katalog/Freizeit/Linztermine_Ort.txt)
- [Schnittstellenbeschreibung Veranstalter*innen](https://data.linz.gv.at/katalog/Freizeit/Linztermine%20-%20Veranstalter.txt)
- [Schnittstellenbeschreibung Tags](https://data.linz.gv.at/katalog/Freizeit/Linztermine_Tags.txt)
- [Nutzungsbedingungen von Linztermine](https://www.linztermine.at/nutzungsbedingungen)
