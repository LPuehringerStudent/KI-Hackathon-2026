---
title: "EFA API-Referenz"
summary: "Vollständige Referenz zur Linzer EFA-Legacy-API"
provider: "Stadt Linz / LINZ AG LINIEN"
status: "optional"
format: "HTTP-API mit JSON oder XML"
license: "CC BY 4.0 mit ergänzenden LINZ-AG-Bedingungen"
data_vintage: "Live-API; zuletzt geprüft am 23. Juli 2026"
---

## Wichtig: Es gibt keinen EFA-Adapter

Für den Hackathon wird **kein gemeinsamer Adapter, Proxy, Cache oder
Fallback für die EFA-API** bereitgestellt.

Direkte Aufrufe aus einer Website funktionieren voraussichtlich nicht: Bei
unseren Tests am 23. Juli 2026 lieferte der EFA-Server keinen
`Access-Control-Allow-Origin`-Header. Browser blockieren solche
Cross-Origin-Aufrufe wegen CORS. Ein direktes `fetch()` aus dem Frontend ist
daher keine tragfähige Integration.

Wer die API trotzdem verwendet, muss selbst:

- einen eigenen Server, eine Serverless Function oder einen vergleichbaren
  Backend-Endpunkt betreiben;
- Timeouts, Fehlerbehandlung, Caching und einen Fallback implementieren;
- die unten beschriebenen Legacy-Requests und Antworten verarbeiten.

Für eine reine Frontend-Anwendung ist dieser Datensatz ungeeignet. Baut keine
unverzichtbare Demo-Funktion ausschließlich auf dieser API auf: Der aktuelle
Katalog kündigte bereits eine Einstellung der XML-Schnittstelle im Jahr 2024
an. Trotzdem war sie bei der letzten Prüfung am 23. Juli 2026 noch erreichbar.
Es gibt keine veröffentlichte Verfügbarkeitsgarantie.

## Kurzüberblick

| Eigenschaft | Stand der Recherche |
| --- | --- |
| Basis-URL | `https://www.linzag.at/static/` |
| Authentifizierung | In Dokumentation und Tests war kein API-Key erforderlich |
| Haltestellen-/Ortssuche | `XML_STOPFINDER_REQUEST` |
| Abfahrten | `XML_DM_REQUEST` |
| Routen | `XML_TRIP_REQUEST2` |
| Antwortformat | `outputFormat=JSON` oder `outputFormat=XML` |
| Request-Modus | Immer zustandslos mit `stateless=1` |
| Koordinaten | Für die Ausgabe ausdrücklich `coordOutputFormat=WGS84[DD.ddddd]` setzen |
| Browser-CORS | Kein `Access-Control-Allow-Origin` bei der Prüfung; Frontend-Direktaufrufe werden blockiert |
| Rate Limits / Quote | Nicht veröffentlicht |
| SLA / Verfügbarkeit | Nicht veröffentlicht |
| Lebenszyklus | Legacy-Schnittstelle; Einstellung war für 2024 angekündigt |
| Letzter Funktionstest | 23. Juli 2026 |

## Getesteter Zugriff

Die Beispiele verwenden `curl --get` mit `--data-urlencode`. Das ist
absichtlich ausführlicher als eine fertig zusammengesetzte URL: Leerzeichen,
Umlaute und die eckigen Klammern im Koordinatenformat werden dadurch korrekt
kodiert.

### 1. Orte und Haltestellen suchen

`XML_STOPFINDER_REQUEST` löst einen Suchtext in eindeutige EFA-Objekte auf.
Diese IDs können anschließend für Abfahrts- oder Routenabfragen verwendet
werden.

```bash
curl --fail --get \
  'https://www.linzag.at/static/XML_STOPFINDER_REQUEST' \
  --data-urlencode 'locationServerActive=1' \
  --data-urlencode 'stateless=1' \
  --data-urlencode 'outputFormat=JSON' \
  --data-urlencode 'type_sf=any' \
  --data-urlencode 'name_sf=Ars Electronica' \
  --data-urlencode 'coordOutputFormat=WGS84[DD.ddddd]'
```

Bei der Prüfung enthielt `stopFinder.points` unter anderem:

- `Linz/Donau, Ars Electronica Center`, Typ `poi`, ID `3575`;
- WGS84-Koordinaten `14.284714,48.309926`.

Die Koordinaten in der JSON-Antwort stehen in der Reihenfolge
**Längengrad, Breitengrad**.

### 2. Abfahrten abfragen

Für eine zustandslose Abfahrtsabfrage ist `mode=direct` wichtig. Das folgende
Beispiel verwendet die EFA-Haltestellen-ID `60501010` für den Linzer
Hauptplatz:

```bash
curl --fail --get \
  'https://www.linzag.at/static/XML_DM_REQUEST' \
  --data-urlencode 'locationServerActive=1' \
  --data-urlencode 'stateless=1' \
  --data-urlencode 'outputFormat=JSON' \
  --data-urlencode 'type_dm=any' \
  --data-urlencode 'name_dm=60501010' \
  --data-urlencode 'itdDateTimeDepArr=dep' \
  --data-urlencode 'limit=5' \
  --data-urlencode 'mode=direct' \
  --data-urlencode 'useRealtime=1' \
  --data-urlencode 'coordOutputFormat=WGS84[DD.ddddd]'
```

Relevante JSON-Bereiche sind:

- `dm.points`: aufgelöster Ausgangspunkt;
- `departureList`: Abfahrten;
- `departureList[].dateTime`: Sollzeit;
- `departureList[].realDateTime`: beobachtete Echtzeit;
- `departureList[].countdown`: verbleibende Minuten;
- `departureList[].servingLine`: Linie, Richtung und Verkehrsmittel;
- `servingLines`: am Punkt verfügbare Linien.

Die API serialisiert zahlreiche Zahlen und Wahrheitswerte als Strings.
Verlasst euch daher nicht ungeprüft auf JSON-Datentypen.

### 3. Eine Route berechnen

Das Beispiel sucht am 23. Juli 2026 ab 12:00 Uhr eine Verbindung vom
Hauptplatz (`60501010`) zum Hauptbahnhof (`60501720`):

```bash
curl --fail --get \
  'https://www.linzag.at/static/XML_TRIP_REQUEST2' \
  --data-urlencode 'locationServerActive=1' \
  --data-urlencode 'stateless=1' \
  --data-urlencode 'outputFormat=JSON' \
  --data-urlencode 'type_origin=stopID' \
  --data-urlencode 'name_origin=60501010' \
  --data-urlencode 'type_destination=stopID' \
  --data-urlencode 'name_destination=60501720' \
  --data-urlencode 'itdDate=20260723' \
  --data-urlencode 'itdTime=1200' \
  --data-urlencode 'itdTripDateTimeDepArr=dep' \
  --data-urlencode 'useRealtime=1' \
  --data-urlencode 'coordOutputFormat=WGS84[DD.ddddd]'
```

Relevante Bereiche sind `origin`, `destination` und `trips`. Eine Fahrt
enthält Abschnitte, Zeiten, Linieninformationen und gegebenenfalls Fußwege
oder Umstiege.

Das Datum muss im Format `YYYYMMDD`, die Uhrzeit im Format `HHMM` übergeben
werden. Ohne Datum oder Uhrzeit verwendet EFA den aktuellen Serverzeitpunkt.
`itdTripDateTimeDepArr=dep` interpretiert den Zeitpunkt als Abfahrt,
`itdTripDateTimeDepArr=arr` als gewünschte Ankunft.

## Gemeinsame EFA-Parameter

EFA verwendet keine moderne REST-Struktur. Stattdessen werden Parameter an
drei spezialisierte Request-Endpunkte übergeben.

### Punktparameter

`<usage>` steht für den Einsatzzweck des Punktes:

| Usage | Bedeutung |
| --- | --- |
| `sf` | StopFinder-Suche |
| `dm` | Ausgangspunkt der Abfahrtsabfrage |
| `origin` | Start einer Route |
| `destination` | Ziel einer Route |
| `via` | optionaler Zwischenpunkt |

Für jeden Punkt werden `name_<usage>` und `type_<usage>` kombiniert:

```text
locationServerActive=1
name_<usage>=Suchtext, ID oder Koordinate
type_<usage>=any|stopID|poiID|coord
stateless=1
```

`type=any` lässt EFA nach einem passenden Objekttyp suchen.
`type=stopID` und `type=poiID` sind für bereits bekannte IDs bestimmt.
`type=coord` erwartet eine Koordinate im unten beschriebenen EFA-Format.

Mögliche Suchzustände in einer Antwort sind `empty`, `identified`, `list`
und `notidentified`. Bei `list` muss die Anwendung einen Treffer auswählen.
Die offiziellen Unterlagen empfehlen zustandslose Requests; ältere Beispiele
mit `sessionID` und `requestID` sollten nicht mehr verwendet werden.

### Suchtypen einschränken

`anyObjFilter_<usage>` ist eine Bitmaske. Werte können addiert werden:

| Wert | Objekttyp |
| ---: | --- |
| `0` | alle Typen |
| `1` | Orte |
| `2` | Haltestellen |
| `4` | Straßen |
| `8` | Adressen |
| `16` | Kreuzungen |
| `32` | Points of Interest |
| `64` | Postleitzahlen |

Beispiel: `anyObjFilter_sf=34` sucht Haltestellen (`2`) und POIs (`32`).

### Datum, Zeit und Anzahl

| Parameter | Verwendung |
| --- | --- |
| `itdDate=YYYYMMDD` | Datum; laut Dokumentation wird auch `YYMMDD` akzeptiert |
| `itdTime=HHMM` | Uhrzeit |
| `timeOffset=<Minuten>` | Zeitverschiebung zum angegebenen Zeitpunkt |
| `itdTripDateTimeDepArr=dep|arr` | Abfahrts- oder Ankunftszeit bei Routen |
| `itdDateTimeDepArr=dep|arr` | Abfahrts- oder Ankunftszeit bei Departure Monitor |
| `limit=<Anzahl>` | Anzahl der Abfahrten; dokumentierter Standardwert ist 40 |

Der in der Schnittstellendokumentation beschriebene maximale
Abfragezeitraum für Abfahrten beträgt zwei Tage.

### Linien filtern

Eine Abfahrtsabfrage kann `line` mehrfach erhalten. Das dokumentierte Format
lautet:

```text
<network>:<DIVA-line>:<supplement>:<direction>:<project>
```

Offizielles Beispiel:

```text
line=esg:01001:E:H:f15
```

Diese internen Kennungen sind nicht selbsterklärend. Ermittelt sie aus einer
vorherigen Antwort und kodiert jeden `line`-Parameter einzeln.

## Koordinaten

### Koordinaten als Eingabe

Die historische Linzer Koordinatendokumentation beschreibt Eingaben als:

```text
name_origin=<x>:<y>:<Koordinatensystem>
type_origin=coord
```

Beispiele aus der Dokumentation:

```text
name_origin=5448851:810583:NAV5
name_origin=5448851:810583:NAV5:Ein schöner Ort
```

Ein neueres, allgemeines EFA-Handbuch zeigt WGS84-Eingaben in dieser Form:

```text
type_sf=coord
name_sf=14.284714:48.309926:WGS84[dd.ddddd]
```

Das allgemeine Handbuch dokumentiert das EFA-Produkt, nicht die konkrete
Linzer Instanz. Testet eine Koordinateneingabe deshalb vor der Verwendung.

### Koordinaten als Ausgabe

Ohne ausdrücklichen Parameter kann EFA Koordinaten im internen
MDV-Koordinatensystem liefern. Für webübliche Dezimalgrade immer setzen:

```text
coordOutputFormat=WGS84[DD.ddddd]
```

Weitere historisch dokumentierte Optionen:

| Parameter | Bedeutung |
| --- | --- |
| `coordOutputFormat=MDV` | internes Standardformat |
| `coordOutputFormat=WGS84[DD.ddddd]` | WGS84-Dezimalgrad |
| `coordOutputFormat=PROJ[+init=epsg:<Code>]` | Ausgabe in einem EPSG-System |
| `coordOutputFormatTail=<Anzahl>` | Anzahl der Nachkommastellen begrenzen |
| `coordListOutputFormat=list|string` | Darstellung einer Koordinatenliste |

## Ausgabeformate und Zeichencodierung

`outputFormat` akzeptiert laut offizieller Dokumentation `HTML`, `XML` und
`JSON`. Für Anwendungen ist `JSON` meist am einfachsten.

Beachtet zwei Abweichungen zwischen historischer Dokumentation und aktuellem
Server:

- Das Handbuch von 2015 beschreibt XML als `ISO-8859-1`. Die am 23. Juli
  2026 getestete XML-Antwort deklarierte dagegen `UTF-8`.
- Eine getestete JSON-Antwort enthielt gültiges JSON, wurde vom Server aber
  mit `Content-Type: text/html` ausgeliefert. Parser sollten den Body daher
  anhand des erwarteten Formats verarbeiten und nicht ausschließlich dem
  MIME-Type vertrauen.

## Sollzeit und Echtzeit

Der aktuelle Datenkatalog bezeichnet das Angebot als
**Sollzeit-Fahrplanauskunft**. Das aktualisierte Linzer Handbuch von 2015
erklärt außerdem, dass diese Schnittstellenvariante keine Störungs- und
Echtzeitmeldungen bereitstellt.

Beim Live-Test am 23. Juli 2026 lieferte `XML_DM_REQUEST` mit
`useRealtime=1` jedoch unter anderem `realDateTime`, `delay` und
`realtime=1`. Auch eine Routenabfrage enthielt überwachte Echtzeitwerte.

Diese Beobachtung ist **keine Garantie**. Anwendungen müssen:

1. `realDateTime` nur verwenden, wenn das Feld vorhanden und plausibel ist;
2. andernfalls auf `dateTime` als Sollzeit zurückfallen;
3. nicht voraussetzen, dass Störungen, Ausfälle oder Echtzeitdaten vollständig
   sind.

## Historisch dokumentierte Routenoptionen

Die folgenden Parameter stammen aus den älteren Handbüchern. Sie sind hier
zur Einordnung gesammelt, wurden aber am aktuellen Linzer Endpunkt nicht
vollständig geprüft:

| Parameter | Historisch dokumentierte Bedeutung |
| --- | --- |
| `ptOptionsActive=1` | Optionen für öffentliche Verkehrsmittel aktivieren |
| `useProxFootSearch=1` | Fußwegsuche in der Umgebung |
| `maxChanges=<Anzahl>` | maximale Umstiege |
| `routeType=LEASTTIME` | schnellste Route |
| `routeType=LEASTINTERCHANGE` | möglichst wenige Umstiege |
| `routeType=LEASTWALKING` | möglichst wenig Fußweg |
| `excludedMeans=...` | Verkehrsmittel ausschließen |
| `exclMOT_<ID>=1` | Verkehrsmittel anhand der MOT-ID ausschließen |

Historische MOT-IDs:

| ID | Verkehrsmittel |
| ---: | --- |
| `0` | Zug |
| `1` | S-Bahn |
| `2` | U-Bahn |
| `3` | Stadtbahn |
| `4` | Straßenbahn |
| `5` | Stadtbus |
| `6` | Regionalbus |
| `7` | Schnellbus |
| `8` | Seilbahn oder Zahnradbahn |
| `9` | Schiff |
| `10` | Bedarfsverkehr |
| `11` | Sonstiges |

Historisch dokumentierte Barrierefreiheitsoptionen sind
`imparedOptionsActive=1` – die falsche Schreibweise ist Teil der API –,
`noSolidStairs=1`, `lowPlatformVhcl=1` und `changeSpeed=slow`. Auch diese
Parameter müssen gegen die aktuelle Instanz getestet werden.

## Eigener Backend-Zugriff

Ein selbst betriebener Backend-Endpunkt sollte mindestens:

- nur die drei bekannten EFA-Endpunkte zulassen, niemals eine beliebige vom
  Client gelieferte URL weiterleiten;
- Parameter validieren und eine Obergrenze für Ergebnisse setzen;
- einen kurzen Verbindungs- und Antwort-Timeout verwenden;
- Antworten sinnvoll zwischenspeichern;
- einen klaren Fehlerstatus an das Frontend liefern;
- Sollzeiten oder lokale Beispieldaten als Fallback vorsehen.

Das ist eine Empfehlung für eure eigene Anwendung, **kein vom Hackathon
bereitgestellter Dienst**.

## Bekannte Lücken und Risiken

Folgende Informationen wurden in keiner auffindbaren Linzer
Schnittstellendokumentation veröffentlicht:

- Rate Limit, Tageskontingent oder maximale Parallelität;
- SLA, Wartungsfenster oder garantierte Verfügbarkeit;
- garantierter Lebenszyklus der EFA-Endpunkte;
- verbindliches JSON-Schema oder Versionierungsregeln;
- Garantie für stabile Haltestellen-, POI- oder Linien-IDs;
- Vollständigkeit und Aktualisierungsintervall der Echtzeitdaten;
- offiziell unterstützte Browser-CORS-Origins.

Verwendet den Dienst rücksichtsvoll, vermeidet Polling in kurzen Intervallen
und speichert wiederverwendbare Antworten zwischen. HTTP `200` allein
bedeutet bei EFA nicht zwingend, dass eine fachlich gültige Verbindung
gefunden wurde; prüft auch den Inhalt der Antwort.

## Alternativen

Der aktuelle Datenkatalog nennt **GTFS** und **NeTEx** als vorgesehene
Nachfolgeformate für Soll-Fahrplandaten. Nutzt für planbare, wiederholbare
Auswertungen bevorzugt einen dort verfügbaren statischen Export. Die
öffentlich sichtbaren Katalogeinträge sind allerdings widersprüchlich:
Der Beschreibungstext kündigt die EFA-Einstellung für 2024 an, während ein
Distributionslabel „nur noch bis 2014“ nennt.

Der lokale Datensatz [LINZ AG Linien 2025](linz-ag-linien-2025) enthält
statische Liniengeometrien. Er ersetzt keine Abfahrts- oder Routenberechnung,
ist aber für Karten ohne Live-Abhängigkeit geeignet.

## Dokumentationsbestand

Alle auffindbaren relevanten Unterlagen sind hier eingeordnet. Die Inhalte
der vier Linzer PDFs wurden in den Abschnitten oben konsolidiert.

| Dokument | Einordnung |
| --- | --- |
| [EFA XML Schnittstelle, Stand Dezember 2015](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/EFA_XML_Schnittstelle_20151217.pdf) | Wichtigste Linzer Schnittstellenbeschreibung; StopFinder, Trip und zustandsloser Departure Monitor |
| [EFA Koordinaten](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/LINZ_AG_LINIEN_Schnittstelle_EFA_Koordinaten.pdf) | Linzer Ergänzung zu Eingabe- und Ausgabeformaten für Koordinaten |
| [EFA v7 Echtzeit, Stand Januar 2013](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/LINZ_AG_Linien_Schnitstelle_EFA_v7_Echtzeit.pdf) | Historisches Handbuch mit Echtzeit-, Routen- und Optionsparametern; enthält alte zustandsbehaftete Abläufe |
| [EFA V1, Stand September 2011](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/LINZ_LINIEN_Schnittstelle_EFA_V1.pdf) | Historische Erstfassung; nur zur Erklärung alter Parameter |
| [Verzeichnis der Linzer Fahrplanunterlagen](https://data.linz.gv.at/katalog/linz_ag/linz_ag_linien/fahrplan/) | Offizielles Verzeichnis der vier PDFs |
| [Aktueller Datenkatalog: EFA, GTFS und NeTEx](https://www.data.gv.at/datasets/d3c0a223-516b-4049-9370-22881a0428d8?locale=de) | Aktueller Katalogeintrag mit CC-BY-4.0-Lizenz, Migrationshinweis und angekündigter EFA-Einstellung |
| [Legacy-Katalogeintrag auf data.europa.eu](https://data.europa.eu/data/datasets/cc074ef6-bcc9-4c76-815c-81e349ee6a13) | Spiegel des älteren Linzer EFA-Datensatzes und seiner Dokumente |
| [Allgemeines EFA JSON API Training, Version 2.3](https://www.mobidata-bw.de/data/EFA_JSON_API_Training_EN_2.3.pdf) | Umfangreiches allgemeines Mentz-EFA-Handbuch; hilfreich für Antwortstrukturen, aber kein Vertrag für die Linzer Konfiguration |
| [Mentz: EFA Fahrplanauskunft](https://www.mentz.net/loesungen/efa-fahrplanauskunft/) | Produktüberblick des EFA-Herstellers; keine Linzer API-Referenz |
| [Nutzungsbedingungen des Linzer Datenportals](https://data.linz.gv.at/nutzungsbedingungen/) | Ergänzende Bedingungen zur im Katalog genannten CC-BY-4.0-Lizenz |

## Was bei der Recherche verifiziert wurde

Am 23. Juli 2026 wurden die drei HTTPS-Endpunkte mit zustandslosen Requests
geprüft:

- StopFinder lieferte Treffer für „Ars Electronica“;
- Departure Monitor lieferte Abfahrten für den Hauptplatz;
- Trip Request lieferte Verbindungen vom Hauptplatz zum Hauptbahnhof;
- JSON und XML waren abrufbar;
- XML deklarierte aktuell UTF-8;
- es wurde kein API-Key verlangt;
- kein getesteter Response enthielt `Access-Control-Allow-Origin`.

Das ist eine Momentaufnahme und keine Zusage für den Veranstaltungstag.
